defmodule Control.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Control.Controller GenServer")
    {:ok, process_id} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, process_id}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    state = %{
      pv_cmds: %{},
      pv_cmds_store: %{},
      control_state: -1,
      airspeed: 0,
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:pv_values, :attitude_bodyrate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
    Registry.register(MessageSorterRegistry, :control_state, 200)
    Registry.register(MessageSorterRegistry, {:pv_cmds, 1}, Configuration.Generic.get_loop_interval_ms(:medium))
    Registry.register(MessageSorterRegistry, {:pv_cmds, 2}, Configuration.Generic.get_loop_interval_ms(:medium))
    Registry.register(MessageSorterRegistry, {:pv_cmds, 3}, Configuration.Generic.get_loop_interval_ms(:medium))
    # Common.Utils.start_loop(self(), Keyword.fetch!(config, :process_variable_cmd_loop_interval_ms), :control_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :attitude_bodyrate}, attitude, bodyrate, dt}, state) do
    # Logger.debug("Control rx att/attrate/dt: #{inspect(attitude)}/#{inspect(bodyrate)}/#{dt}")
    # Logger.debug("cs: #{state.control_state}")
    {destination_group, pv_cmds} =
      case state.control_state do
        3 -> {{:pv_cmds_values, 2}, state.pv_cmds}
        2 -> {{:pv_cmds_values, 2}, state.pv_cmds}
        1 -> {{:pv_cmds_values, 1}, state.pv_cmds}
        0 -> {{:pv_cmds_values, 1}, state.pv_cmds}
        -1 -> {{:pv_cmds_values, 1}, state.pv_cmds}
        _other -> {nil, nil}
      end
    pv_value_map = %{attitude: attitude, bodyrate: bodyrate}
    # Logger.debug("dest grp/cmds: #{inspect(destination_group)}/#{inspect(pv_cmds)}")
    Comms.Operator.send_local_msg_to_group(__MODULE__, {destination_group, pv_cmds, pv_value_map, state.airspeed, dt}, destination_group, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :position_velocity}, position, velocity, dt}, state) do
    # Logger.debug("Control rx vel/pos/dt: #{inspect(position)}/#{inspect(velocity)}/#{dt}")
    # Logger.debug("cs: #{state.control_state}")
    airspeed = velocity.airspeed
    if (state.control_state == 3) do
      pv_value_map = Map.merge(velocity, %{altitude: position.altitude})
      # Logger.debug("pv_value_map/cmds: #{inspect(pv_value_map)}/#{inspect(state.pv_cmds)}")
      Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_cmds_values, 3}, state.pv_cmds, pv_value_map, airspeed, dt},{:pv_cmds_values, 3}, self())
    end
    {:noreply, %{state | airspeed: airspeed}}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, :control_state, control_state, status}, state) do
    pv_cmds = retrieve_pv_cmds_from_1_to_control_state(control_state)
    {:noreply, %{state | control_state: control_state, pv_cmds: pv_cmds}}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, {:pv_cmds, level}, pv_cmds, _status}, state) do
    {:noreply, %{state | pv_cmds_store: Map.put(state.pv_cmds_store, level, pv_cmds)}}
  end

  def retrieve_pv_cmds_from_1_to_control_state(control_state) do
    Enum.reduce(1..max(control_state,1),%{}, fn (level, acc) ->
      Map.merge(acc, MessageSorter.Sorter.get_value({:pv_cmds, level}))
    end)
  end
end
