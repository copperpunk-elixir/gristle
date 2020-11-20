defmodule Navigation.Navigator do
  use GenServer
  require Logger

  @default_pv_cmds_level 2

  def start_link(config) do
    Logger.info("Start Navigation.Navigator GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
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
    {pv_cmds_msg_classification, pv_cmds_msg_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :pv_cmds)
    {control_state_msg_classification, control_state_msg_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :control_state)
    state = %{
      default_pv_cmds_level: Keyword.get(config, :default_pv_cmds_level, @default_pv_cmds_level),
      navigator_loop_timer: nil,
      pv_cmds_msg_classification: pv_cmds_msg_classification,
      pv_cmds_msg_time_validity_ms: pv_cmds_msg_time_validity_ms,
      control_state_msg_classification: control_state_msg_classification,
      control_state_msg_time_validity_ms: control_state_msg_time_validity_ms,
      goals_store: %{},
      goals_default: %{}
    }

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :goals_sorter, self())
    navigator_loop_interval_ms = Keyword.fetch!(config, :navigator_loop_interval_ms)
    Registry.register(MessageSorterRegistry, {:goals, 1}, navigator_loop_interval_ms)
    Registry.register(MessageSorterRegistry, {:goals, 2}, navigator_loop_interval_ms)
    Registry.register(MessageSorterRegistry, {:goals, 3}, navigator_loop_interval_ms)
    Common.Utils.start_loop(self(), navigator_loop_interval_ms, :navigator_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:goals_sorter, level, classification, time_validity_ms, goals_map}, state) do
    # Logger.debug("rx goals #{level} from #{inspect(classification)}: #{inspect(goals_map)}")
    MessageSorter.Sorter.add_message({:goals, level}, classification, time_validity_ms, goals_map)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, {:goals, level}, goals, status}, state) do
    goals_default = if (level == state.default_pv_cmds_level), do: goals, else: state.goals_default
    goals = if (status == :current), do: goals, else: %{}
    {:noreply, %{state | goals_store: Map.put(state.goals_store, level, goals), goals_default: goals_default}}
  end


  @impl GenServer
  def handle_info(:navigator_loop, state) do
    # Start with Goals 3, move through goals 1
    # If there a no current commands, then take the command from default_pv_cmds_level
    default_result = {state.goals_default, state.default_pv_cmds_level}
    goals_store = state.goals_store
    {pv_cmds, control_state} = Enum.reduce(3..1, default_result, fn (pv_cmd_level, acc) ->
      cmd_values = Map.get(goals_store, pv_cmd_level, %{})
      if Enum.empty?(cmd_values), do: acc, else: {cmd_values, pv_cmd_level}
    end)

    MessageSorter.Sorter.add_message(:control_state, state.control_state_msg_classification, state.control_state_msg_time_validity_ms, control_state)
    MessageSorter.Sorter.add_message({:pv_cmds, control_state}, state.pv_cmds_msg_classification, state.pv_cmds_msg_time_validity_ms, pv_cmds)
    Peripherals.Uart.Telemetry.Operator.store_data(%{control_state: control_state})
    {:noreply, state}
  end
end
