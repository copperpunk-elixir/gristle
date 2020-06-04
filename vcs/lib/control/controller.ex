defmodule Control.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Control.Controller")
    {:ok, process_id} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    vehicle_type = config.vehicle_type
    vehicle_module = Module.concat([Configuration.Vehicle, vehicle_type, Control])
    Logger.debug("Vehicle module: #{inspect(vehicle_module)}")
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_module: vehicle_module,
        pv_cmds: %{},
        control_loop_timer: nil,
        control_loop_interval_ms: config.process_variable_cmd_loop_interval_ms,
        control_state: -1,
        yaw: 0
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    join_process_variable_groups()
    control_loop_timer = Common.Utils.start_loop(self(), state.control_loop_interval_ms, :control_loop)
    {:noreply, %{state | control_loop_timer: control_loop_timer}}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :attitude_bodyrate}, pv_value_map, dt}, state) do
    # Logger.warn("Control rx att/attrate/dt: #{inspect(pv_value_map)}/#{dt}")
    # Logger.warn("cs: #{state.control_state}")
    {destination_group, pv_cmds} =
      case state.control_state do
        3 -> {{:pv_cmds_values, 2}, state.pv_cmds}
        2 -> {{:pv_cmds_values, 2}, state.pv_cmds}
        1 -> {{:pv_cmds_values, 1}, state.pv_cmds}
        0 -> {{:pv_cmds_values, 1}, state.pv_cmds}
        -1 -> {{:pv_cmds_values, 1}, state.pv_cmds}
        _other -> {nil, nil}
      end
    # Logger.warn("dest grp/cmds: #{inspect(destination_group)}/#{inspect(pv_cmds)}")
    Comms.Operator.send_local_msg_to_group(__MODULE__, {destination_group, pv_cmds, pv_value_map, dt}, destination_group, self())
    {:noreply, %{state | yaw: pv_value_map.attitude.yaw}}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :position_velocity}, pv_value_map, dt}, state) do
    # Logger.warn("Control rx vel/pos/dt: #{inspect(pv_value_map)}/#{dt}")
    if (state.control_state == 3) do
      pv_value_map = apply(state.vehicle_module, :get_auto_pv_value_map, [pv_value_map, state.yaw])
      # Logger.warn("pv_value_map/cmds: #{inspect(pv_value_map)}/#{inspect(state.pv_cmds)}")
      Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_cmds_values, 3}, state.pv_cmds, pv_value_map,dt},{:pv_cmds_values, 3}, self())
    end
    {:noreply, state}
  end


  @impl GenServer
  def handle_info(:control_loop, state) do
    # Logger.debug("Control loop. CS: #{state.control_state}")
    # For every PV, get the corresponding command
    control_state = MessageSorter.Sorter.get_value(:control_state)
    pv_cmds = retrieve_pv_cmds_from_1_to_control_state(control_state)
    {:noreply, %{state | pv_cmds: pv_cmds, control_state: control_state}}
  end

  def get_pv_cmd(pv_name) do
    Enum.reduce(1..3, nil, fn (level, acc) ->
      cmds = MessageSorter.Sorter.get_value({:pv_cmds, level})
      Map.get(cmds, pv_name, acc)
    end)
  end

  def retrieve_pv_cmds_from_1_to_control_state(control_state) do
    Enum.reduce(1..max(control_state,1),%{}, fn (level, acc) ->
      Map.merge(acc, MessageSorter.Sorter.get_value({:pv_cmds, level}))
    end)
  end

  defp join_process_variable_groups() do
    Comms.Operator.join_group(__MODULE__, {:pv_values, :attitude_bodyrate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
  end
end
