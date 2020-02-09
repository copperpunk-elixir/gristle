defmodule Gimbal.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start GimbalController")
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    register_subscribers()
    start_command_sorters()
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok,  %{
        attitude: %{roll: 0, pitch: 0, yaw: 0},
        attitude_rate: %{roll: 0,pitch: 0, yaw: 0},
        imu_dt: 0,
        attitude_cmd: %{roll: 0, pitch: 0, yaw: 0},
        command_priority_max: config.command_priority_max,
        pid_time_prev_us: nil,
        imu_ready: false,
        actuators_ready: false,
        imu_timer: nil,
        actuator_timer: nil,
        actuator_pids: config.actuator_pids,
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
  def handle_cast(:start_command_sorters, state) do
    Enum.each(state.actuator_pids, fn {_actuator_name, actuator_pid} ->
      CommandSorter.System.start_sorter({__MODULE__, actuator_pid.process_variable}, state.command_priority_max)
    end)
    # Logger.debug("Start command sorters: #{inspect(cmd_variables)}")
    # CommandSorter.System.start_sorter({__MODULE__, :roll}, state.command_priority_max)
    # CommandSorter.System.start_sorter({__MODULE__, :pitch}, state.command_priority_max)
    # CommandSorter.System.start_sorter({__MODULE__, :yaw}, state.command_priority_max)
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
  def handle_cast({:imu_status, :ready}, state) do
    Logger.debug("Gimbal: IMU ready!")
    {:noreply, %{state | imu_ready: true}}
  end

  @impl GenServer
  def handle_cast({:imu_status, :not_ready}, state) do
    Logger.debug("Gimbal: IMU not ready!")
    {:noreply, %{state | imu_ready: false}}
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
  def handle_cast({:attitude_cmd, sorting, attitude_cmd}, state) do
    # Logger.debug("new att cmd: #{inspect(Common.Utils.rad2deg_map(attitude_cmd))}")
    expiration_mono_ms = :erlang.monotonic_time(:millisecond) + sorting.time_validity_ms
    Enum.each(attitude_cmd, fn {cmd_variable, value} ->
      CommandSorter.Sorter.add_command({__MODULE__, cmd_variable}, sorting.priority, sorting.authority, expiration_mono_ms, value)
    end)
    {:noreply, state}
    # if (attitude_cmd[:roll] != nil) do
    # end
    # if (attitude_cmd[:pitch] != nil) do
    #   CommandSorter.Sorter.add_command({__MODULE__, :pitch}, sorting.priority, sorting.authority, expiration_mono_ms, attitude_cmd.roll)
    # end
    # if (attitude_cmd[:roll] != nil) do
    #   CommandSorter.Sorter.add_command({__MODULE__, :roll}, sorting.priority, sorting.authority, expiration_mono_ms, attitude_cmd.roll)
    # end
    # roll_cmd = Map.get(attitude_cmd, :roll, state.attitude_cmd.roll)
    # pitch_cmd = Map.get(attitude_cmd, :pitch, state.attitude_cmd.pitch)
    # yaw_cmd = Map.get(attitude_cmd, :yaw, state.attitude_cmd.yaw)
    # {:noreply, %{state | attitude_cmd: %{roll: roll_cmd, pitch: pitch_cmd, yaw: yaw_cmd}}}
  end

  @impl GenServer
  def handle_cast({:pid_updated, channel_name, output}, state) do
    # actuator_pid = get_in(state.actuator_pids,[channel_name])
    # Logger.debug("Ch name/Actuator/output: #{channel_name}/#{actuator_pid.actuator}/#{output}")
    {:noreply, put_in(state,[:actuator_pids, channel_name, :output], output)}
  end

  @impl GenServer
  def handle_cast({:euler_eulerrate_dt, attitude, attitude_rate, imu_dt}, state) do
    # Logger.debug("attitude #{inspect(Common.Utils.rad2deg_map(attitude))}")
    # Logger.debug("rate: #{inspect(Common.Utils.rad2deg_map(attitude_rate))}")
    state = %{state | attitude: attitude, attitude_rate: attitude_rate, imu_dt: imu_dt}
    state = if (state.actuators_ready) do
      update_pid_controller(state)
    else
      Logger.debug("Actuators not ready")
      state
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:set_pid_gain, channel_name, gain_name, gain_value}, state) do
      # Allow this function to handle multiple channels with a single call
    channel_name =
    if(is_list(channel_name)) do
      channel_name
    else
      [channel_name]
    end
    Enum.each(channel_name, fn channel ->
      Pid.Controller.set_pid_gain(channel, gain_name, gain_value)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_parameter, parameter}, _from, state) do
    {:reply, Map.get(state, parameter), state}
  end

  @impl GenServer
  def handle_info(:actuator_loop, state) do
    # Go through every channel and send an update to the ActuatorController
    # actuator_controller_process_name = state.config.actuator_controller.process_name
    if state.imu_ready && state.actuators_ready do
      Enum.each(state.actuator_pids, fn {_channel, actuator_pid} ->
        # Logger.debug("gimbal :move actuator")
        Actuator.Controller.move_actuator(actuator_pid.actuator, actuator_pid.output)
      end )
    end
    {:noreply, state}
  end

  def imu_ready() do
    GenServer.cast(__MODULE__, :imu_ready)
  end

  def arm_actuators() do
    GenServer.cast(__MODULE__, {:actuator_status, :ready})
  end

  def disarm_actuators() do
    GenServer.cast(__MODULE__, {:actuator_status, :not_ready})
  end

  def set_pid_gain(channel_name, gain_name, gain_value) do
    GenServer.cast(__MODULE__, {:set_pid_gain, channel_name, gain_name, gain_value})
  end

  # defp via_tuple(system_id) do
  #   Common.ProcessRegistry.via_tuple({__MODULE__, system_id})
  # end

  def register_subscribers() do
    GenServer.cast(__MODULE__, :register_subscribers)
  end

  def start_command_sorters() do
    GenServer.cast(__MODULE__, :start_command_sorters)
  end

  def get_parameter(parameter) do
    GenServer.call(__MODULE__, {:get_parameter, parameter})
  end

  defp update_pid_controller(state) do
    current_time_us = :erlang.monotonic_time(:microsecond)
    dt =
      case state.pid_time_prev_us do
        nil ->
          0 # first reading, this will be multiplied by the P error
        time_prev_us->
          0.000001*(current_time_us - time_prev_us)
      end
    # Update the PID for each channel
    # Logger.debug("init att_cmds: #{inspect(state.attitude_cmd)}")
    attitude_cmd_updated = Enum.reduce(state.actuator_pids, state.attitude_cmd, fn ({channel_name, channel}, acc) ->
      # Logger.debug("#{channel_name}")
      cmd =
        case CommandSorter.Sorter.get_command({__MODULE__, channel.process_variable}) do
          nil -> state.attitude_cmd[channel.process_variable]
          value -> value
        end
      # cmd = state.attitude_cmd[channel.process_variable]
      act = state.attitude[channel.process_variable]
      act_rate = state.attitude[channel.process_variable]
      cmd_error = cmd - act
      Pid.Controller.update_pid(channel_name, cmd_error, act_rate, dt, self())
      Map.put(acc, channel.process_variable, cmd)
    end)
    Logger.debug("att_cmds: #{inspect(attitude_cmd_updated)}")
    %{state | pid_time_prev_us: current_time_us, attitude_cmd: attitude_cmd_updated}
  end
end
