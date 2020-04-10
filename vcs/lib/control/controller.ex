defmodule Control.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Control.Controller")
    {:ok, process_id} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    join_process_variable_cmd_groups()
    start_pv_cmd_loop()
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        process_variables: config.process_variables,
        pv_cmds: %{},
        pv_values: %{},
        pv_cmd_loop_timer: nil,
        pv_cmd_loop_interval_ms: config.process_variable_cmd_loop_interval_ms
     }}
  end

  @impl GenServer
  def handle_cast(:start_message_sorter_system, state) do
    {:ok, pid} = MessageSorter.System.start_link()
    Common.Utils.wait_for_genserver_start(pid)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:join_process_variable_cmd_groups, state) do
    Enum.each(state.process_variables, fn process_variable ->
      Comms.Operator.join_group({:process_variable_cmd, process_variable}, self())
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_pv_cmd_loop, state) do
    pv_cmd_loop_timer = Common.Utils.start_loop(self(), state.pv_cmd_loop_interval_ms, :pv_cmd_loop)
    state = %{state | pv_cmd_loop_timer: pv_cmd_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_pv_cmd_loop, state) do
    pv_cmd_loop_timer = Common.Utils.stop_loop(state.pv_cmd_loop_timer)
    state = %{state | pv_cmd_loop_timer: pv_cmd_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:pv_cmd_loop, state) do
    Logger.debug("PV cmd loop")
    # For every PV, get the corresponding command
    pv_cmds = get_all_pv_cmds_for_pvs(state.pv_values)
    {:noreply, %{state | pv_cmds: pv_cmds}}
  end

  def start_pv_cmd_loop() do
    GenServer.cast(__MODULE__, :start_pv_cmd_loop)
  end

  def stop_pv_cmd_loop() do
    GenServer.cast(__MODULE__, :stop_pv_cmd_loop)
  end

  def get_pv_cmd(pv_name) do
    MessageSorter.Sorter.get_value({:process_variable_cmd, pv_name})
  end

  def get_all_pv_cmds_for_pvs(process_variables) do
    Enum.reduce(process_variables, %{}, fn ({pv_name, _value}, acc) ->
      Map.put(acc, pv_name, get_pv_cmd(pv_name))
    end)
  end

  def update_process_variables(process_variable_names_value) do
    GenServer.cast(__MODULE__, {:update_pv, process_variable_names_value})
  end

  defp join_process_variable_cmd_groups() do
    GenServer.cast(__MODULE__, :join_process_variable_cmd_groups)
  end
end
