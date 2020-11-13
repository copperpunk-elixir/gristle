defmodule Peripherals.I2c.Health.Ina219.Operator do
  use Bitwise
  use GenServer
  require Logger

  @i2c_bus "i2c-1"
  @device_address 0x48
  @reg_config 0x00
  @reg_bus_voltage 0x02
  @reg_current 0x04
  @reg_calibration 0x05

  def start_link(config) do
    Logger.info("Start I2c.Health.INA219.Operator GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, i2c_ref} = Circuits.I2C.open(@i2c_bus)
    {:ok, %{
        i2c_ref: i2c_ref,
        current_divider: 10,
        cal_value: 4096,
        read_voltage_interval_ms: Keyword.fetch!(config, :read_voltage_interval_ms),
        read_current_interval_ms: Keyword.fetch!(config, :read_current_interval_ms),
        battery: Health.Hardware.Battery.new(Keyword.fetch!(config, :battery_type), Keyword.fetch!(config, :battery_channel))
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
    Logger.debug("INA219 begin with process: #{inspect(self())}")
    set_mode(state.i2c_ref, state.cal_value)
    Process.sleep(100)
    Common.Utils.start_loop(self(), state.read_voltage_interval_ms, :read_voltage)
    # Process.sleep(50)
    # Common.Utils.start_loop(self(), state.read_current_interval_ms, :read_current)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:read_channel, channel}, state) do
    output = read_channel(state.i2c_ref, channel)
    Logger.debug("channel #{channel} output: #{output}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:read_voltage, state) do
    voltage = read_voltage(state.i2c_ref)
    battery = if is_nil(voltage), do: state.battery, else: Health.Hardware.Battery.update_voltage(state.battery, voltage*0.001)
    send_battery_status(battery)
    {:noreply, %{state | battery: battery}}
  end

  @impl GenServer
  def handle_info(:read_current, state) do
    current = read_current(state.i2c_ref)
    current = if is_nil(current), do: nil, else: current/state.current_divider
    Logger.info("current: #{current}")
    battery = if is_nil(current), do: state.battery, else: Health.Hardware.Battery.update_current(state.battery, current, state.read_current_interval_ms*0.001)
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

  @spec set_mode(any(), integer()) :: atom()
  def set_mode(i2c_ref, cal_value) do
    Circuits.I2C.write(i2c_ref, @device_address, <<@reg_calibration>> <> <<cal_value::16>>)
    Process.sleep(5)
    brng = 1 # Bus Voltage Range (32V)
    pg = 3 # PGA gain/range (+/- 320mV)
    badc = 3 # Bus ADC Resolution/Averaging (12-bit)
    sadc = 3 # Shunt ADC Resolution/Averaging (12-bit 1S 532us)
    mode = 7 # Operating Mode (Shunt and Bus, Continuous)
    data = <<0::2,brng::1,pg::2, badc::4, sadc::4, mode::3>>
    Circuits.I2C.write(i2c_ref, @device_address, <<@reg_config>> <> data)
  end

  @spec read_voltage(any()) :: float()
  def read_voltage(i2c_ref) do
    result = read_channel(i2c_ref, @reg_bus_voltage)
    case result do
      {:ok, voltage} ->
        Logger.debug("Ina219 voltage (raw): #{voltage}")
        (voltage>>>3)*4
      other ->
        Logger.error("Ina219 Voltage read error: #{inspect(other)}")
        nil
    end
  end

  @spec read_current(any()) :: float()
  def read_current(i2c_ref) do
    result = read_channel(i2c_ref, @reg_current)
    case result do
      {:ok, current} ->
        Logger.debug("Ina219 current (raw): #{current}")
        current
      other ->
        Logger.error("Ina219 Current read error: #{inspect(other)}")
        nil
    end
  end

  @spec read_channel(any(), integer()) :: tuple()
  def read_channel(i2c_ref, channel) do
    {msg, result} = Circuits.I2C.write_read(i2c_ref, @device_address, <<channel>>, 2)
    if msg == :ok do
      if result == "" do
        {:error, :bad_ack}
      else
        <<msb, lsb>> = result
        Logger.debug("msb/lsb: #{msb}/#{lsb}")
        output = ((msb<<<8) + lsb)
        {:ok, output}
      end
    else
      {:error, :bus_not_available}
    end
  end

  @spec request_read(integer()) :: atom()
  def request_read(channel)  do
    GenServer.cast(__MODULE__, {:read_channel, channel})
  end

end
