defmodule Peripherals.I2c.Health.Ina260.Operator do
  use Bitwise
  use GenServer
  require Logger

  @i2c_bus "i2c-1"

  def start_link(config) do
    Logger.debug("Start INA260 GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, i2c_ref} = Circuits.I2c.open_link(@i2c_bus)
    {:ok, %{
        i2c_ref: i2c_ref,
        read_voltage_interval_ms: config.read_voltage_interval_ms,
        read_current_interval_ms: config.read_voltage_interval_ms,
        voltage: -1,
        current: -1,
        mAh_used: -1
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
    Common.Utils.start_loop(self(), state.read_voltage_interval_ms, :read_voltage)
    Common.Utils.start_loop(self(), state.read_current_interval_ms, :read_current)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:read_voltage, state) do
    Logger.debug("read voltage")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:read_voltage, state) do
    Logger.debug("read voltage")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_value, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @spec get_voltage() :: float()
  def get_voltage() do
    Common.Utils.safe_call(__MODULE__, {:get_value, :voltage}, 200, -1)
  end

  @spec get_current() :: float()
  def get_current() do
    Common.Utils.safe_call(__MODULE__, {:get_value, :current}, 200, -1)
  end

end
