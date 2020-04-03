defmodule Control.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Control.Controller")
    {:ok, process_id} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    join_process_variable_groups()
    start_control_loop()
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        process_variables: config.process_variables,
        pv_cmds: %{},
        pv_values: %{},
        control_loop_timer: nil,
        control_loop_interval_ms: config.control_loop_interval_ms
     }}
  end

  @impl GenServer
  def handle_cast(:start_message_sorter_system, state) do
    {:ok, pid} = MessageSorter.System.start_link()
    Common.Utils.wait_for_genserver_start(pid)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:join_process_variable_groups, state) do
    Enum.each(state.process_variables, fn process_variable ->
      Comms.Operator.join_group({:process_variable, process_variable})
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_control_loop, state) do
    control_loop_timer = Common.Utils.start_loop(self(), state.control_loop_interval_ms, :control_loop)
    state = %{state | control_loop_timer: control_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_control_loop, state) do
    control_loop_timer = Common.Utils.stop_loop(state.control_loop_timer)
    state = %{state | control_loop_timer: control_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:control_loop, state) do
    Logger.debug("Control loop")
    {:noreply, state}
  end

  def join_process_variable_groups() do
    GenServer.cast(__MODULE__, :join_process_variable_groups)
  end

  def start_control_loop() do
    GenServer.cast(__MODULE__, :start_control_loop)
  end

  def stop_control_loop() do
    GenServer.cast(__MODULE__, :stop_control_loop)
  end
end
