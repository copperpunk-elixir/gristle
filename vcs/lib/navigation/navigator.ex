defmodule Navigation.Navigator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Navigation.Navigator")
    {:ok, pid} = Common.Utils.start_link_redudant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    vehicle_type = config.vehicle_type
    vehicle_module = Module.concat([Vehicle, vehicle_type])
    Logger.debug("Vehicle module: #{inspect(vehicle_module)}")
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_module: vehicle_module,
        navigator_loop_timer: nil,
        navigator_loop_interval_ms: config.navigator_loop_interval_ms,
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    # Start sorters
    MessageSorter.System.start_link()
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 1}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 2}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 3}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 4}, self())
    navigator_loop_timer = Common.Utils.start_loop(self(), state.navigator_loop_interval_ms, :navigator_loop)
    start_goals_sorter(state.vehicle_module)
    apply(state.vehicle_module, :start_pv_cmds_message_sorters, [])
    {:noreply, %{state | navigator_loop_timer: navigator_loop_timer}}
  end

  @impl GenServer
  def handle_cast({{:goals, level},classification, time_validity_ms, goals_map}, state) do
    Logger.warn("rx goals #{level} from #{inspect(classification)}: #{inspect(goals_map)}")
    MessageSorter.Sorter.add_message({:goals, level}, classification, time_validity_ms, goals_map)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:navigator_loop, state) do
    # goals_2 = MessageSorter.Sorter.get_value({:goals, 2})
    # MessageSorter.Sorter.add_message({:pv_cmds, 2}, [0,1], 200, goals_2)
    {:noreply, state}
  end

  @spec start_goals_sorter(atom()) :: atom()
  defp start_goals_sorter(vehicle_module) do
    level_pv_sorter_list = apply(vehicle_module, :get_process_variable_list, [])
    Enum.each(level_pv_sorter_list,fn pv_cmds_config ->
      {:pv_cmds, level} = pv_cmds_config.name
      goals_config = %{pv_cmds_config | name: {:goals, level}}
     MessageSorter.System.start_sorter(goals_config)
    end)
  end

end
