defmodule Pids.Pid do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start PID #{inspect(config[:name])}")
    GenServer.start_link(__MODULE__, config, name: Comms.ProcessRegistry.via_tuple(__MODULE__, config[:name]))
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        kp: Keyword.get(config, :kp, 0),
        ki: Keyword.get(config, :ki, 0),
        kd: Keyword.get(config, :kd, 0),
        pv_error_prev: 0,
        output: 0
      }}
  end

  @impl GenServer
  def handle_call({:update, process_var_error, _dt}, _from, state) do
    Logger.debug("Update pid #{inspect(self())}")
    cmd_p = state.kp*process_var_error
    output = cmd_p
    {:reply, output, %{state | output: output}}
  end

  @impl GenServer
  def handle_call(:get_output, _from, state) do
    {:reply, state.output, state}
  end

  def update_pid(process_id, process_var_error, dt) do
    GenServer.call(process_id, {:update, process_var_error, dt})
  end

  def get_output(process_id) do
    GenServer.call(process_id, :get_output)
  end

  def via_tuple(process_variable, actuator) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,{process_variable, actuator})
  end
end
