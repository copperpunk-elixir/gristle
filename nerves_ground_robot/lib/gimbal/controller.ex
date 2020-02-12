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
        actuator_cmd_classification: config.actuator_cmd_classification,
        pid_time_prev_us: nil,
        imu_ready: false,
        actuators_ready: false,
        imu_timer: nil,
        pid_actuator_links: config.pid_actuator_links,
        # pid_outputs: %{},
        # actuator_output: %{}, #in the form of %{actuator: output},
        # actuator_loop_interval_ms: config.actuator_loop_interval_ms,
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
    # Command sorters will store the values of all the process variable COMMANDS
    # i.e. ROLL, or PITCH, or YAW
    Enum.each(state.pid_actuator_links, fn pid_actuator_link ->
      CommandSorter.System.start_sorter({__MODULE__, pid_actuator_link.process_variable}, pid_actuator_link.cmd_limit_min, pid_actuator_link.cmd_limit_max)
    end)
    {:noreply, state}
  end


  @impl GenServer
  def handle_cast({:imu_status, :ready}, state) do
    Logger.debug("Gimbal: IMU ready!")
    if state.actuators_ready do
      Logger.debug("Actuators are ready, arm actuators")
      Actuator.Controller.arm_actuators()
    else
      Logger.debug("Waiting for actuators ready to arm")
    end
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
    if state.imu_ready do
      Logger.debug("IMU is ready, arm actuators")
      Actuator.Controller.arm_actuators()
    else
      Logger.debug("IMU not ready yet, do not arm actuators")
    end
    # GenServer.cast(__MODULE__, :start_actuator_loop)
    {:noreply, %{state | actuators_ready: true}}
  end

  @impl GenServer
  def handle_cast({:actuator_status, :not_ready}, state) do
    Logger.debug("Gimbal: Actuators not ready!")
    # GenServer.cast(__MODULE__, :stop_actuator_loop)
    {:noreply, %{state | actuators_ready: false}}
  end

  @impl GenServer
  def handle_cast({:attitude_cmd, cmd_type_min_max_exact, classification, attitude_cmd}, state) do
    # Logger.debug("new att cmd: #{inspect(Common.Utils.rad2deg_map(attitude_cmd))}")
    Enum.each(attitude_cmd, fn {cmd_process_variable, value} ->
      CommandSorter.Sorter.add_command({__MODULE__, cmd_process_variable}, cmd_type_min_max_exact, classification, value)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:pid_updated, _process_variable, actuator, output}, state) do
    # Logger.debug("Ch name/Actuator/output: #{channel_name}/#{actuator_pid.actuator}/#{output}")
    Actuator.Controller.add_actuator_cmds(:exact, state.actuator_cmd_classification, Map.put(%{}, actuator, output))
    {:noreply, state}
    # {:noreply, put_in(state,[:pid_outputs, process_variable, actuator], output)}
  end

  @impl GenServer
  def handle_cast({:euler_eulerrate_dt, attitude, attitude_rate, imu_dt}, state) do
    # Logger.debug("attitude #{inspect(Common.Utils.Math.rad2deg_map(attitude))}")
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

  # TODO: Implement this
  # @impl GenServer
  # def handle_cast({:set_pid_gain, process_variable, actuator, gain_name, gain_value}, state) do
  #     # Allow this function to handle multiple channels with a single call
  #   channel_name =
  #   if(is_list(channel_name)) do
  #     channel_name
  #   else
  #     [channel_name]
  #   end
  #   Enum.each(channel_name, fn channel ->
  #     Pid.Controller.set_pid_gain(channel, gain_name, gain_value)
  #   end)
  #   {:noreply, state}
  # end

  @impl GenServer
  def handle_call({:get_parameter, parameter}, _from, state) do
    {:reply, Map.get(state, parameter), state}
  end

  def imu_ready() do
    GenServer.cast(__MODULE__, :imu_ready)
  end

  # def arm_actuators() do
  #   GenServer.cast(__MODULE__, {:actuator_status, :ready})
  # end

  # def disarm_actuators() do
  #   GenServer.cast(__MODULE__, {:actuator_status, :not_ready})
  # end

  # TODO: implement this
  def set_pid_gain(process_variable, actuator, gain_name, gain_value) do
    GenServer.cast(__MODULE__, {:set_pid_gain, process_variable, actuator, gain_name, gain_value})
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
    dt = get_dt_since_prev(current_time_us, state.pid_time_prev_us)
    # Update the PID for each channel
    # Logger.debug("init att_cmds: #{inspect(state.attitude_cmd)}")
    # attitude_cmd_updated = Enum.reduce(state.pid_actuator_links, state.attitude_cmd, fn (pid_actuator_link, acc) ->
    Enum.each(state.pid_actuator_links, fn pid_actuator_link ->
      process_variable = pid_actuator_link.process_variable
      actuator = pid_actuator_link.actuator
      # Logger.debug("#{channel_name}")
      cmd = CommandSorter.Sorter.get_command({__MODULE__, process_variable}, pid_actuator_link.failsafe_cmd)
      # cmd = state.attitude_cmd[channel.process_variable]
      act = state.attitude[process_variable]
      act_rate = state.attitude[process_variable]
      cmd_error = cmd - act
      Pid.Controller.update_pid(process_variable, actuator, cmd_error, act_rate, dt, self())
      # Map.put(acc, channel.process_variable, cmd)
    end)
    # Logger.debug("att_cmds: #{inspect(attitude_cmd_updated)}")
    %{state | pid_time_prev_us: current_time_us}
  end

  defp get_dt_since_prev(current_time_us, time_prev_us) do
    case time_prev_us do
      nil ->
        0 # first reading, this will be multiplied by the P error
      time_prev_us->
        0.000001*(current_time_us - time_prev_us)
    end
  end

end
