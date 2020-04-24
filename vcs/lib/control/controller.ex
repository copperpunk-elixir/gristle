defmodule Control.Controller do
  use GenServer
  require Logger

  @control_state_sorter {:control_state, :state}
  @pv_corr_level_I_group {:pv_correction, :I}
  @pv_corr_level_II_group {:pv_correction, :II}
  @pv_corr_level_III_group {:pv_correction, :III}

  def start_link(config) do
    Logger.debug("Start Control.ControllerCar")
    {:ok, process_id} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    begin()
    start_control_loop()
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    vehicle_type = config.vehicle_type
    vehicle_module = get_module_for_vehicle_type(vehicle_type)
    Logger.debug("Vehicle module: #{inspect(vehicle_module)}")
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_module: vehicle_module,
        pv_cmds: %{},
        control_loop_timer: nil,
        control_loop_interval_ms: config.process_variable_cmd_loop_interval_ms,
        control_state: nil
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    MessageSorter.System.start_link()
    # Start PV Cmds sorter
    # GenServer.cast(self(), :create_pv_cmd_map)
    GenServer.cast(self(), :start_pv_cmd_sorters)
    # Start control state sorter
    control_state_config = %{
      name: @control_state_sorter,
      default_message_behavior: :last
    }
    MessageSorter.System.start_sorter(control_state_config)
    join_process_variable_cmd_groups()
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_pv_cmd_sorters, state) do
    apply(state.vehicle_module, :start_message_sorters, [])
    {:noreply, state}
  end

  # @impl GenServer
  # def handle_cast(:create_pv_cmd_map, state) do
  #   Logger.warn("create pv cmd map")
  #   pv_cmds = Enum.reduce(apply(state.vehicle_module, :get_process_variable_list, []), %{}, fn(pv_config, acc) ->
  #     {:pv_cmds, name} = pv_config.name
  #     Map.put(acc, name, pv_config.default_value)
  #   end)
  #   Logger.warn("initial PV cmds: #{inspect(pv_cmds)}")
  #   {:noreply, %{state | pv_cmds: pv_cmds}}
  # end

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
  def handle_cast({:pv_attitude_attitude_rate, pv_value_map, dt}, state) do
    Logger.debug("Control rx att/attrate: #{inspect(pv_value_map)}")
    pv_corr_group =
      case state.control_state do
        :semi_auto -> @pv_corr_level_II_group
        :manual -> @pv_corr_level_I_group
      end
    Comms.Operator.send_local_msg_to_group(__MODULE__, {pv_corr_group, state.pv_cmds, pv_value_map,dt},pv_corr_group, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:pv_velocity_position, pv_value_map, dt}, state) do
    Logger.debug("Control rx vel/pos: #{inspect(pv_value_map)}")
    # If control_state :auto, compute Level III correction
    if (state.control_state == :auto) do
      pv_value_map = apply(state.vehicle_module, :get_auto_pv_value_map, [pv_value_map])
      Comms.Operator.send_local_msg_to_group(__MODULE__, {@pv_corr_level_III_group, state.pv_cmds, pv_value_map,dt},@pv_corr_level_III_group, self())
    end
    {:noreply, state}
  end


  @impl GenServer
  def handle_info(:control_loop, state) do
    Logger.debug("Control loop. CS: #{state.control_state}")
    # For every PV, get the corresponding command
    pv_cmds = update_all_pv_cmds(state.pv_cmds)
    control_state = get_control_state()
    {:noreply, %{state | pv_cmds: pv_cmds, control_state: control_state}}
  end

  def start_control_loop() do
    GenServer.cast(__MODULE__, :start_control_loop)
  end

  def stop_control_loop() do
    GenServer.cast(__MODULE__, :stop_control_loop)
  end

  def get_pv_cmd(pv_name) do
    MessageSorter.Sorter.get_value({:pv_cmds, pv_name})
  end

  def update_all_pv_cmds(pv_cmds) do
    Enum.reduce(pv_cmds, %{}, fn ({pv_name, _value}, acc) ->
      Map.put(acc, pv_name, get_pv_cmd(pv_name))
    end)
  end

  def add_control_state(control_state) do
    # This is the only process adding to the control_state_sorter, so
    # the classification and time_validity_ms aren't really important
    MessageSorter.Sorter.add_message(@control_state_sorter, [0], 100, control_state)
  end

  def get_control_state() do
    MessageSorter.Sorter.get_value(@control_state_sorter)
  end

  defp begin() do
    GenServer.cast(__MODULE__, :begin)
  end

  defp join_process_variable_cmd_groups() do
    Comms.Operator.join_group(__MODULE__, :pv_attitude_attitude_rate, self())
    Comms.Operator.join_group(__MODULE__, :pv_velocity_position, self())
  end

  # defp get_initial_pv_values() do
  #   %{
  #     attitude_rate: %{roll: 0, pitch: 0, yaw: 0},
  #     attitude: %{roll: 0, pitch: 0, yaw: 0},
  #     velocity: %{x: 0, y: 0, z: 0},
  #     position: %{x: 0, y: 0, z: 0}
  #   }
  # end


  def get_module_for_vehicle_type(vehicle_type) do
    Atom.to_string(__MODULE__) <> "." <> Atom.to_string(vehicle_type)
    |> String.to_atom()
  end
end
