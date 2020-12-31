defmodule Navigation.PathManager do
  use GenServer
  require Logger

  @pi_2 1.5708796

  def start_link(config) do
    Logger.info("Start Navigation.PathManager GenServer")
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
    {goals_classification, goals_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :goals)
    {flaps_cmd_class, flaps_cmd_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, {:direct_actuator_cmds, :flaps})
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
      speed: nil,
      course: nil,
      stored_current_cp_index: nil,
      stored_current_path_case: nil,
      orbit_active: false
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, :load_mission, self())
    Comms.Operator.join_group(__MODULE__, :clear_mission, self())
    Comms.Operator.join_group(__MODULE__, :load_orbit, self())
    Comms.Operator.join_group(__MODULE__, :clear_orbit, self())
    {:noreply, state}
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
  def handle_cast({{:pv_values, :position_velocity}, position, velocity, _dt}, state) do
    # Determine path_case
    # Get vehicle_cmds
    # Send to Navigator
    speed = velocity.speed
    course = velocity.course
    # airspeed = velocity.airspeed
    current_case_index = if is_nil(state.current_path_case), do: -1, else: state.current_path_case.case_index
    state = move_vehicle(position, state, current_case_index)
    current_path_case = state.current_path_case
    # If we have a path_case, then follow it
    unless is_nil(current_path_case) do
      # Logger.debug("cpc_i: #{current_path_case.case_index}")
      # Logger.debug("cpc: #{inspect(current_path_case)}")
      {speed_cmd, course_cmd, altitude_cmd} = Navigation.Path.PathFollower.follow(state.path_follower, position, course, speed, current_path_case)
      goals = %{speed: speed_cmd, altitude: altitude_cmd}
      path_case_type = current_path_case.type
      goals =
        case path_case_type do
          :flight -> Map.put(goals, :course_flight, course_cmd)
          :climbout ->
            agl_error = agl_error(altitude_cmd, state.takeoff_altitude, position.agl)
            altitude_cmd = position.altitude + agl_error
            Map.put(goals, :course_flight, course_cmd)
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
              |> Map.put(:course_ground, course_cmd)
            else
              Map.put(goals, :course_flight, course_cmd)
            end
          :landing->
            agl_error = agl_error(altitude_cmd, state.landing_altitude, position.agl)
            altitude_cmd = position.altitude + agl_error
            if (position.agl < state.vehicle_agl_ground_threshold) do
              Map.put(goals, :course_ground, course_cmd)
            else
              Map.put(goals, :course_flight, course_cmd)
            end
            |> Map.put(:altitude, altitude_cmd)
          :approach->
            agl_error = agl_error(altitude_cmd, state.landing_altitude, position.agl)
            altitude_cmd = position.altitude + agl_error
            Map.put(goals, :course_flight, course_cmd)
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
    {:noreply, %{state | position: position, speed: speed, course: course}}
  end

  @impl GenServer
  def handle_call(:get_config_points, _from, state) do
    {:reply, state.config_points, state}
  end

  @impl GenServer
  def handle_call(:get_current_path_distance, _from, state) do
    {:reply, state.current_path_distance, state}
  end

  @spec move_vehicle(map(), map(), integer()) :: map()
  def move_vehicle(position, state, path_case_index_prev) do
    temp_case_index =
      case state.current_cp_index do
        nil -> -1
        index ->
          # Logger.debug("cp_index/path_case_index: #{index}/#{state.current_path_case.case_index}")
          current_cp = Enum.at(state.config_points, index)
          Navigation.Dubins.Utils.check_for_path_case_completion(position, current_cp, state.current_path_case)
      end
    {current_cp_index, current_path_case} =
      case temp_case_index do
        -1 ->
          # Logger.error("No config points. Follow path_case if it exists")
          {nil, state.current_path_case}
        5 ->
          # Completed this control point
          # if there is a goto, then go to it
          current_cp = Enum.at(state.config_points, state.current_cp_index)
          current_cp_index =
            case current_cp.goto_upon_completion do
              nil ->
                Logger.info("no goto, move to cp_index: #{state.current_cp_index + 1}")
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
            nil -> {nil, nil}
            index ->
              new_dubins = Enum.at(state.config_points, index) |> Map.get(:dubins)
              path_case_index = if (new_dubins.skip_case_0 == true), do: 1, else: 0
              path_case = Enum.at(new_dubins.path_cases, path_case_index)
              {index, path_case}
          end
        index ->
          current_cp = Enum.at(state.config_points, state.current_cp_index)
          {state.current_cp_index, Enum.at(current_cp.dubins.path_cases, index)}
      end
    state = %{state | current_cp_index: current_cp_index, current_path_case: current_path_case}
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
    agl_error = agl_cmd - agl
    agl_error
  end

  @spec process_load_mission(struct(), boolean(), map()) :: map()
  def process_load_mission(mission, confirmation, state) do
    mission =
    if is_nil(state.speed) or (state.speed < 1.0) do
      mission
    else
      Logger.warn("add current position")
      Navigation.Path.Mission.add_current_position_to_mission(mission, state.position, state.speed, state.course)
    end
    # Logger.debug("path manager load mission: #{mission.name}")
    {config_points, current_path_distance} = Navigation.Dubins.Utils.config_points_from_waypoints(mission.waypoints, mission.vehicle_turn_rate)
    current_cp = Enum.at(config_points, 0)
    current_path_case = Enum.at(current_cp.dubins.path_cases,0)
    takeoff_altitude = Enum.at(config_points, 0) |> Map.get(:z2) |> Map.get(:altitude)
    landing_altitude = Enum.at(config_points, -1) |> Map.get(:z2) |> Map.get(:altitude)
    Logger.debug("landing altitude: #{landing_altitude}")
    state = %{
      state |
      config_points: config_points,
      current_cp_index: 0,
      current_path_case: current_path_case,
      current_path_distance: current_path_distance,
      takeoff_altitude: takeoff_altitude,
      landing_altitude: landing_altitude,
      orbit_active: false
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
    Logger.debug("path manager load orbit: #{radius}")
    if is_nil(position), do: Logger.warn("no orbit position")
    {_turn_rate, speed, radius} = Navigation.Path.Mission.calculate_orbit_parameters(state.model_type, radius)
    position = if is_nil(position), do: state.position, else: position
    if is_nil(position) or is_nil(state.course) do
      Logger.warn("no position. can't load orbit")
      state
    else
      Logger.debug("position: #{Common.Utils.LatLonAlt.to_string(position)}")
      path_case = new_orbit_path_case(position, state.course, speed, radius, orbit_type)
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

  @spec get_config_points() :: struct()
  def get_config_points() do
    GenServer.call(__MODULE__, :get_config_points)
  end

  @spec get_current_path_distance() :: float()
  def get_current_path_distance() do
    GenServer.call(__MODULE__, :get_current_path_distance)
  end
end
