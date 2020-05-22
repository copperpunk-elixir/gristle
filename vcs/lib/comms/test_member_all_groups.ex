defmodule Comms.TestMemberAllGroups do
  use GenServer
  require Logger

  def start_link() do
    {:ok, pid} = Common.Utils.start_link_redudant(GenServer, __MODULE__, nil, __MODULE__)
    Comms.Operator.start_link(%{name: __MODULE__})
    GenServer.cast(__MODULE__, :join_all_groups)
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{
        pv_values_estimator: %{},
        pv_values_pid_system: %{},
        pv_calculated: %{},
        pv_cmds: %{}
     }}
  end

  @impl GenServer
  def handle_cast(:join_all_groups, state) do
    Comms.Operator.join_group(__MODULE__, {:pv_values, :attitude_body_rate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
    # Comms.Operator.join_group(__MODULE__, {:pv_calculated, :attitude_body_rate}, self())
    # Comms.Operator.join_group(__MODULE__, {:pv_calculated, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, 1}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, 2}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, 3}, self())
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
      #   :attitude_body_rate ->
      #     Map.put(state.pv_values, :attitude, values.attitude)
      #     |> Map.put(:body_rate, values.body_rate)
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
  def handle_cast({{:pv_cmds_values, level}, pv_cmd_map, pv_value_map, _dt}, state ) do
    Logger.debug("Test member rx: pv_cmds_values #{level}, cmds: #{inspect(pv_cmd_map)}")
    pv_cmds = Map.merge(state.pv_cmds, pv_cmd_map)
    pv_value_type =
      case level do
        3 -> :position_velocity
        2 -> :position_velocity
        1 -> :attitude_body_rate
      end
    pv_values = get_pvs_from_map(pv_value_map, pv_value_type, state.pv_values_pid_system)
    {:noreply, %{state | pv_cmds: pv_cmds, pv_values_pid_system: pv_values}}
  end

  @impl GenServer
  def handle_call({:get_value, key}, _from, state) do
    Logger.debug("get value for key: #{inspect(key)}")
    {:reply, get_in(state, key), state}
  end

  def get_value(key) do
    GenServer.call(__MODULE__, {:get_value, key})
  end

  def get_pvs_from_map(pv_map, value_type, pvs_to_update) do
      case value_type do
        :position_velocity ->
          Map.put(pvs_to_update, :position, pv_map.position)
          |> Map.put(:velocity, pv_map.velocity)
        :attitude_body_rate ->
          Map.put(pvs_to_update, :attitude, pv_map.attitude)
          |> Map.put(:body_rate, pv_map.body_rate)
      end


  end

end
