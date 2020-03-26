defmodule Pids.System do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start PIDs.System #{config[:name]}")
    process_via_tuple = apply(config[:registry_module], config[:registry_function], [__MODULE__, Keyword.get(config[:name])])
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: process_via_tuple)
    GenServer.cast(pid, :start_pids)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        registry_module: Keyword.fetch!(config, :registry_module),
        registry_function: Keyword.fetch!(config, :registry_function),
        pids: Keyword.fetch!(config, :pids)
     }}
  end

  @impl GenServer
  def handle_cast(:start_pids, state) do
    state = Enum.reduce(state.pids, state, fn ({process_variable, actuator}, acc) ->
      process_variable_actuators =
        Enum.reduce(process_variable, process_variable, fn ({actuator, pid}, acc) ->
          Controller.Pid.start_link(pid)
          pid_via_tuple = Pids.Pid.via_tuple(state.registry_module, state.registry_function, {process_variable, actuator})
          pid = Map.put(pid, :via_tuple, pid_via_tuple)
          %{acc | Map.put(acc, actuator, pid)}
        end)
      %{acc | Map.put(acc, process_variable, process_variable_actuators)}
    end)
    Logger.debug("Pids state: #{inspect(state)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:update_pid, process_variable, process_variable_error, dt}, state) do
    Enum.each(state.pids, fn {pid_process_variable, pid} ->
      if pid_process_variable == process_variable do
        pid_via_tuple = get_in(state, [:pids, process_variable, :via_tuple])
        GenServer.cast(pid_via_tuple, {:update, process_variable_error, dt})
      end
    end)
    {:noreply, state}
  end

end
