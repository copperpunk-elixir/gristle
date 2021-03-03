defmodule Navigation.Navigator do
  use GenServer
  require Logger
  require Command.Utils, as: CU

  @default_control_cmds_level CU.cs_attitude

  def start_link(config) do
    Logger.debug("Start Navigation.Navigator")
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
    {control_cmds_msg_classification, control_cmds_msg_time_validity_ms} = Configuration.Module.MessageSorter.get_message_sorter_classification_time_validity_ms(__MODULE__, :control_cmds)
    {control_state_msg_classification, control_state_msg_time_validity_ms} = Configuration.Module.MessageSorter.get_message_sorter_classification_time_validity_ms(__MODULE__, :control_state)
    state = %{
      default_control_cmds_level: Keyword.get(config, :default_control_cmds_level, @default_control_cmds_level),
      navigator_loop_timer: nil,
      control_cmds_msg_classification: control_cmds_msg_classification,
      control_cmds_msg_time_validity_ms: control_cmds_msg_time_validity_ms,
      control_state_msg_classification: control_state_msg_classification,
      control_state_msg_time_validity_ms: control_state_msg_time_validity_ms,
      goals_store: %{},
      goals_default: %{}
    }

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :goals_sorter, self())
    navigator_loop_interval_ms = Keyword.fetch!(config, :navigator_loop_interval_ms)
    Registry.register(MessageSorterRegistry, {{:goals, CU.cs_rates}, :value}, navigator_loop_interval_ms)
    Registry.register(MessageSorterRegistry, {{:goals, CU.cs_attitude}, :value}, navigator_loop_interval_ms)
    Registry.register(MessageSorterRegistry, {{:goals, CU.cs_sca}, :value}, navigator_loop_interval_ms)
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
  def handle_cast({:message_sorter_value, {:goals, level}, _classification, goals, status}, state) do
    goals_default = if (level == state.default_control_cmds_level), do: goals, else: state.goals_default
    goals_store =
    if (status == :current) do
      Map.put(state.goals_store, level, goals)
    else
      Map.drop(state.goals_store, [level])
    end
    {:noreply, %{state | goals_store: goals_store, goals_default: goals_default}}
  end

  @impl GenServer
  def handle_info(:navigator_loop, state) do
    # Start with Goals cs_rates, move through goals cs_sca
    # If there a no current commands, then take the command from default_control_cmds_level
    default_result = {state.goals_default, state.default_control_cmds_level}
    {control_cmds, control_state} = get_highest_level_active_goals(CU.cs_sca, state.goals_store, default_result)

    MessageSorter.Sorter.add_message(:control_state, state.control_state_msg_classification, state.control_state_msg_time_validity_ms, control_state)
    MessageSorter.Sorter.add_message({:control_cmds, control_state}, state.control_cmds_msg_classification, state.control_cmds_msg_time_validity_ms, control_cmds)
    Peripherals.Uart.Telemetry.Operator.store_data(%{control_state: control_state})
    {:noreply, state}
  end

  @spec get_highest_level_active_goals(integer(), map(), map()) :: tuple()
  def get_highest_level_active_goals(_, goals_store, default_result) when goals_store == %{} do
    default_result
  end

  @spec get_highest_level_active_goals(integer(), map(), map()) :: tuple()
  def get_highest_level_active_goals(level, goals_store, default_result) do
    case Map.pop(goals_store, level) do
      {nil, remaining_goals} -> get_highest_level_active_goals(level-1, remaining_goals, default_result)
      {goals, _} -> {goals, level}
    end
  end
end
