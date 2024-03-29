defmodule Comms.TestMemberAllGroups do
  use GenServer
  require Logger

  def start_link() do
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    Comms.System.start_operator(__MODULE__)
    GenServer.cast(__MODULE__, :join_all_groups)
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{
        pv_values_estimator: %{},
        pv_values_pid_system: %{},
        pv_calculated: %{},
        control_cmds: %{},
        goals: %{},
     }}
  end

  @impl GenServer
  def handle_cast(:join_all_groups, state) do
    Comms.Operator.join_group(__MODULE__, {:pv_values, :attitude_bodyrate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
    # Comms.Operator.join_group(__MODULE__, {:pv_calculated, :attitude_bodyrate}, self())
    # Comms.Operator.join_group(__MODULE__, {:pv_calculated, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, {:control_cmds_values, 1}, self())
    Comms.Operator.join_group(__MODULE__, {:control_cmds_values, 2}, self())
    Comms.Operator.join_group(__MODULE__, {:control_cmds_values, 3}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 1}, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_values, value_type}, values, _dt}, state) do
    Logger.debug("Test Member rx: pv_values/#{value_type}/#{inspect(values)}")
    pv_values = get_pvs_from_map(values, value_type, state.pv_values_estimator)
      # case value_type do
      #   :position_velocity ->
      #     Map.put(state.pv_values, :position, values.position)
      #     |> Map.put(:velocity, values.velocity)
      #   :attitude_bodyrate ->
      #     Map.put(state.pv_values, :attitude, values.attitude)
      #     |> Map.put(:bodyrate, values.bodyrate)
      # end
    # Logger.debug("pv values: #{inspect(pv_values)}")
    {:noreply, %{state | pv_values_estimator: pv_values}}
  end

  @impl GenServer
  def handle_cast({{:pv_calculated, value_type}, values}, state) do
    Logger.debug("Test Member rx: pv_calculated/#{value_type}/#{inspect(values)}")
    pv_calculated = get_pvs_from_map(values, value_type, state.pv_calculated)
    {:noreply, %{state | pv_calculated: pv_calculated}}
  end

  @impl GenServer
  def handle_cast({{:control_cmds_values, level}, pv_cmd_map, pv_value_map, _dt}, state ) do
    Logger.debug("Test member rx: control_cmds_values #{level}, cmds: #{inspect(pv_cmd_map)}")
    control_cmds = Map.merge(state.control_cmds, pv_cmd_map)
    pv_value_type =
      case level do
        3 -> :position_velocity
        2 -> :position_velocity
        1 -> :attitude_bodyrate
      end
    pv_values = get_pvs_from_map(pv_value_map, pv_value_type, state.pv_values_pid_system)
    {:noreply, %{state | control_cmds: control_cmds, pv_values_pid_system: pv_values}}
  end

  @impl GenServer
  def handle_cast({{:goals, level},_class, _time, goals}, state) do
    state_goals = Map.put(state.goals, level, goals)
    {:noreply, %{state | goals: state_goals}}
  end

  @impl GenServer
  def handle_call({:get_value, key}, _from, state) do
    Logger.debug("get value for key: #{inspect(key)}")
    {:reply, get_in(state, key), state}
  end

  @impl GenServer
  def handle_call({:get_goals, level}, _from, state) do
    {:reply, Map.get(state.goals, level), state}
  end

  def get_value(key) do
    GenServer.call(__MODULE__, {:get_value, key})
  end

  def get_pvs_from_map(pv_map, value_type, pvs_to_update) do
      case value_type do
        :position_velocity ->
          Map.put(pvs_to_update, :position, pv_map.position)
          |> Map.put(:velocity, pv_map.velocity)
        :attitude_bodyrate ->
          Map.put(pvs_to_update, :attitude, pv_map.attitude)
          |> Map.put(:bodyrate, pv_map.bodyrate)
      end
  end

  def get_goals(level) do
    GenServer.call(__MODULE__, {:get_goals, level})
  end
end
