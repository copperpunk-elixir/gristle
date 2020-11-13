defmodule Navigation.Navigator do
  use GenServer
  require Logger

  @default_pv_cmds_level 2

  def start_link(config) do
    Logger.info("Start Navigation.Navigator GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {pv_cmds_msg_classification, pv_cmds_msg_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :pv_cmds)
    {control_state_msg_classification, control_state_msg_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :control_state)

    {:ok, %{
        default_pv_cmds_level: Map.get(config, :default_pv_cmds_level, @default_pv_cmds_level),
        navigator_loop_timer: nil,
        navigator_loop_interval_ms: Keyword.fetch!(config, :navigator_loop_interval_ms),
        pv_cmds_msg_classification: pv_cmds_msg_classification,
        pv_cmds_msg_time_validity_ms: pv_cmds_msg_time_validity_ms,
        control_state_msg_classification: control_state_msg_classification,
        control_state_msg_time_validity_ms: control_state_msg_time_validity_ms
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
    Comms.Operator.join_group(__MODULE__, :goals_sorter, self())
    navigator_loop_timer = Common.Utils.start_loop(self(), state.navigator_loop_interval_ms, :navigator_loop)
    {:noreply, %{state | navigator_loop_timer: navigator_loop_timer}}
  end

  @impl GenServer
  def handle_cast({:goals_sorter, level, classification, time_validity_ms, goals_map}, state) do
    # Logger.debug("rx goals #{level} from #{inspect(classification)}: #{inspect(goals_map)}")
    MessageSorter.Sorter.add_message({:goals, level}, classification, time_validity_ms, goals_map)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:navigator_loop, state) do
    # Start with Goals 4, move through goals 1
    # If there a no current commands, then take the command from default_pv_cmds_level
    {pv_cmds, control_state} = Enum.reduce(3..-1, {%{}, nil}, fn (pv_cmd_level, acc) ->
      cmd_values = MessageSorter.Sorter.get_value_if_current({:goals, pv_cmd_level})
      if is_nil(cmd_values) do
        acc
      else
        {cmd_values, pv_cmd_level}
      end
    end)
    {pv_cmds, control_state} =
    if Enum.empty?(pv_cmds) do
      # If we are flying, send orbit command to Path Manager
      # if true do
      #   Logger.debug("We are flying and need an orbit. Send request to PathManager.")
      #   Navigation.PathManager.begin_orbit()
      # end
      control_state = state.default_pv_cmds_level
      {MessageSorter.Sorter.get_value({:goals, control_state}), control_state}
    else
      {pv_cmds, control_state}
    end
    control_state_pv_cmds = max(1,control_state)
    MessageSorter.Sorter.add_message(:control_state, state.control_state_msg_classification, state.control_state_msg_time_validity_ms, control_state)
    MessageSorter.Sorter.add_message({:pv_cmds, control_state_pv_cmds}, state.pv_cmds_msg_classification, state.pv_cmds_msg_time_validity_ms, pv_cmds)
    Peripherals.Uart.Telemetry.Operator.store_data(%{control_state: control_state})
    {:noreply, state}
  end
end
