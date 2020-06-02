defmodule Navigation.Navigator do
  use GenServer
  require Logger

  @default_pv_cmds_level 3

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
        default_pv_cmds_level: Map.get(config, :default_pv_cmds_level, @default_pv_cmds_level),
        navigator_loop_timer: nil,
        navigator_loop_interval_ms: config.navigator_loop_interval_ms,
        position_velocity: %{position: %{latitude: 0, longitude: 0, altitude: 0}, velocity: %{north: 0, east: 0, down: 0}},
        # attitude_bodyrate: %{attitude: %{roll: 0, pitch: 0, yaw: 0}, bodyrate: %{rollrate: 0, pitchrate: 0, yawrate: 0}}
        yaw: 0
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    # Start sorters
    Comms.Operator.join_group(__MODULE__, {:pv_values, :attitude_bodyrate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, -1}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 0}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 1}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 2}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 3}, self())
    Comms.Operator.join_group(__MODULE__, {:goals, 4}, self())
    # Comms.Operator.join_group(__MODULE__, {:goals_relative, 2}, self())
    Comms.Operator.join_group(__MODULE__, {:goals_relative, 3}, self())
    # start_goals_sorter(state.vehicle_module)
    # start_command_state_sorter(state.vehicle_module)
    navigator_loop_timer = Common.Utils.start_loop(self(), state.navigator_loop_interval_ms, :navigator_loop)
    # apply(state.vehicle_module, :start_pv_cmds_message_sorters, [])
    {:noreply, %{state | navigator_loop_timer: navigator_loop_timer}}
  end

  # @impl GenServer
  def handle_cast({{:pv_values, :attitude_bodyrate}, attitude_bodyrate, _dt}, state) do
    {:noreply, %{state | yaw: attitude_bodyrate.attitude.yaw}}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :position_velocity}, position_velocity, _dt}, state) do
    {:noreply, %{state | position_velocity: position_velocity}}
  end

  @impl GenServer
  def handle_cast({{:goals, level},classification, time_validity_ms, goals_map}, state) do
    # Logger.warn("rx goals #{level} from #{inspect(classification)}: #{inspect(goals_map)}")
    MessageSorter.Sorter.add_message({:goals, level}, classification, time_validity_ms, goals_map)
    {:noreply, state}
  end

  # @impl GenServer
  # def handle_cast({{:goals_relative, 2}, classification, time_validity_ms, goals_map}, state) do
  #   # Logger.debug("rx goals rel: #{inspect(goals_map)}")
  #   # yaw_actual = state.attitude_bodyrate.attitude.yaw
  #   # yaw_cmd =
  #   #   yaw_actual + goals_map.yaw
  #   #   |> Common.Utils.turn_left_or_right_for_correction()
  #   #   |> Common.Utils.constrain_angle_to_compass()
  #   # new_goals_map = Map.put(goals_map, :yaw, yaw_cmd)
  #   Logger.debug("new goals: #{inspect(new_goals_map)}")
  #   MessageSorter.Sorter.add_message({:goals, 2}, classification, time_validity_ms, new_goals_map)
  #   {:noreply, state}
  # end

  @impl GenServer
  def handle_cast({{:goals_relative, 3}, classification, time_validity_ms, goals_map}, state) do
    velocity = state.position_velocity.velocity
    {speed_actual, course_actual} = Common.Utils.get_speed_course_for_velocity(velocity.north, velocity.east, 2, state.yaw)
    speed_cmd = speed_actual + Map.get(goals_map, :speed, 0)
    course_cmd =
      course_actual + Map.get(goals_map, :course, 0)
      |> Common.Utils.turn_left_or_right_for_correction()

    new_goals_map = %{speed: speed_cmd, course: course_cmd}
    new_goals_map =
    if Map.has_key?(goals_map, :altitude) do
      altitude_cmd = state.position.altitude + Map.get(goals_map, :altitude, 0)
      Map.put(new_goals_map, :altitude, altitude_cmd)
    else
      new_goals_map
    end
    MessageSorter.Sorter.add_message({:goals, 3}, classification, time_validity_ms, new_goals_map)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:navigator_loop, state) do
    # Start with Goals 4, move through goals 1
    # If there a no current commands, then take the command from default_pv_cmds_level
    {pv_cmds, control_state} = Enum.reduce(4..-1, {%{}, nil}, fn (pv_cmd_level, acc) ->
      {cmd_values, cmd_status} = MessageSorter.Sorter.get_value_with_status({:goals, pv_cmd_level})
      if (cmd_status == :current) do
        {cmd_values, pv_cmd_level}
      else
        acc
      end
    end)
    {pv_cmds, control_state} =
    if Enum.empty?(pv_cmds) do
      control_state = state.default_pv_cmds_level
      {MessageSorter.Sorter.get_value({:goals, control_state}), control_state}
    else
      {pv_cmds, max(1,control_state)}
    end
    MessageSorter.Sorter.add_message(:control_state, [0,1], 2*state.navigator_loop_interval_ms, control_state)
    MessageSorter.Sorter.add_message({:pv_cmds, control_state}, [0,1], 2*state.navigator_loop_interval_ms, pv_cmds)
    {:noreply, state}
  end
end
