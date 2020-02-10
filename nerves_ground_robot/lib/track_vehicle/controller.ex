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
        speed_to_turn_ratio: Map.get(config, :speed_to_turn_ratio, 1),
        command_priority_max: config.command_priority_max,
        classification: config.classification,
        actuators_ready: false,
        actuator_timer: nil,
        # actuator_output: %{}, #in the form of %{actuator: output},
        actuator_loop_interval_ms: Map.get(config, :actuator_loop_interval_ms, 0),
        subscriber_topics: Map.get(config, :subscriber_topics, [])
     }
    }
  end

  @impl GenServer
  def handle_cast(:register_subscribers, state) do
    Logger.debug("Gimbal - Register subs")
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
    CommandSorter.System.start_sorter({__MODULE__, :speed}, state.command_priority_max)
    CommandSorter.System.start_sorter({__MODULE__, :turn}, state.command_priority_max)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_actuator_loop, state) do
    state =
      case :timer.send_interval(state.actuator_loop_interval_ms, self(), :actuator_loop) do
        {:ok, actuator_timer} ->
          %{state | actuator_timer: actuator_timer}
        {_, reason} ->
          Logger.debug("Could not start actuator_controller timer: #{inspect(reason)} ")
          state
      end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_actuator_loop, state) do
    state =
      case :timer.cancel(state.actuator_timer) do
        {:ok, _} ->
          %{state | actuator_timer: nil}
        {_, reason} ->
          Logger.debug("Could not stop actuator_controller timer: #{inspect(reason)} ")
          state
      end
    {:noreply, state}
  end

 @impl GenServer
  def handle_cast({:actuator_status, :ready}, state) do
    Logger.debug("Gimbal: Actuators ready!")
    GenServer.cast(__MODULE__, :start_actuator_loop)
    {:noreply, %{state | actuators_ready: true}}
  end

  @impl GenServer
  def handle_cast({:actuator_status, :not_ready}, state) do
    Logger.debug("Gimbal: Actuators not ready!")
    GenServer.cast(__MODULE__, :stop_actuator_loop)
    {:noreply, %{state | actuators_ready: false}}
  end

  @impl GenServer
  def handle_cast({:speed_and_turn_cmd, classification, speed_and_turn_cmd}, state) do
    # Logger.debug("new att cmd: #{inspect(Common.Utils.rad2deg_map(speed_and_turn_cmd))}")
    Enum.each(speed_and_turn_cmd, fn {process_variable, value} ->
      CommandSorter.Sorter.add_command({__MODULE__, process_variable}, classification.priority, classification.authority, classification.time_validity_ms, value)
    end)
    # speed_cmd = Map.get(speed_and_turn_cmd, :speed, state.speed_cmd)
    # turn_cmd = Map.get(speed_and_turn_cmd, :turn, state.turn_cmd)
    {:noreply, state} #%{state | speed_cmd: speed_cmd, turn_cmd: turn_cmd}}
  end

  @impl GenServer
  def handle_call({:get_parameter, parameter}, _from, state) do
    {:reply, Map.get(state, parameter), state}
  end

  @impl GenServer
  def handle_info(:actuator_loop, state) do
    # Go through every channel and send an update to the ActuatorController
    # actuator_controller_process_name = state.config.actuator_controller.process_name
    if state.actuators_ready do
      speed_cmd = CommandSorter.Sorter.get_command({__MODULE__, :speed})
      turn_cmd = CommandSorter.Sorter.get_command({__MODULE__, :speed})
      unless speed_cmd==nil or turn_cmd==nil do
        {left_track_cmd, right_track_cmd} =
          calculate_track_cmd_for_speed_and_turn(speed_cmd, turn_cmd, state.speed_to_turn_ratio)
        Logger.debug("Move actuator L/R: #{left_track_cmd}, #{right_track_cmd}")
        actuator_cmds = %{
          left_track: left_track_cmd,
          right_track: right_track_cmd
        }
        Actuator.Controller.add_actuator_cmds(state.classification, actuator_cmds)
      end
      # Actuator.Controller.move_actuator(actuator_pid.actuator, actuator_pid.output)
    end
    {:noreply, state}
  end

  def update_speed_and_turn_cmd(speed_and_turn_cmd) do
    GenServer.cast(__MODULE__, {:speed_and_turn_cmd, speed_and_turn_cmd})
  end

  def get_parameter(parameter) do
    GenServer.call(__MODULE__, {:get_parameter, parameter})
  end

  def calculate_track_cmd_for_speed_and_turn(speed, turn, speed_to_turn_ratio) do
    {min_cmd, max_cmd} =
    if speed > 0 do
      {0.5, 1.0}
    else
      {0, 0.5}
    end
    left_track_cmd =
      0.5 + 0.5*(speed + turn/speed_to_turn_ratio)
      |> Common.Utils.Math.constrain(min_cmd, max_cmd)
    right_track_cmd =
      0.5 + 0.5*(speed - turn/speed_to_turn_ratio)
      |> Common.Utils.Math.constrain(min_cmd, max_cmd)
    {left_track_cmd, right_track_cmd}
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
