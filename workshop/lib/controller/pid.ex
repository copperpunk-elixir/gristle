defmodule Controller.Pid do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start PID")
    process_via_tuple = apply(config[:registry_module], config[:registry_function], [__MODULE__, config[:name]])
    GenServer.start_link(__MODULE__, config, name: process_via_tuple)
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
         registry_module: Keyword.get(config, :registry_module),
         registry_function: Keyword.get(config, :registry_function),
         kp: Keyword.get(config, :kp),
         output: 0
      }}
  end

  @impl GenServer
  def handle_call({:update, process_var_error, dt}, _from, state) do
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
end
