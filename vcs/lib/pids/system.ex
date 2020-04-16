defmodule Pids.System do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start PIDs.System #{config[:name]}")
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    GenServer.cast(pid, :start_pids)
    GenServer.cast(pid, :reduce_config)
    {:ok, pid}
  end

  # The PID will be simplified to a map of process_variables, each
  # containing a list of actuators. The PID parameters will be dropped, as
  # they are unnessary after startup.
  @impl GenServer
  def init(config) do
    {:ok, %{
        pids: config.pids,
        rate_or_position: config.rate_or_position,
        one_or_two_sided: config.one_or_two_sided,
        pv_act_pids: %{},
        act_pv_pids: %{},
        act_msg_class: config.actuator_output_msg_classification,
        act_msg_time_ms: config.actuator_output_msg_time_validity_ms
     }}
  end

  @impl GenServer
  def handle_cast(:start_pids, state) do
    Enum.each(state.pids, fn {process_variable, actuators} ->
      Enum.each(actuators, fn {actuator, pid_config} ->
        rate_or_position = Map.fetch!(state.rate_or_position, actuator)
        one_or_two_sided = Map.fetch!(state.one_or_two_sided, actuator)
        pid_config = Map.put(pid_config, :name, {process_variable, actuator})
        |> Map.put(:rate_or_position, rate_or_position)
        |> Map.put(:one_or_two_sided, one_or_two_sided)
        Pids.Pid.start_link(pid_config)
      end)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:reduce_config, state) do
    pv_act_pids = Enum.reduce(state.pids, %{}, fn ({process_variable, actuators}, config_reduced) ->
      actuators_reduced = Enum.reduce(actuators, %{}, fn ({actuator, pid_config}, acts_red) ->
        Map.put(acts_red, actuator, pid_config.weight)
      end)
      Map.put(config_reduced, process_variable, actuators_reduced)
    end)
    # IO.puts("pv/act pids: #{inspect(pv_act_pids)}")
    act_pv_pids =
      Enum.reduce(state.pids, %{}, fn ({process_variable, actuators}, config_by_actuator) ->
        # IO.puts("cba: #{inspect(config_by_actuator)}")
          Enum.reduce(actuators, config_by_actuator, fn ({actuator, pid_config}, pv_red) ->
            new_map = Map.get(pv_red, actuator, %{})
            new_map = Map.put(new_map, process_variable, pid_config.weight)
            Map.put(pv_red, actuator, new_map)
          end)
      end)
    # IO.puts("act/pv pids: #{inspect(act_pv_pids)}")
    {:noreply, %{state | pv_act_pids: pv_act_pids, act_pv_pids: act_pv_pids}}
  end

  @impl GenServer
  def handle_cast({:update_pids, process_variable, process_variable_error, dt}, state) do
    pv_actuators = Map.get(state.pv_act_pids, process_variable)
    Enum.each(pv_actuators, fn {actuator, _weight} ->
      Pids.Pid.update_pid(process_variable, actuator, process_variable_error, dt)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:update_pids_for_pv_map, pv_pv_error_map, dt}, state) do
    actuators_affected =
      Enum.reduce(pv_pv_error_map, [], fn ({process_variable, process_variable_error}, actuator_list) ->
        pv_actuators = Map.get(state.pv_act_pids, process_variable)
        actuators_for_pv =[]
          Enum.reduce(pv_actuators, actuator_list, fn ({actuator, _weight}, acc) ->
            Pids.Pid.update_pid(process_variable, actuator, process_variable_error, dt)
            if (Enum.member?(acc, actuator)) do
              acc
            else
              [actuator | acc]
            end
        end)
      end)
    # Update all actuators affected
    Enum.each(actuators_affected, fn actuator_name ->
      pv_pids = Map.get(state.act_pv_pids, actuator_name)
      output = calculate_actuator_output(actuator_name, pv_pids)
      MessageSorter.Sorter.add_message({:actuator, actuator_name}, state.act_msg_class, state.act_msg_time_ms, output)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:update_all_actuators_connected_to_pv, process_variable}, state) do
    Enum.each(state.act_pv_pids, fn {actuator_name, pv_pids} ->
      # Logger.debug("update acts with pv: #{process_variable}")
      if Map.has_key?(pv_pids, process_variable) do
        output = calculate_actuator_output(actuator_name, pv_pids)
        # Logger.debug("#{actuator_name} output: #{output}")
        MessageSorter.Sorter.add_message({:actuator, actuator_name}, state.act_msg_class, state.act_msg_time_ms, output)
      end
    end)
    {:noreply, state}
  end

  # TODO: Does this function have a purpose besides testing?
  @impl GenServer
  def handle_call({:get_actuator_output, actuator_name}, _from, state) do
    pv_pids = Map.get(state.pids_act_pv, actuator_name)
    {:reply, calculate_actuator_output(actuator_name, pv_pids), state}
  end

  def update_pids(process_variable, process_variable_error, dt) do
    GenServer.cast(__MODULE__, {:update_pids, process_variable, process_variable_error, dt})
    GenServer.cast(__MODULE__, {:update_all_actuators_connected_to_pv, process_variable})
    # update_all_actuators_connected_to_process_variable(process_variable)
  end

  def update_pids_for_pvs_and_errors(pv_pv_error_map, dt) do
    GenServer.cast(__MODULE__, {:update_pids_for_pv_map, pv_pv_error_map, dt})
  end

  def get_actuator_output(actuator) do
    GenServer.call(__MODULE__, {:get_actuator_output, actuator})
  end

  def calculate_actuator_output(actuator_name, pv_pids) do
    {output_sum, weight_sum} = Enum.reduce(pv_pids, {0,0}, fn ({pv, weight}, acc) ->
      pid_output = Pids.Pid.get_output(pv, actuator_name)
      output_sum_new = elem(acc, 0) + weight*pid_output
      weight_sum_new = elem(acc, 1) + weight
      {output_sum_new, weight_sum_new}
    end)
    if (weight_sum> 0) do
      constrain_output(output_sum / weight_sum)
    else
      raise "Weights for #{actuator_name} are not valid"
    end
  end

  def update_all_actuators_connected_to_process_variable(process_variable) do
    GenServer.cast(__MODULE__, {:update_all_actuators_connected_to_pv, process_variable})
  end

  def constrain_output(output) do
    cond do
      output > 1 -> 1
      output < 0 -> 0
      true -> output
    end
  end
end
