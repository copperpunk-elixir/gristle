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
    {:ok, %{
        navigator_loop_timer: nil,
        navigator_loop_interval_ms: config.imu_loop_interval_ms,
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    # Start sorters
    MessageSorter.System.start_link()
        Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, :goals, self())
    navigator_loop_timer = Common.Utils.start_loop(self(), state.navigator_loop_interval_ms, :navigator_loop)
    {:noreply, %{state | navigator_loop_timer: navigator_loop_timer}}
  end

  defp start_goal_restrictions_sorter(vehicle_type) do
    # Goal Restrictions
    vehicle_module = Module.concat([__MODULE__, vehicle_type])
    level_pv_sorter_map = apply(vehicle_module, :get_process_variable_map, [])
    pv_default_value_map = get_in(level_pv_sorter_map, [3, :default_value])
    Enum.each(pv_default_value_map, fn {pv, _default_value} ->
      config = %{
      name: {:goal_restrictions, pv},
      default_message_behavior: :default_value,
      default_value: nil,
      value_type: :number
    }
      MessageSorter.System.start_sorter(config)
    end)
    # MessageSorter.System.start_sorter(:goals)
    # MessageSorter.System.start_sorter(:control_state)
  end
 
  defp start_goals_sorter(vehicle_type) do
    generic_config = %{
      default_message_behavior: :default_value,
      default_value: nil,
    }
    vehicle_module = Module.concat([__MODULE__, vehicle_type])
    level_pv_sorter_map = apply(vehicle_module, :get_process_variable_map, [])

    goals_1_config =
      %{generic_config |
        name: {:goals, 1},
        default_value: get_in(level_pv_sorter_map, [1, :default_value]),
        value_type: :map
       }

    attitude_config =
      %{generic_config |
        name: {:goals, :attitude},
        default_value: get_in(level_pv_sorter_map, [2, :default_value]),
        value_type: :map
       }
  end
  

end
