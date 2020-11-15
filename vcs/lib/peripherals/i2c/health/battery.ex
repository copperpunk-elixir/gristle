defmodule Peripherals.I2c.Health.Battery.Operator do
  use Bitwise
  use GenServer
  require Logger

  @i2c_bus "i2c-1"

  def start_link(config) do
    Logger.info("Start I2c.Health.Ads1015.Operator GenServer")
    name = via_tuple(Keyword.fetch!(config, :battery_type), Keyword.fetch!(config, :battery_channel))
    Logger.debug("name: #{inspect(name)}")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, nil, name)
    GenServer.cast(pid, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    Comms.System.start_operator(__MODULE__)
    {:ok, i2c_ref} = Circuits.I2C.open(@i2c_bus)
    read_battery_interval_ms = Keyword.fetch!(config, :read_battery_interval_ms)
    battery_module = Module.concat(Peripherals.I2c.Health.Battery, Keyword.fetch!(config, :module))
    state = %{
      i2c_ref: i2c_ref,
      battery_module: battery_module,
      battery: Health.Hardware.Battery.new(Keyword.fetch!(config, :battery_type), Keyword.fetch!(config, :battery_channel)),
      read_battery_interval_ms: read_battery_interval_ms
    }
    #Configure sensor
    apply(state.battery_module, :configure, [state.i2c_ref])

    Common.Utils.start_loop(self(), read_battery_interval_ms, :read_battery)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:read_voltage, state) do
    battery = update_battery_voltage(state.i2c_ref, state.battery_module, state.battery)
    Logger.debug("voltage for #{state.battery.type}/#{state.battery.channel}: #{battery.voltage_V}")
    {:noreply, %{state | battery: battery}}
  end

  @impl GenServer
  def handle_cast(:read_current, state) do
    battery = update_battery_current(state.i2c_ref, state.battery_module, state.read_battery_interval_ms, state.battery)
    Logger.debug("current for #{state.battery.type}/#{state.battery.channel}: #{battery.current_A}")
    {:noreply, %{state | battery: battery}}
  end

  @impl GenServer
  def handle_info(:read_battery, state) do
    Logger.debug("read battery")
    battery = update_battery_voltage(state.i2c_ref, state.battery_module, state.battery)
    Process.sleep(20)
    battery = update_battery_current(state.i2c_ref, state.battery_module, state.read_battery_interval_ms, battery)
    send_battery_status(battery)
    {:noreply, %{state | battery: battery}}
  end

    @impl GenServer
  def handle_call(:get_battery, _from , state) do
    {:reply, state.battery, state}
  end

  @spec update_battery_voltage(any(), atom(), struct()) :: struct()
  def update_battery_voltage(i2c_ref, battery_module, battery) do
    voltage = apply(battery_module, :read_voltage, [i2c_ref])
    if is_nil(voltage), do: battery, else: Health.Hardware.Battery.update_voltage(battery, voltage)
  end

  @spec update_battery_current(any(), atom(), integer(), struct()) :: struct()
  def update_battery_current(i2c_ref, battery_module, interval_ms, battery) do
    current = apply(battery_module, :read_current, [i2c_ref])
    if is_nil(current), do: battery, else: Health.Hardware.Battery.update_current(battery, current, interval_ms*0.001)
  end

  @spec send_battery_status(struct()) :: atom()
  def send_battery_status(battery) do
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:battery_status, battery}, self())
  end

  @spec request_read_voltage(binary(), binary()) :: atom()
  def request_read_voltage(battery_type, battery_channel) do
    GenServer.cast(via_tuple(battery_type, battery_channel), :read_voltage)
  end

  @spec request_read_current(binary(), binary()) :: atom()
  def request_read_current(battery_type, battery_channel) do
    GenServer.cast(via_tuple(battery_type, battery_channel), :read_current)
  end

  @spec get_battery(binary(), binary()) :: struct()
  def get_battery(battery_type, battery_channel) do
    Common.Utils.safe_call(via_tuple(battery_type, battery_channel), :get_battery, 100, nil)
  end

  @spec via_tuple(atom(), integer()) :: tuple()
  def via_tuple(battery_type, channel) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,{battery_type, channel})
  end
end
