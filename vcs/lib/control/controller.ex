defmodule Control.Controller do
  use GenServer
  require Logger
  require Command.Utils, as: CU

  def start_link(config) do
    Logger.debug("Start Control.Controller GenServer")
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
      pv_keys: config[:pv_keys],
      pv_cmds: %{},
      pv_cmds_store: %{},
      control_state: 0,
      yaw: nil,
      airspeed: 0,
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:pv_values, :attitude_bodyrate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
    Registry.register(MessageSorterRegistry, {:control_state, :value}, 200)
    Registry.register(MessageSorterRegistry, {{:pv_cmds, CU.cs_rates}, :value}, Configuration.Generic.get_loop_interval_ms(:fast))
    Registry.register(MessageSorterRegistry, {{:pv_cmds, CU.cs_attitude}, :value}, Configuration.Generic.get_loop_interval_ms(:fast))
    Registry.register(MessageSorterRegistry, {{:pv_cmds, CU.cs_sca}, :value}, Configuration.Generic.get_loop_interval_ms(:fast))
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :attitude_bodyrate}, attitude, bodyrate, dt}, state) do
    # Logger.debug("Control rx att/attrate/dt: #{inspect(attitude)}/#{inspect(bodyrate)}/#{dt}")
    # Logger.debug("cs: #{state.control_state}")
    pv_cmd_level = if (state.control_state == CU.cs_sca), do: CU.cs_attitude, else: state.control_state
      case state.control_state do
        CU.cs_sca -> CU.cs_attitude
        CU.cs_attitude -> CU.cs_attitude
        CU.cs_rates -> CU.cs_rates
        _other -> nil
      end

    destination_group = {:pv_cmds_values, pv_cmd_level}
    pv_keys = Map.get(state.pv_keys, pv_cmd_level, [])
    # Logger.debug("pv keys: #{inspect(pv_keys)}")
    pv_cmds = Map.take(state.pv_cmds, pv_keys)
    pv_value_map = %{attitude: attitude, bodyrate: bodyrate}
    # Logger.debug("ab pv_value_map/cmds: #{inspect(pv_value_map)}/#{inspect(pv_cmds)}")
    unless Enum.empty?(pv_cmds) do
      Comms.Operator.send_local_msg_to_group(__MODULE__, {destination_group, pv_cmds, pv_value_map, state.airspeed, dt}, destination_group, self())
    end
    {:noreply, %{state | yaw: attitude.yaw}}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :position_velocity}, position, velocity, dt}, state) do
    # Logger.debug("Control rx vel/pos/dt: #{inspect(position)}/#{inspect(velocity)}/#{dt}")
    airspeed = velocity.airspeed
    if (state.control_state == CU.cs_sca) do
      yaw = state.yaw
      unless is_nil(yaw) do
        pv_value_map = Map.merge(velocity, %{altitude: position.altitude, yaw: yaw})
        pv_keys = get_in(state, [:pv_keys, state.control_state])
        pv_cmds = Map.take(state.pv_cmds, pv_keys)
        # Logger.debug("pv pv_value_map/cmds: #{inspect(pv_value_map)}/#{inspect(pv_cmds)}")
        Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_cmds_values, CU.cs_sca}, pv_cmds, pv_value_map, airspeed, dt},{:pv_cmds_values, CU.cs_sca}, self())
      end
    end
    {:noreply, %{state | airspeed: airspeed}}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, :control_state, control_state, _status}, state) do
    {:noreply, %{state | control_state: control_state}}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, {:pv_cmds, level}, pv_cmds, _status}, state) do
    pv_cmds_store = Map.put(state.pv_cmds_store, level, pv_cmds)
    pv_cmds_all = retrieve_pv_cmds_up_to_control_state(state.control_state, pv_cmds_store)
    {:noreply, %{state | pv_cmds_store: pv_cmds_store, pv_cmds: pv_cmds_all}}
  end

  def retrieve_pv_cmds_up_to_control_state(control_state, pv_cmds_store) do
    Enum.reduce(CU.cs_rates..max(control_state,CU.cs_rates),%{}, fn (level, acc) ->
      Map.merge(acc, Map.get(pv_cmds_store, level, %{}))
    end)
  end
end
