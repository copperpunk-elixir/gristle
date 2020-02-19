defmodule Actuator.InterfaceOutput do
  require Logger
  use GenServer

  def start_link(config) do
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    Logger.debug("Start ActuatorInterfaceOutput")
    actuators_not_ready()
    start_command_sorters()
    begin()
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    {:ok, %{
        actuators: config.actuators,
        actuator_driver: config.actuator_driver,
        uart_ref: nil,
        actuator_timer: nil,
        actuator_loop_interval_ms: config.actuator_loop_interval_ms
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Logger.debug("Begin ActuatorInterfaceOutput")
    uart_ref =
      case state.actuator_driver do
        :pololu ->
          Peripherals.Uart.PololuServo.open_port()
      end
    unless uart_ref == nil do
      actuators_ready()
    end
    {:noreply, %{state | uart_ref: uart_ref}}
  end

  @impl GenServer
  def handle_cast(:start_command_sorters, state) do
    Enum.each(state.actuators, fn {actuator_name, actuator} ->
      CommandSorter.System.start_sorter({__MODULE__, actuator_name}, actuator.cmd_limit_min, actuator.cmd_limit_max)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:actuators_not_ready, state) do
    Common.Utils.Comms.dispatch_cast(
      :topic_registry,
      :actuator_status,
      {:actuator_status, :not_ready}
    )
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:actuators_ready, state) do
    Common.Utils.Comms.dispatch_cast(
      :topic_registry,
      :actuator_status,
      {:actuator_status, :ready}
    )
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_actuator_loop, state) do
    state =
      case :timer.send_interval(state.actuator_loop_interval_ms, self(), :actuator_loop) do
        {:ok, actuator_timer} ->
          Logger.debug("Actuator loop started!")
          %{state | actuator_timer: actuator_timer}
        {_, reason} ->
          Logger.debug("Could not start actuator_interface_output timer: #{inspect(reason)} ")
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
          Logger.debug("Could not stop actuator_interface_output timer: #{inspect(reason)} ")
          state
      end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:actuator_cmd, cmd_type_min_max_exact, classification, actuator_cmds}, state) do
    Enum.each(actuator_cmds, fn {actuator, value} ->
      if output_in_bounds?(value) do
        CommandSorter.Sorter.add_command({__MODULE__, actuator}, cmd_type_min_max_exact, classification, value)
      end
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:actuator_loop, state) do
    # Go through every channel and send an update to the ActuatorInterfaceOutput
    # actuator_interface_output_process_name = state.config.actuator_interface_output.process_name
    Enum.each(state.actuators, fn {actuator_name, actuator} ->
      # Logger.debug("gimbal :move actuator")
      # actuator = get_in(state, [:actuators, actuator_name])
      output = get_output_for_actuator_name(actuator_name, actuator.failsafe_cmd)
      # Logger.debug("move_actuator on #{actuator_name} to #{output}")
      channel_number = actuator.channel_number
      pwm_ms = get_pw_for_actuator_and_output(state.actuator_driver, actuator, output)
      unless pwm_ms == nil do
        Peripherals.Uart.PololuServo.write_microseconds(state.uart_ref, channel_number, pwm_ms)
      end
    end)
    {:noreply, state}
  end

  # @impl GenServer
  # def handle_call({:get_output, actuator_name}, _from, state) do
  #   actuator = get_in(state, [:actuators, actuator_name])
  #   channel_number = actuator.channel_number
  #   output =
  #     case state.actuator_driver do
  #       :pololu ->
  #         Peripherals.Uart.PololuServo.get_output_for_channel_number(state.uart_ref, channel_number)
  #     end
  #   {:reply, output, state}
  # end

  def arm_actuators() do
    Logger.warn("arm_actuators called!")
    GenServer.cast(__MODULE__, :start_actuator_loop)
  end

  def disarm_actuators() do
    GenServer.cast(__MODULE__, :stop_actuator_loop)
  end

  def add_actuator_cmds(cmd_type_min_max_exact, classification, actuator_cmds) do
    GenServer.cast(__MODULE__, {:actuator_cmd, cmd_type_min_max_exact, classification, actuator_cmds})
  end

  # def move_actuator(actuator_name, output) do
  #   # Logger.debug("move actuator for #{actuator_name}")
  #   GenServer.cast(__MODULE__, {:move_actuator, actuator_name, output})
  # end

  def get_output_for_actuator_name(actuator_name, failsafe_cmd) do
    CommandSorter.Sorter.get_command({__MODULE__, actuator_name}, failsafe_cmd)
    # GenServer.call(__MODULE__, {:get_output, actuator_name})
  end

  def get_pw_for_actuator_and_output(actuator_driver, actuator, output) do
    unless output == nil do
      case actuator_driver do
        :pololu ->
          Peripherals.Uart.PololuServo.output_to_ms(output, actuator.reversed, actuator.min_pw_ms, actuator.max_pw_ms)
          # Logger.debug("channel/number/output/ms: #{channel}/#{channel_number}/#{output}/#{inspect(pwm_ms)}")
      end
    else
      nil
    end
  end

  defp begin() do
    GenServer.cast(__MODULE__, :begin)
  end

  defp actuators_not_ready() do
    GenServer.cast(__MODULE__, :actuators_not_ready)
  end

  defp actuators_ready() do
    GenServer.cast(__MODULE__, :actuators_ready)
  end

  defp start_command_sorters() do
    GenServer.cast(__MODULE__, :start_command_sorters)
  end

  defp output_in_bounds?(value) do
    !(value < 0 || value > 1)
  end


end
