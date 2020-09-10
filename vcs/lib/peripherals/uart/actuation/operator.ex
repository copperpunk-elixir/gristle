defmodule Peripherals.Uart.Actuation.Operator do
  use GenServer
  require Logger

@connection_count_max 10

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    Logger.debug("Start Actuation Operator")
    GenServer.cast(__MODULE__, {:begin, config.driver_config})
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    Logger.warn("Actuation module: #{config.interface_module}")
    {:ok, %{
        interface_module: config.interface_module,
        # driver_config: config.driver_config,
        interface: nil,
        channels: %{}
     }
    }
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, driver_config}, state) do
    interface = apply(state.interface_module, :new_device, [driver_config])
    interface = Peripherals.Uart.Utils.open_interface_connection(state.interface_module, interface, 0, @connection_count_max)
    {:noreply, %{state | interface: interface}}
  end

  @impl GenServer
  def handle_cast({:update_actuators, actuators_and_outputs}, state) do
    channels = Enum.reduce(actuators_and_outputs, state.channels, fn ({_actuator_name, {actuator, output}}, acc) ->
      # Logger.info("op #{actuator_name}: #{output}")
      pulse_width_us = output_to_us(output, actuator.reversed, actuator.min_pw_us, actuator.max_pw_us)
      Map.put(acc, actuator.channel_number, pulse_width_us)
    end)

    apply(state.interface_module, :write_channels, [state.interface, channels])
    {:noreply, %{state | channels: channels}}
  end

  @spec update_actuators(map()) :: atom()
  def update_actuators(actuators_and_outputs) do
    GenServer.cast(__MODULE__, {:update_actuators, actuators_and_outputs})
  end

  def output_to_us(output, reversed, min_pw_us, max_pw_us) do
    # Output will arrive in range [-1,1]
    if (output < 0) || (output > 1) do
      nil
    else
      # output = 0.5*(output + 1.0)
      case reversed do
        false ->
          min_pw_us + output*(max_pw_us - min_pw_us)
        true ->
          max_pw_us - output*(max_pw_us - min_pw_us)
      end
    end
  end

end
