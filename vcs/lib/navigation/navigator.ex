defmodule Navigation.Navigator do
  use GenServer
  require Logger

  @default_pv_cmds_level 3

  def start_link(config) do
    Logger.debug("Start Navigation.Navigator")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    vehicle_type = config.vehicle_type
    vehicle_module = Module.concat([Vehicle, vehicle_type])
    {pv_cmds_msg_classification, pv_cmds_msg_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :pv_cmds)
    Logger.debug("Vehicle module: #{inspect(vehicle_module)}")
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_module: vehicle_module,
        default_pv_cmds_level: Map.get(config, :default_pv_cmds_level, @default_pv_cmds_level),
        navigator_loop_timer: nil,
        navigator_loop_interval_ms: config.navigator_loop_interval_ms,
        pv_cmds_msg_classification: pv_cmds_msg_classification,
        pv_cmds_msg_time_validity_ms: pv_cmds_msg_time_validity_ms,
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    # Start sorters
    Comms.Operator.join_group(__MODULE__, {:goals, -1}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 0}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 1}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 2}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 3}, self())
    # Comms.Operator.join_group(__MODULE__, {:goals, 4}, self())
    navigator_loop_timer = Common.Utils.start_loop(self(), state.navigator_loop_interval_ms, :navigator_loop)
    {:noreply, %{state | navigator_loop_timer: navigator_loop_timer}}
  end

  @impl GenServer
  def handle_cast({{:goals, level},classification, time_validity_ms, goals_map}, state) do
    # Logger.warn("rx goals #{level} from #{inspect(classification)}: #{inspect(goals_map)}")
    MessageSorter.Sorter.add_message({:goals, level}, classification, time_validity_ms, goals_map)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:navigator_loop, state) do
    # Start with Goals 4, move through goals 1
    # If there a no current commands, then take the command from default_pv_cmds_level
    {pv_cmds, control_state} = Enum.reduce(3..-1, {%{}, nil}, fn (pv_cmd_level, acc) ->
      {cmd_values, cmd_status} = MessageSorter.Sorter.get_value_with_status({:goals, pv_cmd_level})
      if (cmd_status == :current) do
        {cmd_values, pv_cmd_level}
      else
        acc
      end
    end)
    {pv_cmds, control_state} =
    if Enum.empty?(pv_cmds) do
      # If we are flying, send orbit command to Path Manager
      # if true do
      #   Logger.warn("We are flying and need an orbit. Send request to PathManager.")
      #   Navigation.PathManager.begin_orbit()
      # end
      control_state = state.default_pv_cmds_level
      {MessageSorter.Sorter.get_value({:goals, control_state}), control_state}
    else
      {pv_cmds, control_state}
    end
    control_state_pv_cmds = max(1,control_state)
    MessageSorter.Sorter.add_message(:control_state, [0,1], 2*state.navigator_loop_interval_ms, control_state)
    MessageSorter.Sorter.add_message({:pv_cmds, control_state_pv_cmds}, [0,1], 2*state.navigator_loop_interval_ms, pv_cmds)
    # Comms.Operator.send_global_msg_to_group(__MODULE__, {:control_state, control_state}, :control_state, self())
    # Telemetry.Operator.construct_and_send_message(:control_state, [Telemetry.Ublox.get_itow(), control_state])
    Telemetry.Operator.store_data(%{control_state: control_state})
    # Comms.Operator.send_global_msg_to_group(__MODULE__, {{:tx_goals, control_state}, pv_cmds}, :tx_goals, self())
    # MessageSorter.Sorter.add_message(
    #   {:pv_cmds, control_state},
    #   state.pv_cmds_msg_classification,
    #   state.pv_cmds_msg_time_validity_ms,
    #   pv_cmds)
    {:noreply, state}
  end
end
