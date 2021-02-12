defmodule Navigation.PathManager do
  use GenServer
  require Logger

  @pi_2 1.5708796

  def start_link(config) do
    Logger.debug("Start Navigation.PathManager")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(pid, {:begin, config})
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
    {goals_classification, goals_time_validity_ms} = Configuration.Module.MessageSorter.get_message_sorter_classification_time_validity_ms(__MODULE__, :goals)
    {flaps_cmd_class, flaps_cmd_time_ms} = Configuration.Module.MessageSorter.get_message_sorter_classification_time_validity_ms(__MODULE__, {:direct_actuator_cmds, :flaps})
    state = %{
      vehicle_loiter_speed: Keyword.fetch!(config, :vehicle_loiter_speed),
      vehicle_agl_ground_threshold: Keyword.fetch!(config, :vehicle_agl_ground_threshold),
      vehicle_takeoff_speed: Keyword.fetch!(config, :vehicle_takeoff_speed),
      model_type: Keyword.fetch!(config, :model_type),
      # vehicle_max_ground_speed: Keyword.fetch!(config, :vehicle_max_ground_speed),
      goals_classification: goals_classification,
      goals_time_validity_ms: goals_time_validity_ms,
      flaps_cmd_class: flaps_cmd_class,
      flaps_cmd_time_ms: flaps_cmd_time_ms,
      config_points: [],
      current_cp_index: nil,
      current_path_case: nil,
      current_path_distance: 0,
      landing_altitude: 0,
      takeoff_altitude: 0,
      path_follower: Navigation.Path.PathFollower.new(Keyword.fetch!(config, :path_follower)),
      position: nil,
      velocity: nil,
      stored_current_cp_index: nil,
      stored_current_path_case: nil,
      orbit_active: false,
      peripheral_path: nil,
      on_deck_peripheral_path: nil,
      peripheral_control_allowed: false
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:estimation_values, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, :load_mission, self())
    Comms.Operator.join_group(__MODULE__, :clear_mission, self())
    Comms.Operator.join_group(__MODULE__, :load_orbit, self())
    Comms.Operator.join_group(__MODULE__, :clear_orbit, self())
    Comms.Operator.join_group(__MODULE__, :peripheral_paths_sorter, self())
    Comms.Operator.join_group(__MODULE__, :change_peripheral_control, self())
    Registry.register(MessageSorterRegistry, {:peripheral_paths, :value}, config[:peripheral_paths_update_interval_ms])
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:peripheral_paths_sorter, classification, time_validity_ms, path_command_map}, state) do
    Logger.debug("rx path  from #{inspect(classification)}: #{inspect(path_command_map)}")
    path_command_map = Map.put(path_command_map, :path_id, System.system_time())
    MessageSorter.Sorter.add_message(:peripheral_paths, classification, time_validity_ms, path_command_map)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:change_peripheral_control, control_allowed}, state) do
    Logger.debug("PM pca: #{control_allowed}")
    # If we are going from "allowed" to "not allowed", we must process as though the path is now nil
    state =
    if !control_allowed and state.peripheral_control_allowed do
      Logger.debug("pca no longer allowed")
      process_peripheral_path(state, nil)
    else
      state
    end
    {:noreply, %{state | peripheral_control_allowed: control_allowed}}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, :peripheral_paths, path_command, _status}, state) do
    on_deck_peripheral_path = if state.peripheral_control_allowed, do: path_command, else: nil
    {:noreply, %{state | on_deck_peripheral_path: on_deck_peripheral_path}}
  end

  @impl GenServer
  def handle_cast({:load_mission, mission, confirmation}, state) do
    state = process_load_mission(mission, confirmation, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:clear_mission, iTOW}, state) do
    state = process_clear_mission(iTOW, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:load_orbit, orbit_type, position, radius, confirmation}, state) do
    state = process_load_orbit(orbit_type, position, radius, confirmation, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:clear_orbit, confirmation}, state) do
    state = process_clear_orbit(confirmation, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:estimation_values, :position_velocity}, position, velocity, _dt}, state) do
    # Determine path_case
    # Get vehicle_cmds
    # Send to Navigator
    speed = velocity.speed
    course = velocity.course
    # airspeed = velocity.airspeed
    state = if state.peripheral_control_allowed, do: process_peripheral_path(state, state.on_deck_peripheral_path), else: state

    current_case_index = if is_nil(state.current_path_case), do: -1, else: state.current_path_case.case_index
    state = move_vehicle(position, state, current_case_index)
    current_path_case = state.current_path_case
    # If we have a path_case, then follow it
    unless is_nil(current_path_case) do
      # Logger.debug("cpc_i: #{current_path_case.case_index}")
      # Logger.debug("cpc: #{inspect(current_path_case)}")
      {speed_cmd, course_cmd, altitude_cmd} = Navigation.Path.PathFollower.follow(state.path_follower, position, course, speed, current_path_case)
      course_rotate_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - course)
      goals = %{speed: speed_cmd, altitude: altitude_cmd, course_rotate: course_rotate_cmd}
      path_case_type = current_path_case.type
      goals =
        case path_case_type do
          :flight ->
            Map.put(goals, :course_tilt, course_cmd)
          :climbout ->
            agl_error = agl_error(altitude_cmd, state.takeoff_altitude, position.agl)
            altitude_cmd = position.altitude + agl_error
            Map.put(goals, :course_tilt, course_cmd)
            |> Map.put(:altitude, altitude_cmd)
          :ground ->
            if (position.agl < state.vehicle_agl_ground_threshold) do
              if (speed < state.vehicle_takeoff_speed) do
                Map.put(goals, :altitude, position.altitude)
              else
                agl_error = agl_error(altitude_cmd, state.takeoff_altitude, position.agl)
                altitude_cmd = position.altitude + agl_error
                Map.put(goals, :altitude, altitude_cmd)
              end
              |> Map.put(:course_tilt, course)
            else
              Map.put(goals, :course_tilt, course_cmd)
            end
          :landing->
            agl_error = agl_error(altitude_cmd, state.landing_altitude, position.agl)
            altitude_cmd = position.altitude + agl_error
            if (position.agl < state.vehicle_agl_ground_threshold) do
              Map.put(goals, :course_tilt, course)
            else
              Map.put(goals, :course_tilt, course_cmd)
            end
            |> Map.put(:altitude, altitude_cmd)

          :approach->
            agl_error = agl_error(altitude_cmd, state.landing_altitude, position.agl)
            altitude_cmd = position.altitude + agl_error
            Map.put(goals, :course_tilt, course_cmd)
            |> Map.put(:altitude, altitude_cmd)
        end

      # Send goals to message sorter
      MessageSorter.Sorter.add_message({:goals, 3}, state.goals_classification, state.goals_time_validity_ms, goals)
      # Direct Commands
      flaps_cmd =
        case path_case_type do
          :ground -> 0.5
          :climbout -> 0.5
          :flight -> 0.0
          :approach -> 1.0
          :landing -> 1.0
          _other -> 0.0
        end
      MessageSorter.Sorter.add_message({:direct_actuator_cmds, :flaps}, state.flaps_cmd_class, state.flaps_cmd_time_ms, flaps_cmd)
    end
    {:noreply, %{state | position: position, velocity: velocity}}
  end

  @spec move_vehicle(map(), map(), integer()) :: map()
  def move_vehicle(position, state, path_case_index_prev) do
    # If peripheral cases are allowed, check for one, and process it if available
    temp_case_index =
      case state.current_cp_index do
        nil -> -1
        index ->
          # Logger.debug("cp_index/path_case_index: #{index}/#{state.current_path_case.case_index}")
          current_cp = Enum.at(state.config_points, index)
          Navigation.Dubins.Utils.check_for_path_case_completion(position, current_cp, state.current_path_case)
      end
    {current_cp_index, current_path_case, peripheral_control_allowed} =
      case temp_case_index do
        -1 ->
          # Logger.error("No config points. Follow path_case if it exists")
          {nil, state.current_path_case, state.peripheral_control_allowed}
        5 ->
          # Completed this control point
          # if there is a goto, then go to it
          current_cp = Enum.at(state.config_points, state.current_cp_index)
          current_cp_index =
            case current_cp.goto_upon_completion do
              nil ->
                Logger.debug("no goto, move to cp_index: #{state.current_cp_index + 1}")
                cp_index = state.current_cp_index + 1
                if cp_index >= length(state.config_points) do
                  # No more waypoints
                  Logging.Logger.save_log("mission_complete")
                  nil
                else
                  cp_index
                end
              wp_name ->
                index = Common.Utils.index_for_embedded_value(state.config_points, :name, wp_name)
                Logger.debug("goto: #{index} for wp: #{wp_name}")
                index
            end
          case current_cp_index do
            nil -> {nil, nil, state.peripheral_control_allowed}
            index ->
              new_config_point = Enum.at(state.config_points, index)
              new_dubins = Map.get(new_config_point, :dubins)
              path_case_index = if (new_dubins.skip_case_0 == true), do: 1, else: 0
              path_case = Enum.at(new_dubins.path_cases, path_case_index)
              {index, path_case, new_config_point.peripheral_control_allowed}
          end
        index ->
          current_cp = Enum.at(state.config_points, state.current_cp_index)
          {state.current_cp_index, Enum.at(current_cp.dubins.path_cases, index), state.peripheral_control_allowed}
      end
    state = %{state | current_cp_index: current_cp_index, current_path_case: current_path_case, peripheral_control_allowed: peripheral_control_allowed}
    if (temp_case_index != path_case_index_prev) do
      move_vehicle(position, state, temp_case_index)
    else
      state
    end
  end

  @spec new_orbit_path_case(struct(), float(), float(), float(), atom()) :: map()
  def new_orbit_path_case(position, course, speed, radius, orbit_type) do
    direction = if radius > 0, do: 1, else: -1
    course_offset = direction*@pi_2
    radius = radius*direction
    radius_center =
      case orbit_type do
        :centered -> position
        :inline ->  Common.Utils.Location.lla_from_point_with_distance(position, radius, course + course_offset)
        _other -> raise "Invalid orbit_type"
      end
    path_case = Navigation.Dubins.PathCase.new_orbit(-1, :flight)
    %{
      path_case |
      v_des: speed,
      c: radius_center,
      rho: radius,
      turn_direction: direction
    }
  end

  @spec agl_error(float(), float(), float()) :: float()
  def agl_error(altitude_cmd, landing_altitude, agl) do
    agl_cmd = altitude_cmd - landing_altitude
    agl_cmd - agl
  end

  @spec process_peripheral_path(map(), map()) :: map()
  def process_peripheral_path(state, on_deck_path) do
    # on_deck_path = state.on_deck_peripheral_path
    current_path = if is_nil(state.peripheral_path), do: %{}, else: state.peripheral_path
    path_id = if is_nil(on_deck_path), do: nil, else: on_deck_path.path_id
    # This is a new command
    cond do
      is_nil(on_deck_path) ->
        case Map.get(current_path, :class) do
          :orbit -> process_clear_orbit(true, state)
          # :goto ->
          # :sca ->
          _other -> state
        end
        |> Map.put(:peripheral_path, nil)
      path_id == Map.get(current_path, :path_id) -> state
      true ->
        Logger.debug("process on deck path")
        case on_deck_path.class do
          :orbit -> process_load_orbit(on_deck_path.type, on_deck_path.position, on_deck_path.radius, on_deck_path.confirmation, state)
          _other ->
            Logger.warn("unsupported path class")
            state
        end
        |> Map.put(:peripheral_path, on_deck_path)
    end
  end

  @spec process_load_mission(struct(), boolean(), map()) :: map()
  def process_load_mission(mission, confirmation, state) do
    speed = get_in(state, [:velocity, :speed])
    mission =
    if is_nil(speed) or (speed < 1.0) do
      mission
    else
      Logger.debug("add current position")
      Navigation.Path.Mission.add_current_position_to_mission(mission, state.position, speed, state.velocity.course)
    end
    # Logger.debug("path manager load mission: #{mission.name}")
    {config_points, current_path_distance} = Navigation.Dubins.Utils.config_points_from_waypoints(mission.waypoints, mission.vehicle_turn_rate)
    current_cp = Enum.at(config_points, 0)
    current_path_case = Enum.at(current_cp.dubins.path_cases,0)
    takeoff_altitude = Enum.at(config_points, 0) |> Map.get(:z2) |> Map.get(:altitude)
    landing_altitude = Enum.at(config_points, -1) |> Map.get(:z2) |> Map.get(:altitude)
    peripheral_control_allowed = current_cp.peripheral_control_allowed
    Logger.debug("landing altitude: #{landing_altitude}")
    state = %{
      state |
      config_points: config_points,
      current_cp_index: 0,
      current_path_case: current_path_case,
      current_path_distance: current_path_distance,
      takeoff_altitude: takeoff_altitude,
      landing_altitude: landing_altitude,
      orbit_active: false,
      peripheral_control_allowed: peripheral_control_allowed
    }
    if (confirmation) do
      pb_encoded = Navigation.Path.Mission.encode(mission, false, true)
      Peripherals.Uart.Generic.construct_and_send_proto_message(:mission_proto, pb_encoded, Peripherals.Uart.Telemetry.Operator)
    end
    state
  end

  @spec process_clear_mission(float(), map()) :: map()
  def process_clear_mission(iTOW, state) do
    Logger.debug("clear mission iTOW: #{iTOW}")
    %{
      state |
      config_points: [],
      current_cp_index: nil,
      current_path_case: nil,
      current_path_distance: 0,
      takeoff_altitude: 0,
      landing_altitude: 0,
    }
  end

  @spec process_load_orbit(atom(), struct(), float(), integer(), map()) :: map()
  def process_load_orbit(orbit_type, position, radius, confirmation, state) do
    course = get_in(state, [:velocity, :course])
    Logger.debug("path manager load orbit: #{radius}")
    {_turn_rate, speed, radius} = Navigation.Path.Mission.calculate_orbit_parameters(state.model_type, radius)
    position = if is_nil(position), do: state.position, else: position
    if is_nil(position) or is_nil(course) do
      Logger.warn("no position. can't load orbit")
      state
    else
      Logger.debug("position: #{Common.Utils.LatLonAlt.to_string(position)}")
      path_case = new_orbit_path_case(position, course, speed, radius, orbit_type)
      Logger.debug("valid load orbit: #{inspect(path_case)}")
      # Confirm orbit
      if confirmation do
        center = path_case.c
        Navigation.PathPlanner.send_orbit_confirmation(radius, center.latitude, center.longitude, center.altitude)
      end
      # Logger.debug("current cpi/cpc: #{inspect(state.current_cp_index)}/#{inspect(state.current_path_case)}")
      if state.orbit_active do
        %{
          state | current_path_case: path_case
        }
      else
        %{
          state |
          current_path_case: path_case,
          current_cp_index: nil,
          stored_current_cp_index: state.current_cp_index,
          stored_current_path_case: state.current_path_case,
          orbit_active: true
        }
      end
    end
  end

  @spec process_clear_orbit(boolean(), map()) :: map()
  def process_clear_orbit(confirmation, state) do
    Logger.debug("path man clear orbit")
    Logger.debug("orbit active? #{state.orbit_active}")
    if confirmation do
      Logger.debug("confirm clear orbit")
      Peripherals.Uart.Generic.construct_and_send_message(:clear_orbit, [0], Telemetry)
    end

    if state.orbit_active do
      %{
        state |
        current_cp_index: state.stored_current_cp_index,
        current_path_case: state.stored_current_path_case,
        stored_current_cp_index: nil,
        stored_current_path_case: nil,
        orbit_active: false
      }
    else
      state
    end
  end
end
