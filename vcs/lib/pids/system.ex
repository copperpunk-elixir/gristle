defmodule Pids.System do
  use GenServer
  require Logger

  @pv_cmds_values_group :pv_cmds_values

  def start_link(config) do
    Logger.debug("Start PIDs.System #{config[:name]}")
    Logger.info("module: #{inspect(__MODULE__)}")
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :start_pids)
    GenServer.cast(pid, :reduce_config)
    GenServer.cast(pid, :join_pv_cmds_values_groups)
    {:ok, pid}
  end

  # The PID will be simplified to a map of process_variables, each
  # containing a list of output variables. The PID parameters will be dropped, as
  # they are unnessary after startup.
  @impl GenServer
  def init(config) do
    {act_msg_class, act_msg_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :actuator_cmds)
    {pv_msg_class, pv_msg_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :pv_cmds)
    {:ok, %{
        pids: config.pids,
        pv_output_pids: %{},
        act_msg_class: act_msg_class,
        act_msg_time_ms: act_msg_time_ms,
        pv_msg_class: pv_msg_class,
        pv_msg_time_ms: pv_msg_time_ms
     }}
  end

  @impl GenServer
  def handle_cast(:start_pids, state) do
    Enum.each(state.pids, fn {process_variable, control_variables} ->
      Enum.each(control_variables, fn {control_variable, pid_config} ->
        pid_config = Map.put(pid_config, :name, {process_variable, control_variable})
        Pids.Pid.start_link(pid_config)
      end)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:join_pv_cmds_values_groups, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    Enum.each(0..3, fn level ->
      Comms.Operator.join_group(__MODULE__, {@pv_cmds_values_group, level}, self())
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:reduce_config, state) do
    pv_output_pids = Enum.reduce(state.pids, %{}, fn ({process_variable, control_variables}, config_reduced) ->
      control_variables_reduced =
        Enum.reduce(control_variables, %{}, fn ({control_variable, pid_config}, acts_red) ->
          weight = Map.get(pid_config, :weight, 1.0)
          Map.put(acts_red, control_variable, weight)
        end)
      Map.put(config_reduced, process_variable, control_variables_reduced)
    end)
    {:noreply, %{state | pv_output_pids: pv_output_pids}}
  end

  @impl GenServer
  def handle_cast({{@pv_cmds_values_group, level}, pv_cmd_map, pv_value_map, dt}, state) do
    # Logger.debug("PID pv_cmds_values level #{level}: #{inspect(pv_cmd_map)}/#{inspect(pv_value_map)}")
    case level do
      3 ->
        # Logger.warn("pv_cmd_map/value: #{inspect(pv_cmd_map)}/#{inspect(pv_value_map)}")
        # pv_cmd_map will always contain course
        course_cmd_constrained = Common.Utils.turn_left_or_right_for_correction(pv_cmd_map.course - pv_value_map.course)
        pv_cmd_map = Map.put(pv_cmd_map, :course, course_cmd_constrained)
        pv_value_map = Map.put(pv_value_map, :course, 0)

        level_2_output_map = calculate_outputs_for_pv_cmds_values(pv_cmd_map, pv_value_map, dt, state.pv_output_pids)

        # Logger.warn("PID Level 3")
        send_cmds(level_2_output_map, state.pv_msg_class, state.pv_msg_time_ms, {:pv_cmds, 2})
      2 ->
        # Logger.warn("PID Level 2")
        # Logger.warn("pv_cmd_map/values: #{inspect(pv_cmd_map)}/#{inspect(pv_value_map)}")
        # pv_cmd_map will always contain yaw, and it was always be a relative command
        # Therefore set the pv_value yaw to 0
        pv_value_map = put_in(pv_value_map, [:attitude, :yaw], 0)
        level_1_output_map = calculate_outputs_for_pv_cmds_values(pv_cmd_map, pv_value_map.attitude, dt, state.pv_output_pids)
        # output_map turns into input_map for Level I calcs
        pv_1_cmd_map = level_1_output_map
        Logger.warn("new pv_cmd_map: #{inspect(pv_1_cmd_map)}")
        # Logger.warn("pv_value_map, bodyrate: #{inspect(pv_value_map.bodyrate)}")
        pv_value_map = put_in(pv_value_map,[:bodyrate, :thrust], 0)
        level_2_thrust_cmd = Map.get(pv_cmd_map, :thrust, 0)
        pv_1_cmd_map = Map.put(pv_1_cmd_map, :thrust, level_2_thrust_cmd)
        actuator_output_map = calculate_outputs_for_pv_cmds_values(pv_1_cmd_map, pv_value_map.bodyrate, dt, state.pv_output_pids)
        send_cmds(actuator_output_map, state.act_msg_class, state.act_msg_time_ms, :actuator_cmds)
      1 ->
        # Logger.warn("PID Level 1")
        pv_value_map = put_in(pv_value_map,[:bodyrate, :thrust], 0)
        actuator_output_map = calculate_outputs_for_pv_cmds_values(pv_cmd_map, pv_value_map.bodyrate, dt, state.pv_output_pids)
        # Logger.debug("actuator output map: #{inspect(actuator_output_map)}")
        send_cmds(actuator_output_map, state.act_msg_class, state.act_msg_time_ms, :actuator_cmds)
      0 ->
        Logger.warn("PID level 0 - How did we get here?")
    end
    {:noreply, state}
  end

  defp calculate_outputs_for_pv_cmds_values(pv_cmd_map, pv_value_map, dt, pv_output_pids) do
    Enum.reduce(pv_value_map, %{}, fn ({pv_name, pv_value}, output_variable_list) ->
      # Logger.debug("update cvs: cmds/values: #{inspect(pv_cmd_map)}/#{inspect(pv_value_map)}")
      # If a command does not yet exist, then do not ignore it. Rather pass the pv_value as the cmd
      # i.e., the correction=0
      pv_cmd = Map.get(pv_cmd_map, pv_name, pv_value)
      # Logger.warn("pv_cmd/value: #{pv_name}:#{pv_cmd}/#{pv_value}")
      pv_output_map = Map.get(pv_output_pids, pv_name, %{})
      unless Enum.empty?(pv_output_map) do
        Enum.reduce(pv_output_map, output_variable_list, fn ({output_variable_name, weight}, acc) ->
          # Logger.debug("pv/cv/cmd/value: #{pv_name}/#{output_variable_name}/#{pv_cmd}/#{pv_value}")
          output = Pids.Pid.update_pid(pv_name, output_variable_name, pv_cmd, pv_value, dt)
          total_output = output*weight + Map.get(acc, output_variable_name, 0)
          # Logger.debug("output/weight/total: #{output}/#{weight}/#{total_output}")
          Map.put(acc, output_variable_name, total_output)
        end)
      else
        output_variable_list
      end
    end)
  end

  defp send_cmds(output_map, msg_class, msg_time_ms, cmd_type) do
    MessageSorter.Sorter.add_message(cmd_type, msg_class, msg_time_ms, output_map)
  end
end
