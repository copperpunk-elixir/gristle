defmodule TrackVehicle.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start TrackVehicleController")
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    register_subscribers()
    start_command_sorters()
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok,  %{
        # speed_cmd: 0,
        # turn_cmd: 0,
        pid_actuator_links: Map.get(config, :pid_actuator_links),
        # speed_to_turn_ratio: Map.get(config, :speed_to_turn_ratio, 1),
        actuator_cmd_classification: config.actuator_cmd_classification,
        actuators_ready: false,
        # actuator_output: %{}, #in the form of %{actuator: output},
        subscriber_topics: Map.get(config, :subscriber_topics, [])
     }
    }
  end

  @impl GenServer
  def handle_cast(:register_subscribers, state) do
    Logger.debug("TrackVehicle - Register subs")
    Common.Utils.Comms.register_subscriber_list(:topic_registry, state.subscriber_topics)
    # Enum.each(state.subscriber_topics, fn {registry, topic} ->
    #   Logger.debug("#{registry}/#{topic}")
    #   Registry.register(registry, topic, topic)
    # end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_command_sorters, state) do
    # Command sorters will store the values of all the process variable COMMANDS
    # i.e. ROLL, or PITCH, or YAW
    Enum.each(state.pid_actuator_links, fn pid_actuator_link ->
      CommandSorter.System.start_sorter({__MODULE__, pid_actuator_link.process_variable}, pid_actuator_link.cmd_limit_min, pid_actuator_link.cmd_limit_max)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:actuator_status, :ready}, state) do
    Logger.debug("Gimbal: Actuators ready!")
    Actuator.Controller.arm_actuators()
    {:noreply, %{state | actuators_ready: true}}
  end

  @impl GenServer
  def handle_cast({:actuator_status, :not_ready}, state) do
    Logger.debug("Gimbal: Actuators not ready!")
    {:noreply, %{state | actuators_ready: false}}
  end

  @impl GenServer
  def handle_cast({:speed_and_turn_cmd, cmd_type_min_max_exact, classification, speed_and_turn_cmd}, state) do
    # Logger.debug("new att cmd: #{inspect(Common.Utils.rad2deg_map(speed_and_turn_cmd))}")
    Enum.each(speed_and_turn_cmd, fn {process_variable, value} ->
      CommandSorter.Sorter.add_command({__MODULE__, process_variable}, cmd_type_min_max_exact, classification, value)
    end)

    actuator_cmd = Enum.reduce(state.pid_actuator_links, %{}, fn (pid_actuator_link, acc) ->
      cmd = CommandSorter.Sorter.get_command({__MODULE__, pid_actuator_link.process_variable}, pid_actuator_link.failsafe_cmd)
      Map.put(acc, pid_actuator_link.process_variable, cmd)
    end)
    Logger.debug("act cmds: #{inspect(actuator_cmd)}")
    {left_track_cmd, right_track_cmd} = calculate_track_cmd_for_speed_and_turn(actuator_cmd.speed, actuator_cmd.turn)
    actuator_cmds = %{left_track_motor: left_track_cmd, right_track_motor: right_track_cmd}
    Actuator.Controller.add_actuator_cmds(:exact, state.actuator_cmd_classification, actuator_cmds)
    # speed_cmd = Map.get(speed_and_turn_cmd, :speed, state.speed_cmd)
    # turn_cmd = Map.get(speed_and_turn_cmd, :turn, state.turn_cmd)
    {:noreply, state} #%{state | speed_cmd: speed_cmd, turn_cmd: turn_cmd}}
  end

  @impl GenServer
  def handle_call({:get_parameter, parameter}, _from, state) do
    {:reply, Map.get(state, parameter), state}
  end

  # @impl GenServer
  # def handle_info(:actuator_loop, state) do
  #   # Go through every channel and send an update to the ActuatorController
  #   # actuator_controller_process_name = state.config.actuator_controller.process_name
  #   if state.actuators_ready do
  #     speed_cmd = CommandSorter.Sorter.get_command({__MODULE__, :speed}, )
  #     turn_cmd = CommandSorter.Sorter.get_command({__MODULE__, :turn})
  #     unless speed_cmd==nil or turn_cmd==nil do
  #       {left_track_cmd, right_track_cmd} =
  #         calculate_track_cmd_for_speed_and_turn(speed_cmd, turn_cmd)
  #       Logger.debug("Move actuator L/R: #{left_track_cmd}, #{right_track_cmd}")
  #       actuator_cmds = %{
  #         left_track: left_track_cmd,
  #         right_track: right_track_cmd
  #       }
  #       Actuator.Controller.add_actuator_cmds(:exact, state.actuator_cmd_classification, actuator_cmds)
  #     end
  #     # Actuator.Controller.move_actuator(actuator_pid.actuator, actuator_pid.output)
  #   end
  #   {:noreply, state}
  # end

  def update_speed_and_turn_cmd(cmd_type_min_max_exact, classification, speed_and_turn_cmd) do
    GenServer.cast(__MODULE__, {:speed_and_turn_cmd, cmd_type_min_max_exact, classification, speed_and_turn_cmd})
  end

  def get_parameter(parameter) do
    GenServer.call(__MODULE__, {:get_parameter, parameter})
  end

  def calculate_track_cmd_for_speed_and_turn(speed, turn) do
    # Vector of x/y components, magnitude=1
    x_component = turn
    y_component = :math.sqrt(1.0 - x_component*x_component)
    # Command returned in the form of {left_track_cmd, right_track_cmd}
    cond do
      x_component < 0 ->
        {speed*y_component, speed}
      turn ->
        {speed, speed*y_component}
    end
  end

  def arm_actuators() do
    GenServer.cast(__MODULE__, {:actuator_status, :ready})
  end

  def disarm_actuators() do
    GenServer.cast(__MODULE__, {:actuator_status, :not_ready})
  end

  def register_subscribers() do
    GenServer.cast(__MODULE__, :register_subscribers)
  end

  def start_command_sorters() do
    GenServer.cast(__MODULE__, :start_command_sorters)
  end
end
