defmodule Peripherals.I2c.Health.Ads1015.Operator do
  use Bitwise
  use GenServer
  require Logger

  @i2c_bus "i2c-1"
  @device_address 0x48
  @config_os_single 0x8000
  @config_mode_cont 0x0000
  @config_mux_single_0 0x4000
  @config_rate_128_hz 0x0000
  # @config_rate_1600_hz 0x0080
  @pointer_config 1
  @pointer_convert 0
  @config_pga_1 0x0200
  # @config_pga_2 0x0400

  @counts2output 2.0 #output is in mV
  # @output2volts 0.00412712
  # @output2amps 0.0136612


  @channel_voltage 0
  @channel_current 1

  def start_link(config) do
    Logger.info("Start I2c.Health.Ads1015.Operator GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, i2c_ref} = Circuits.I2C.open(@i2c_bus)
    {:ok, %{
        i2c_ref: i2c_ref,
        read_battery_interval_ms: Keyword.fetch!(config, :read_battery_interval_ms),
        battery: Health.Hardware.Battery.new(Keyword.fetch!(config, :battery_type), Keyword.fetch!(config, :battery_channel)),
        voltage_mult: Keyword.fetch!(config, :voltage_mult),
        current_mult: Keyword.fetch!(config, :current_mult)
     }
    }
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Logger.debug("Ads1015 begin with process: #{inspect(self())}")
    Common.Utils.start_loop(self(), state.read_battery_interval_ms, :read_battery)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:read_battery, state) do
    # Logger.debug("read battery #{state.battery.type}/#{state.battery.channel}")
    voltage = read_voltage(state.i2c_ref, state.voltage_mult)
    # Process.sleep(10)
    current = read_current(state.i2c_ref, state.current_mult)

    battery = if is_nil(voltage), do: state.battery, else: Health.Hardware.Battery.update_voltage(state.battery, voltage)
    battery = if is_nil(current), do: battery, else: Health.Hardware.Battery.update_current(battery, current, state.read_battery_interval_ms*0.001)
    send_battery_status(battery)
    {:noreply, %{state | battery: battery}}
  end

  @impl GenServer
  def handle_call({:get_battery_value, key}, _from, state) do
    value = Health.Hardware.Battery.get_value(state.battery, key)
    {:reply, value, state}
  end

  @spec send_battery_status(struct()) :: atom()
  def send_battery_status(battery) do
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:battery_status, battery}, self())
  end

  @spec get_voltage() :: float()
  def get_voltage() do
    Common.Utils.safe_call(__MODULE__, {:get_battery_value, :voltage}, 200, -1)
  end

  @spec get_current() :: float()
  def get_current() do
    Common.Utils.safe_call(__MODULE__, {:get_battery_value, :current}, 200, -1)
  end

  @spec get_energy_discharged() :: float()
  def get_energy_discharged() do
    Common.Utils.safe_call(__MODULE__, {:get_battery_value, :energy_discharged}, 200, -1)
  end

  @spec read_voltage(any(), float()) :: float()
  def read_voltage(i2c_ref, output2volts) do
    result = read_channel(i2c_ref, @channel_voltage)
    case result do
      {:ok, output} ->
        # Logger.debug("Ads1015 voltage: #{output*output2volts}")
        output*output2volts
      _other ->
        Logger.error("Voltage read error")
        nil
    end
  end

  @spec read_current(any(), float()) :: float()
  def read_current(i2c_ref, output2amps) do
    result = read_channel(i2c_ref, @channel_current)
    case result do
      {:ok, current} ->
        # Logger.debug("Ads1015 current: #{current*output2amps}")
        current*output2amps
      _other ->
        Logger.error("Current read error")
        nil
    end
  end

  @spec read_channel(any(), integer()) :: tuple()
  def read_channel(i2c_ref, channel) do
    config = @config_os_single ||| @config_mode_cont ||| @config_rate_128_hz
    config = config ||| @config_pga_1
    config = config ||| (@config_mux_single_0 + (channel <<< 12))
    # require IEx; IEx.pry
    data = <<@pointer_config, config >>> 8, config &&& 0xFF>>
    # IO.puts("write data: #{data}")
    Circuits.I2C.write(i2c_ref, @device_address, data)
    Process.sleep(20)
    {msg, result} = Circuits.I2C.write_read(i2c_ref, @device_address, <<@pointer_convert>>, 2)
    # Logger.debug("value: #{inspect(result)}")
    if msg == :ok do
      if result == "" do
      {:error, :bad_ack}
      else
        <<msb, lsb>> = result
        output = (((msb <<< 8) + lsb) >>> 4)*@counts2output
        {:ok, output}
      end
    else
      {:error, :bus_not_available}
    end
  end
end
