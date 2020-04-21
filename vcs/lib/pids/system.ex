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
      control_variables_reduced = Enum.reduce(control_variables, %{}, fn ({control_variable, pid_config}, acts_red) ->
        Map.put(acts_red, control_variable, pid_config.weight)
      end)
      Map.put(config_reduced, process_variable, control_variables_reduced)
    end)
    # IO.puts("pv/cv pids: #{inspect(pv_cv_pids)}")
    cv_pv_pids =
      Enum.reduce(state.pids, %{}, fn ({process_variable, control_variables}, config_by_control_variable) ->
        # IO.puts("cba: #{inspect(config_by_control_variable)}")
          Enum.reduce(control_variables, config_by_control_variable, fn ({control_variable, pid_config}, pv_red) ->
            new_map = Map.get(pv_red, control_variable, %{})
            new_map = Map.put(new_map, process_variable, pid_config.weight)
            Map.put(pv_red, control_variable, new_map)
          end)
      end)
    # IO.puts("cv/pv pids: #{inspect(cv_pv_pids)}")
    {:noreply, %{state | pv_cv_pids: pv_cv_pids, cv_pv_pids: cv_pv_pids}}
  end

  @impl GenServer
  def handle_cast({{@pv_correction_group, pv_level}, pv_pv_correction_map, pv_feed_forward_map, dt}, state) do
    Logger.debug("PID pv_corr level #{pv_level}: #{inspect(pv_pv_correction_map)}")
    case pv_level do
      :III ->
        update_levelIII(pv_pv_correction_map, pv_feed_forward_map, dt, state.pv_cv_pids, state.cv_pv_pids, state.pv_msg_class, state.pv_msg_time_ms)
      :II ->
        update_levelII(pv_pv_correction_map, dt, state.pv_cv_pids)
        update_levelI(pv_pv_correction_map, dt, state.pv_cv_pids, state.cv_pv_pids, state.act_msg_class, state.act_msg_time_ms)
      :I ->
        update_levelI(pv_pv_correction_map, dt, state.pv_cv_pids, state.cv_pv_pids, state.act_msg_class, state.act_msg_time_ms)
    end
    {:noreply, state}
  end

  def update_levelIII(pv_pv_correction_map, pv_feed_forward_map, dt, pv_cv_pids, cv_pv_pids, msg_class, msg_time_ms) do
    control_variables_affected = update_cvs_multiple_outputs(pv_pv_correction_map, pv_feed_forward_map, dt, pv_cv_pids)
    # Logger.debug("cvs affected: #{inspect(control_variables_affected)}")
    send_cmds(control_variables_affected, cv_pv_pids, msg_class, msg_time_ms, :pv_cmds)
  end

  def update_levelII(pv_feed_forward_map, dt, pv_cv_pids) do
    update_cvs_single_output(pv_feed_forward_map, dt, pv_cv_pids)
  end

  def update_levelI(pv_pv_correction_map, dt, pv_cv_pids, cv_pv_pids, msg_class, msg_time_ms) do
    actuators_affected = update_cvs_multiple_outputs(pv_pv_correction_map, %{}, dt, pv_cv_pids)
    # Update all control_variables affected
    send_cmds(actuators_affected, cv_pv_pids, msg_class, msg_time_ms, :actuator_cmds)
  end

  defp update_cvs_single_output(pv_pv_correction_map, dt, pv_cv_pids) do
    Enum.each(pv_pv_correction_map, fn {process_variable, process_variable_correction} ->
      pv_cvs = Map.get(pv_cv_pids, process_variable)
      Enum.each(pv_cvs, fn {control_variable, _weight} ->
        # Logger.debug("pv/cv/corr: #{process_variable}/#{control_variable}/#{process_variable_correction}")
        Pids.Pid.update_pid(process_variable, control_variable, process_variable_correction, 0, dt)
      end)
    end)
  end

  defp update_cvs_multiple_outputs(pv_pv_correction_map, pv_feed_forward_map, dt, pv_cv_pids) do
    Enum.reduce(pv_pv_correction_map, [], fn ({process_variable, process_variable_correction}, control_variable_list) ->
      pv_cvs = Map.get(pv_cv_pids, process_variable)
      pv_feed_forward = Map.get(pv_feed_forward_map, process_variable, %{})
      Enum.reduce(pv_cvs, control_variable_list, fn ({control_variable, _weight}, acc) ->
        feed_forward = Map.get(pv_feed_forward, control_variable, 0)
        # Logger.debug("pv/cv/corr/ff: #{process_variable}/#{control_variable}/#{process_variable_correction}/#{feed_forward}")
        Pids.Pid.update_pid(process_variable, control_variable, process_variable_correction, feed_forward, dt)
        if (Enum.member?(acc, control_variable)) do
          acc
        else
          [control_variable | acc]
        end
      end)
    end)
  end

  defp send_cmds(cvs_affected, act_pv_pids, act_msg_class, act_msg_time_ms, cmd_type) do
    Enum.each(cvs_affected, fn control_variable_name ->
      pv_pids = Map.get(act_pv_pids, control_variable_name)
      # Logger.debug("Update acts: #{inspect(control_variable_name)}")
      output = calculate_combined_output(control_variable_name, pv_pids)
      # cmd_type is either :pv_cmds or :actuator_cmds
      MessageSorter.Sorter.add_message({cmd_type, control_variable_name}, act_msg_class, act_msg_time_ms, output)
    end)
  end

  defp calculate_combined_output(control_variable_name, pv_pids) do
    Enum.reduce(pv_pids, 0, fn ({pv, weight}, acc) ->
      pid_output = Pids.Pid.get_output(pv, control_variable_name, weight)
      # Logger.debug("CAO pv/act/output: #{pv}/#{control_variable_name}/#{pid_output}")
      acc + pid_output
    end)
  end
end
