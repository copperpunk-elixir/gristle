defmodule Pids.System do
  use GenServer
  require Logger

  @pv_correction_group :pv_correction

  def start_link(config) do
    Logger.debug("Start PIDs.System #{config[:name]}")
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)

    GenServer.cast(pid, :start_pids)
    GenServer.cast(pid, :reduce_config)
    GenServer.cast(pid, :join_pv_groups)
    {:ok, pid}
  end

  # The PID will be simplified to a map of process_variables, each
  # containing a list of control_variables. The PID parameters will be dropped, as
  # they are unnessary after startup.
  @impl GenServer
  def init(config) do
    {:ok, %{
        pids: config.pids,
        rate_or_position: config.rate_or_position,
        one_or_two_sided: config.one_or_two_sided,
        pv_cv_pids: %{},
        cv_pv_pids: %{},
        act_msg_class: config.actuator_cmds_msg_classification,
        act_msg_time_ms: config.actuator_cmds_msg_time_validity_ms,
        pv_msg_class: config.pv_cmds_msg_classification,
        pv_msg_time_ms: config.pv_cmds_msg_time_validity_ms
     }}
  end

  @impl GenServer
  def handle_cast(:start_pids, state) do
    Enum.each(state.pids, fn {process_variable, control_variables} ->
      Enum.each(control_variables, fn {control_variable, pid_config} ->
        rate_or_position = Map.fetch!(state.rate_or_position, control_variable)
        one_or_two_sided = Map.fetch!(state.one_or_two_sided, control_variable)
        pid_config = Map.put(pid_config, :name, {process_variable, control_variable})
        |> Map.put(:rate_or_position, rate_or_position)
        |> Map.put(:one_or_two_sided, one_or_two_sided)
        Pids.Pid.start_link(pid_config)
      end)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:join_pv_groups, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    Comms.Operator.join_group(__MODULE__, {@pv_correction_group, :I}, self())
    Comms.Operator.join_group(__MODULE__, {@pv_correction_group, :II}, self())
    Comms.Operator.join_group(__MODULE__, {@pv_correction_group, :III}, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:reduce_config, state) do
    pv_cv_pids = Enum.reduce(state.pids, %{}, fn ({process_variable, control_variables}, config_reduced) ->
      control_variables_reduced =
        Enum.reduce(control_variables, %{}, fn ({control_variable, pid_config}, acts_red) ->
          weight = Map.get(pid_config, :weight, 1.0)
          Map.put(acts_red, control_variable, weight)
        end)
      Map.put(config_reduced, process_variable, control_variables_reduced)
    end)
    # IO.puts("pv/cv pids: #{inspect(pv_cv_pids)}")
    cv_pv_pids =
      Enum.reduce(state.pids, %{}, fn ({process_variable, control_variables}, config_by_control_variable) ->
        # IO.puts("cba: #{inspect(config_by_control_variable)}")
          Enum.reduce(control_variables, config_by_control_variable, fn ({control_variable, pid_config}, pv_red) ->
            weight = Map.get(pid_config, :weight, 1)
            new_map = Map.get(pv_red, control_variable, %{})
            new_map = Map.put(new_map, process_variable, weight)
            Map.put(pv_red, control_variable, new_map)
          end)
      end)
    # IO.puts("cv/pv pids: #{inspect(cv_pv_pids)}")
    {:noreply, %{state | pv_cv_pids: pv_cv_pids, cv_pv_pids: cv_pv_pids}}
  end

  @impl GenServer
  def handle_cast({{@pv_correction_group, pv_level}, pv_cmd_map, pv_value_map, dt}, state) do
    Logger.debug("PID pv_corr level #{pv_level}: #{inspect(pv_cmd_map)}/#{inspect(pv_value_map)}")
    case pv_level do
      :III ->
        output_map = update_cvs(pv_cmd_map, pv_value_map, dt, state.pv_cv_pids)
        Logger.warn("Auto")
        send_cmds(output_map, state.pv_msg_class, state.pv_msg_time_ms, :pv_cmds)
      :II ->
        Logger.warn("Semi-auto")
        output_map = update_cvs(pv_cmd_map, pv_value_map.attitude, dt, state.pv_cv_pids)
        # output_map turns into input_map for Level I calcs
        pv_cmd_map = output_map
        Logger.warn("new pv_cmd_map: #{inspect(pv_cmd_map)}")
        output_map = update_cvs(pv_cmd_map, pv_value_map.attitude_rate, dt, state.pv_cv_pids)
        send_cmds(output_map, state.act_msg_class, state.act_msg_time_ms, :act_cmds)
      :I ->
        Logger.warn("Manual")
        pv_value_map = put_in(pv_value_map,[:attitude_rate, :thrust], 0)
        output_map = update_cvs(pv_cmd_map, pv_value_map.attitude_rate, dt, state.pv_cv_pids)
        send_cmds(output_map, state.act_msg_class, state.act_msg_time_ms, :act_cmds)
    end
    {:noreply, state}
  end

  defp update_cvs(pv_cmd_map, pv_value_map, dt, pv_cv_pids) do
    Enum.reduce(pv_value_map, %{}, fn ({process_var_name, process_var_value}, control_var_list) ->
      # If a command does not yet exist, then do not actuate on it.
      # Rather pass the pv_value as the cmd
      Logger.debug("update cvs: cmds/values: #{inspect(pv_cmd_map)}/#{inspect(pv_value_map)}")
      process_var_cmd = Map.get(pv_cmd_map, process_var_name, process_var_value)
      Logger.warn("pv_cmd: #{process_var_name}/#{process_var_cmd}")
      pv_cvs = Map.get(pv_cv_pids, process_var_name)
      Enum.reduce(pv_cvs, control_var_list, fn ({control_var_name, weight}, acc) ->
        Logger.debug("pv/cv/cmd/value: #{process_var_name}/#{control_var_name}/#{process_var_cmd}/#{process_var_value}")
        output = Pids.Pid.update_pid(process_var_name, control_var_name, process_var_cmd, process_var_value, dt)
        total_output = output*weight + Map.get(acc, control_var_name, 0)
        Map.put(acc, control_var_name, total_output)
      end)
    end)
  end

  defp send_cmds(output_map, act_msg_class, act_msg_time_ms, cmd_type) do
    Enum.each(output_map, fn {control_variable_name, output} ->
      # pv_pids = Map.get(act_pv_pids, control_variable_name)
      # Logger.debug("Update acts: #{inspect(control_variable_name)}")
      # output = calculate_combined_output(control_variable_name, pv_pids)
      # cmd_type is either :pv_cmds or :actuator_cmds
      MessageSorter.Sorter.add_message({cmd_type, control_variable_name}, act_msg_class, act_msg_time_ms, output)
    end)
  end
end
