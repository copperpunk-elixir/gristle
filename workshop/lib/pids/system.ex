defmodule Pids.System do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start PIDs.System #{config[:name]}")
    name = Keyword.get(config, :name)
    IO.inspect(config)
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: Comms.ProcessRegistry.via_tuple(__MODULE__, name))
    GenServer.cast(pid, :start_pids)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        pids: Keyword.fetch!(config, :pids)
     }}
  end

  @impl GenServer
  def handle_cast(:start_pids, state) do
    IO.inspect(state)
    Enum.each(state.pids, fn {process_variable, actuators} ->
      Enum.each(actuators, fn {actuator, pid_config} ->
        Logger.debug("pid: #{inspect(pid_config)}")
        pid_config = Keyword.put(pid_config, :name, {process_variable, actuator})
          Pids.Pid.start_link(pid_config)
        end)
    end)
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
