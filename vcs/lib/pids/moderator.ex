defmodule Pids.Moderator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Pids.Moderator GenServer")
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
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
    {act_msg_class, act_msg_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :indirect_actuator_cmds)
    {pv_msg_class, pv_msg_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :pv_cmds)
    attitude_scalar = Enum.reduce(Keyword.fetch!(config, :attitude_scalar), %{}, fn ({cv_pv, scalar}, acc) ->
      Map.put(acc, cv_pv, Enum.into(scalar, %{}))
    end)
    vehicle_type = String.to_existing_atom(config[:vehicle_type])
    bodyrate_module = Module.concat(Pids.Bodyrate, vehicle_type)
    attitude_module = Module.concat(Pids.Attitude, vehicle_type)
    high_level_module = Module.concat(Pids.HighLevel, vehicle_type)
    state = %{
      attitude_scalar: attitude_scalar,
      act_msg_class: act_msg_class,
      act_msg_time_ms: act_msg_time_ms,
      pv_msg_class: pv_msg_class,
      pv_msg_time_ms: pv_msg_time_ms,
      bodyrate_module: bodyrate_module,
      attitude_module: attitude_module,
      high_level_module: high_level_module,
      motor_moments: config[:motor_moments]
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, 1}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, 2}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, 3}, self())
    Pids.Tecs.Arm.start_link()
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_cmds_values, level}, pv_cmd_map, pv_value_map, airspeed, dt}, state) do
    case level do
      3 ->
        # pv_cmd_map will always contain course

        course_key = if Map.has_key?(pv_cmd_map, :course_ground), do: :course_ground, else: :course_flight
        course_cmd = Map.get(pv_cmd_map, course_key)
        # Logger.debug("course act-org: #{Common.Utils.eftb_deg(pv_value_map.course,1)}")
        # Logger.debug("course cmd-org: #{Common.Utils.eftb_deg(course_cmd,1)}")
        pv_cmd_map = Map.put(pv_cmd_map, course_key, course_cmd)
        # Logger.debug("pre: #{Common.Utils.eftb_map(pv_cmd_map,2)}")
        level_2_output_map = apply(state.high_level_module, :calculate_outputs, [pv_cmd_map, pv_value_map, airspeed, dt])

        # pv_cmd_map = Map.put(pv_cmd_map, course_key, roll_yaw_course_output.course)
        # Logger.debug("pst: #{Common.Utils.eftb_map(pv_cmd_map,2)}")
        # Logger.debug("PID Level 3")
        send_cmds(level_2_output_map, state.pv_msg_class, state.pv_msg_time_ms, {:pv_cmds, 2})
        pv_cmd_map = if Map.has_key?(pv_cmd_map, :yaw) do
          pv_cmd_map
        else
          Map.put(pv_cmd_map, :yaw, 0)
        end
        publish_cmds(pv_cmd_map, 3)
        # Logger.debug(Common.Utils.eftb_map(pv_cmd_map,2))
      2 ->
        # Logger.debug("PID Level 2")
        level_1_output_map = apply(state.attitude_module, :calculate_outputs, [pv_cmd_map, pv_value_map.attitude, state.attitude_scalar])

        # Logger.debug(Common.Utils.eftb_map(level_1_output_map,2))
        # output_map turns into input_map for Level I calcs
        pv_1_cmd_map = level_1_output_map
        actuator_outputs = apply(state.bodyrate_module, :calculate_outputs, [pv_1_cmd_map, pv_value_map.bodyrate, airspeed, dt, state.motor_moments])
        # Logger.debug(Common.Utils.eftb_map(actuator_outputs, 2))
        send_cmds(actuator_outputs, state.act_msg_class, state.act_msg_time_ms, :indirect_actuator_cmds)
        pv_cmd_map = if Map.has_key?(pv_cmd_map, :yaw) do
          pv_cmd_map
        else
          Map.put(pv_cmd_map, :yaw, 0)
        end
        publish_cmds(pv_cmd_map, 2)
        publish_cmds(pv_1_cmd_map, 1)
      1 ->
        # Logger.debug("PID Level 1")
        actuator_outputs = apply(state.bodyrate_module, :calculate_outputs, [pv_cmd_map, pv_value_map.bodyrate, airspeed, dt, state.motor_moments])
        # Logger.debug(Common.Utils.eftb_map(actuator_outputs, 2))
        send_cmds(actuator_outputs, state.act_msg_class, state.act_msg_time_ms, :indirect_actuator_cmds)
        publish_cmds(pv_cmd_map, 1)
      0 ->
        Logger.warn("PID level 0 - How did we get here?")
    end
    {:noreply, state}
  end

  defp send_cmds(output_map, msg_class, msg_time_ms, cmd_type) do
    MessageSorter.Sorter.add_message(cmd_type, msg_class, msg_time_ms, output_map)
  end

  @spec publish_cmds(map(), integer()) :: atom()
  def publish_cmds(cmds, level) do
    cmd_level =
      case level do
        1-> :level_1
        2-> :level_2
        3-> :level_3
      end
    Peripherals.Uart.Telemetry.Operator.store_data(%{cmd_level => cmds})
  end
end
