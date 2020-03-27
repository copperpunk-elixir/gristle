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
        pids: Map.fetch!(config, :pids)
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
    pids = Enum.reduce(state.pids, %{}, fn ({process_variable, actuators}, config_reduced) ->
      actuators_reduced = Enum.reduce(actuators, [], fn ({actuator, _pid_config}, acts_red) ->
        [actuator | acts_red]
      end)
      Map.put(config_reduced, process_variable, actuators_reduced)
    end)
    {:noreply, %{state | pids: pids}}
  end

  @impl GenServer
  def handle_cast({:update_pids, process_variable, process_variable_error, dt}, state) do
    Enum.each(state.pids, fn {pid_process_variable, actuators} ->
      if pid_process_variable == process_variable do
        Enum.each(actuators, fn actuator ->
          Pids.Pid.update_pid(process_variable, actuator, process_variable_error, dt)
        end)
      end
    end)
    {:noreply, state}
  end

  def update_pids(process_variable, process_variable_error, dt) do
    GenServer.cast(__MODULE__, {:update_pids, process_variable, process_variable_error, dt})
  end

end
