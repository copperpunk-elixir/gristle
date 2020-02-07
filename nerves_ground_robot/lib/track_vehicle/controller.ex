defmodule TrackVehicle.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start TrackVehicleController")
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    GenServer.cast(__MODULE__, :register_subscribers)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok,  %{
        turn_and_speed_cmd: %{turn: 0, speed: 0},
        actuators_ready: false,
        actuator_timer: nil,
        # actuator_output: %{}, #in the form of %{actuator: output},
        actuator_loop_interval_ms: config.actuator_loop_interval_ms,
        subscriber_topics: config.subscriber_topics
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
    arm_actuators()
    {:noreply, %{state | actuators_ready: true}}
  end

  @impl GenServer
  def handle_cast({:actuator_status, :not_ready}, state) do
    Logger.debug("Gimbal: Actuators not ready!")
    disarm_actuators()
    {:noreply, %{state | actuators_ready: false}}
  end

  @impl GenServer
  def handle_cast({:turn_and_speed_cmd, turn_and_speed_cmd}, state) do
    # Logger.debug("new att cmd: #{inspect(Common.Utils.rad2deg_map(turn_and_speed_cmd))}")
    speed_cmd = Map.get(turn_and_speed_cmd, :speed, state.turn_and_speed_cmd.speed)
    turn_cmd = Map.get(turn_and_speed_cmd, :turn, state.turn_and_speed_cmd.turn)
    {:noreply, %{state | turn_and_speed_cmd: %{speed: speed_cmd, turn: turn_cmd}}}
  end

  @impl GenServer
  def handle_info(:actuator_loop, state) do
    # Go through every channel and send an update to the ActuatorController
    # actuator_controller_process_name = state.config.actuator_controller.process_name
    if state.actuators_ready do
      {min_cmd, max_cmd} =
      if state.turn_and_speed_cmd.speed > 0 do
        {0.5, 1.0}
      else
        {0, 0.5}
      end
      left_track_cmd = 0.5 + Common.Utils.Math.constrain(state.turn_and_speed_cmd.speed + state.turn_and_speed_cmd.turn, min_cmd, max_cmd)
      right_track_cmd = 0.5 + Common.Utils.Math.constrain(state.turn_and_speed_cmd.speed - state.turn_and_speed_cmd.turn, min_cmd, max_cmd)
      Logger.debug("Move actuator L/R: #{left_track_cmd}, #{right_track_cmd}")
      Actuator.Controller.move_actuator(:left_track, left_track_cmd)
      Actuator.Controller.move_actuator(:right_track, right_track_cmd)
      # Actuator.Controller.move_actuator(actuator_pid.actuator, actuator_pid.output)
    end
    {:noreply, state}
  end

  def update_turn_and_speed_cmd(turn_and_speed_cmd) do
    GenServer.cast(__MODULE__, {:turn_and_speed_cmd, turn_and_speed_cmd})
  end

  def arm_actuators() do
    GenServer.cast(__MODULE__, :start_actuator_loop)
  end

  def disarm_actuators() do
    GenServer.cast(__MODULE__, :stop_actuator_loop)
  end
end
