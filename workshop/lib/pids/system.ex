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
        pids: Map.fetch!(config, :pids),
        pids_pv_act: %{},
        pids_act_pv: %{}
     }}
  end

  @impl GenServer
  def handle_cast(:start_pids, state) do
    Enum.each(state.pids, fn {process_variable, actuators} ->
      Enum.each(actuators, fn {actuator, pid_config} ->
        pid_config = Map.put(pid_config, :name, {process_variable, actuator})
          Pids.Pid.start_link(pid_config)
        end)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:reduce_config, state) do
    pids_pv_act = Enum.reduce(state.pids, %{}, fn ({process_variable, actuators}, config_reduced) ->
      actuators_reduced = Enum.reduce(actuators, %{}, fn ({actuator, pid_config}, acts_red) ->
        Map.put(acts_red, actuator, pid_config.weight)
      end)
      Map.put(config_reduced, process_variable, actuators_reduced)
    end)
    IO.puts("pids: pv/act: #{inspect(pids_pv_act)}")
    pids_act_pv =
      Enum.reduce(state.pids, %{}, fn ({process_variable, actuators}, config_by_actuator) ->
        # IO.puts("cba: #{inspect(config_by_actuator)}")
          Enum.reduce(actuators, config_by_actuator, fn ({actuator, pid_config}, pv_red) ->
            new_map = Map.get(pv_red, actuator, %{})
            new_map = Map.put(new_map, process_variable, pid_config.weight)
            Map.put(pv_red, actuator, new_map)
          end)
      end)
    IO.puts("pids act/pv: #{inspect(pids_act_pv)}")
    {:noreply, %{state | pids_pv_act: pids_pv_act, pids_act_pv: pids_act_pv}}
  end

  @impl GenServer
  def handle_cast({:update_pids, process_variable, process_variable_error, dt}, state) do
    pv_actuators = Map.get(state.pids, process_variable)
    Enum.each(pv_actuators, fn {actuator, _weight} ->
      Pids.Pid.update_pid(process_variable, actuator, process_variable_error, dt)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:update_actuator, actuator_to_update}, state) do
    actuator = Map.get(state.pids_act_pv, actuator_to_update)
    output = Enum.reduce(actuator, 0, fn ({pv, weight}, acc) ->
        pid_output = Pids.Pid.get_output(pv, actuator)
        acc + weight*pid_output
    end)
    IO.puts("#{actuator_to_update}:  #{output}")
    output
  end

  def update_pids(process_variable, process_variable_error, dt) do
    GenServer.cast(__MODULE__, {:update_pids, process_variable, process_variable_error, dt})
  end

  def update_actuator(actuator) do
    GenServer.cast(__MODULE__, {:update_actuator, actuator})
  end
end
