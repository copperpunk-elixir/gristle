defmodule Control.Controller do
  use GenServer
  require Logger

  @control_state_sorter {:control_state, :state}

  def start_link(config) do
    Logger.debug("Start Control.Controller")
    {:ok, process_id} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    begin()
    start_control_loop()
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        process_variables: config.process_variables,
        pv_cmds_sorted: %{},
        pv_cmds_control: %{},
        pv_values: %{},
        control_loop_timer: nil,
        control_loop_interval_ms: config.process_variable_cmd_loop_interval_ms,
        control_state: nil
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    MessageSorter.System.start_link()
    join_process_variable_cmd_groups(state.process_variables)
    control_state_config = %{
      name: @control_state_sorter,
      default_message_behavior: :last
    }
    MessageSorter.System.start_sorter(control_state_config)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_message_sorter_system, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:join_process_variable_cmd_groups, state) do
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
  def handle_cast({:update_pvs, pv_group, process_variable_names_values}, state) do
    control_state = state.control_state
    control_state_enum = get_control_state_enum(control_state)
    # case pv_group do
    #   :attitude ->
    #     cond do
    #       control_state_enum == :attitude_rate ->
    #         pv_cmds = get_pv_cmds(:attitude_rate)
    #         Logger.debug("Rate: #{inspect(pv_cmds)}")
    #       control_state_enum == :attitude ->
    #         pv_cmds = get_pv_cmd(:attitude_rate)
    #         Logger.debug("Attitude: #{inspect(pv_cmds)}")
    #       true -> nil
    #     end
    #   :pos_vel ->
    #     cond do
    #       control_state_enum == :velocity ->
    #         pv_cmds = get_pv_cmd(:velocit)
    #     end

    # end
    # pv_values = Enum.reduce(process_variable_names_values, state.pv_values, fn ({pv_name, pv_value}, acc) ->
    #   Map.put(acc, pv_name, pv_value)
    # end)
    # min_control_state = min(Swarm.Gsm.get_state_enum(pv_group), state.control_state)
    # pv_cmds_control = Enum.reduce(state.control_state, min_control_state,
    state
  end

  @impl GenServer
  def handle_info(:control_loop, state) do
    Logger.debug("Control loop")
    # For every PV, get the corresponding command
    pv_cmds_sorted = get_all_pv_cmds_sorted_for_pvs(state.pv_values)
    control_state = get_control_state()
    {:noreply, %{state | pv_cmds_sorted: pv_cmds_sorted, control_state: control_state}}
  end

  def get_pv_cmd_for_control_state(control_state, pv_cmd_name) do
    # case pv_cmd_name do
    #   :roll -> case control_state do

    #            end
    # end
    # case control_state do
    #   :rate -> 
    # end
  end

  def get_control_state_enum(control_state) do
    Swarm.Gsm.get_state_enum(control_state)
  end

  def start_control_loop() do
    GenServer.cast(__MODULE__, :start_control_loop)
  end

  def stop_control_loop() do
    GenServer.cast(__MODULE__, :stop_control_loop)
  end

  def get_pv_cmd(pv_name) do
    MessageSorter.Sorter.get_value({:process_variable_cmd, pv_name})
  end

  def get_all_pv_cmds_sorted_for_pvs(process_variables) do
    Enum.reduce(process_variables, %{}, fn ({pv_name, _value}, acc) ->
      Map.put(acc, pv_name, get_pv_cmd(pv_name))
    end)
  end

  def update_attitude_pvs(process_variable_names_values) do
    GenServer.cast(__MODULE__, {:update_pvs, :attitude, process_variable_names_values})
  end

  def update_pos_vel_pvs(process_variable_names_values) do
    GenServer.cast(__MODULE__, {:update_pvs, :pos_vel, process_variable_names_values})
  end

  def add_control_state(control_state) do
    # This is the only process adding to the control_state_sorter, s
    # the classification and time_validity_ms aren't really important
    MessageSorter.Sorter.add_message(@control_state_sorter, [0], 100, control_state)
  end

  def get_control_state() do
    MessageSorter.Sorter.get_value(@control_state_sorter)
  end

  defp begin() do
    GenServer.cast(__MODULE__, :begin)
  end

  defp join_process_variable_cmd_groups(process_variables) do
    Enum.each(process_variables, fn process_variable ->
      Comms.Operator.join_group({:process_variable_cmd, process_variable}, self())
      MessageSorter.System.start_sorter(%{name: {:process_variable_cmd, process_variable}})
    end)
  end
end
