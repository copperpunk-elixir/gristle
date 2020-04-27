defmodule Control.Controller do
  use GenServer
  require Logger

  @control_state_sorter :control_state
  @pv_cmds_values_I_group {:pv_cmds_values, :I}
  @pv_cmds_values_II_group {:pv_cmds_values, :II}
  @pv_cmds_values_III_group {:pv_cmds_values, :III}
  @pv_cmds_values_disarmed_group {:pv_cmds_values, :disarmed}

  def start_link(config) do
    Logger.debug("Start Control.ControllerCar")
    {:ok, process_id} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    begin()
    start_control_loop()
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    vehicle_type = config.vehicle_type
    vehicle_module = Module.concat([__MODULE__, vehicle_type])
    Logger.debug("Vehicle module: #{inspect(vehicle_module)}")
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_module: vehicle_module,
        pv_cmds: %{},
        control_loop_timer: nil,
        control_loop_interval_ms: config.process_variable_cmd_loop_interval_ms,
        control_state: nil
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    MessageSorter.System.start_link()
    GenServer.cast(self(), :start_pv_cmd_sorters)
    # Start control state sorter
    control_state_config = %{
      name: @control_state_sorter,
      default_message_behavior: :last
    }
    MessageSorter.System.start_sorter(control_state_config)
    join_process_variable_groups()
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_pv_cmd_sorters, state) do
    apply(state.vehicle_module, :start_message_sorters, [])
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_control_loop, state) do
    control_loop_timer = Common.Utils.start_loop(self(), state.control_loop_interval_ms, :control_loop)
    state = %{state | control_loop_timer: control_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_control_loop, state) do
    control_loop_timer = Common.Utils.stop_loop(state.control_loop_timer)
    state = %{state | control_loop_timer: control_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :attitude_attitude_rate}, pv_value_map, dt}, state) do
    Logger.warn("Control rx att/attrate: #{inspect(pv_value_map)}")
    case state.control_state do
      :auto ->
        Comms.Operator.send_local_msg_to_group(__MODULE__, {@pv_cmds_values_III_group, state.pv_cmds, pv_value_map,dt},@pv_cmds_values_III_group, self())
      :semi_auto ->
        Comms.Operator.send_local_msg_to_group(__MODULE__, {@pv_cmds_values_II_group, state.pv_cmds, pv_value_map,dt},@pv_cmds_values_II_group, self())
      :manual ->
        Comms.Operator.send_local_msg_to_group(__MODULE__, {@pv_cmds_values_I_group, state.pv_cmds, pv_value_map,dt},@pv_cmds_values_I_group, self())
      :disarmed ->
        Comms.Operator.send_local_msg_to_group(__MODULE__, {@pv_cmds_values_disarmed_group, %{}, %{},0},@pv_cmds_values_disarmed_group, self())
      _other -> nil
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :position_velocity}, pv_value_map, dt}, state) do
    Logger.warn("Control rx vel/pos: #{inspect(pv_value_map)}")
    if (state.control_state == :auto) do
      pv_value_map = apply(state.vehicle_module, :get_auto_pv_value_map, [pv_value_map])
      Comms.Operator.send_local_msg_to_group(__MODULE__, {@pv_cmds_values_III_group, state.pv_cmds, pv_value_map,dt},@pv_cmds_values_III_group, self())
    end
    {:noreply, state}
  end


  @impl GenServer
  def handle_info(:control_loop, state) do
    Logger.debug("Control loop. CS: #{state.control_state}")
    # For every PV, get the corresponding command
    control_state = get_control_state()
    pv_cmds_list = apply(state.vehicle_module, :get_pv_cmds_list, [state.control_state])
    pv_cmds = update_all_pv_cmds(pv_cmds_list)
    {:noreply, %{state | pv_cmds: pv_cmds, control_state: control_state}}
  end

  def start_control_loop() do
    GenServer.cast(__MODULE__, :start_control_loop)
  end

  def stop_control_loop() do
    GenServer.cast(__MODULE__, :stop_control_loop)
  end

  def get_pv_cmd(pv_name) do
    MessageSorter.Sorter.get_value({:pv_cmds, pv_name})
  end

  def update_all_pv_cmds(pv_cmds_list) do
    Enum.reduce(pv_cmds_list, %{}, fn (pv_name, acc) ->
      Map.put(acc, pv_name, get_pv_cmd(pv_name))
    end)
  end

  # TODO: This is only for testing without GSM in loop
  def add_control_state(control_state) do
    # This is the only process adding to the control_state_sorter, so
    # the classification and time_validity_ms aren't really important
    MessageSorter.Sorter.add_message(@control_state_sorter, [0], 100, control_state)
  end

  def get_control_state() do
    MessageSorter.Sorter.get_value(@control_state_sorter)
  end

  defp begin() do
    GenServer.cast(__MODULE__, :begin)
  end

  defp join_process_variable_groups() do
    Comms.Operator.join_group(__MODULE__, {:pv_values, :attitude_attitude_rate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
  end
end
