defmodule Peripherals.I2c.Health.Ina260.Operator do
  use Bitwise
  use GenServer
  require Logger

  @i2c_bus "i2c-1"
  @device_address 0x40
  @reg_config 0x00
  @reg_current 0x01
  @reg_voltage 0x02

  def start_link(config) do
    Logger.debug("Start INA260 GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, i2c_ref} = Circuits.I2C.open(@i2c_bus)
    {:ok, %{
        i2c_ref: i2c_ref,
        read_voltage_interval_ms: config.read_voltage_interval_ms,
        read_current_interval_ms: config.read_current_interval_ms,
        battery: Health.Hardware.Battery.new(config.battery_type, config.battery_channel)
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
    Logger.debug("INA260 begin with process: #{inspect(self())}")
    set_mode(state.i2c_ref)
    Process.sleep(100)
    Common.Utils.start_loop(self(), state.read_voltage_interval_ms, :read_voltage)
    Common.Utils.start_loop(self(), state.read_current_interval_ms, :read_current)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:read_voltage, state) do
    voltage = read_voltage(state.i2c_ref)
    battery = Health.Hardware.Battery.update_voltage(state.battery, voltage)
    {:noreply, %{state | battery: battery}}
  end

  @impl GenServer
  def handle_info(:read_current, state) do
    current = read_current(state.i2c_ref)
    battery = Health.Hardware.Battery.update_current(state.battery, current, state.read_current_interval_ms)
    {:noreply, %{state | battery: battery}}
  end

  @impl GenServer
  def handle_call({:get_battery_value, key}, _from, state) do
    value = Health.Hardware.Battery.get_value(state.battery, key)
    {:reply, value, state}
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

  @spec set_mode(any()) :: atom()
  def set_mode(i2c_ref) do
    avg_mode = 3 # 64 samples
    bus_volt_conv = 4 # 1.1ms (default)
    shunt_cur_conv = 4 # 1.1ms (default)
    op_mode = 7 # Continuous (default)
    data = <<0::1,6::3,avg_mode::3,bus_volt_conv::3,shunt_cur_conv::3,op_mode::3>>
    Circuits.I2C.write(i2c_ref, @device_address, <<@reg_config>> <> data)
  end

  @spec read_voltage(any()) :: float()
  def read_voltage(i2c_ref) do
    {:ok, <<msb, lsb>>} = Circuits.I2C.write_read(i2c_ref, @device_address, <<@reg_voltage>>, 2)
    voltage = ((msb<<<8) + lsb)*0.00125
    Logger.info("voltage: #{voltage}")
    voltage
  end

  @spec read_current(any()) :: float()
  def read_current(i2c_ref) do
    {:ok, <<msb, lsb>>} = Circuits.I2C.write_read(i2c_ref, @device_address, <<@reg_current>>, 2)
    current = ((msb<<<8) + lsb)*0.00125
    Logger.info("current: #{current}")
    current
  end

end