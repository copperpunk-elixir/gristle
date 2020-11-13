defmodule Pids.Moderator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Pids.Moderator GenServer")
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {act_msg_class, act_msg_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :indirect_actuator_cmds)
    {pv_msg_class, pv_msg_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :pv_cmds)
    attitude_scalar = Enum.reduce(Keyword.fetch!(config, :attitude_scalar), %{}, fn ({cv_pv, scalar}, acc) ->
      Map.put(acc, cv_pv, Enum.into(scalar, %{}))
    end)
    {:ok, %{
        attitude_scalar: attitude_scalar,
        act_msg_class: act_msg_class,
        act_msg_time_ms: act_msg_time_ms,
        pv_msg_class: pv_msg_class,
        pv_msg_time_ms: pv_msg_time_ms,
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, 1}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, 2}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, 3}, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_cmds_values, level}, pv_cmd_map, pv_value_map, airspeed, dt}, state) do
    case level do
      3 ->
        # pv_cmd_map will always contain course

        course_key = if Map.has_key?(pv_cmd_map, :course_ground), do: :course_ground, else: :course_flight
        course_cmd = Map.get(pv_cmd_map, course_key)
        course_cmd_constrained = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - pv_value_map.course)
        pv_cmd_map = Map.put(pv_cmd_map, course_key, course_cmd_constrained)

        roll_yaw_output = Pids.Course.calculate_outputs(pv_cmd_map, airspeed, dt)
        pitch_thrust_output = Pids.Tecs.calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt)
        level_2_output_map = Map.merge(roll_yaw_output, pitch_thrust_output)
        # Logger.debug("PID Level 3")
        send_cmds(level_2_output_map, state.pv_msg_class, state.pv_msg_time_ms, {:pv_cmds, 2})
        pv_cmd_map = if Map.has_key?(pv_cmd_map, :yaw) do
          pv_cmd_map
        else
          Map.put(pv_cmd_map, :yaw, 0)
        end
        publish_cmds(pv_cmd_map, 3)
      2 ->
        # Logger.debug("PID Level 2")
        level_1_output_map = Pids.Attitude.calculate_outputs(pv_cmd_map, pv_value_map.attitude, state.attitude_scalar)
        # output_map turns into input_map for Level I calcs
        pv_1_cmd_map = level_1_output_map
        actuator_outputs = Pids.Bodyrate.calculate_outputs(pv_1_cmd_map, pv_value_map.bodyrate, airspeed, dt)
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
        actuator_outputs = Pids.Bodyrate.calculate_outputs(pv_cmd_map, pv_value_map.bodyrate, airspeed, dt)

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
