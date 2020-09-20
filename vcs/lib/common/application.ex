defmodule Common.Application do
  use Application
  require Logger

  def start(_type, _args) do
    common_startup()
    Logger.debug("Start Application")
    Comms.System.start_link()
    Process.sleep(200)
    model_type = Common.Utils.Configuration.get_model_type()
    node_type = Common.Utils.Configuration.get_node_type()
    MessageSorter.System.start_link(model_type)
    Process.sleep(200)
    Configuration.Module.start_modules([Cluster, Logging, Time], model_type, node_type)
    Process.sleep(200)
    {:ok, self()}
  end

  @spec common_startup() :: atom()
  def common_startup() do
    RingLogger.attach()
    Common.Utils.File.mount_usb_drive()
    Cluster.Network.Utils.set_host_name()
  end

  @spec start_remaining_processes() :: atom()
  def start_remaining_processes() do
    # vehicle_type = Common.Utils.Configuration.get_vehicle_type()
    model_type = Common.Utils.Configuration.get_model_type()
    node_type = Common.Utils.Configuration.get_node_type()

    Logger.warn("Start remaining processes for #{model_type}/#{node_type}")
    modules = get_modules_for_node(node_type)
    Configuration.Module.start_modules(modules, model_type, node_type)
  end

  @spec get_modules_for_node(atom()) :: list()
  def get_modules_for_node(node_type) do
    case node_type do
      :gcs -> [Display.Scenic, Navigation, Peripherals.Uart]
      :sim -> [Actuation,Pids, Control, Estimation, Navigation, Command, Simulation, Peripherals.Uart, Display.Scenic]
      :server -> [Simulation, Peripherals.Uart, Display.Scenic]
      :all -> [Actuation, Pids, Control, Estimation, Health, Navigation, Command, Peripherals.Uart, Peripherals.Gpio, Peripherals.I2c]
      _vehicle -> [Actuation, Pids, Control, Estimation, Health, Navigation, Command, Peripherals.Uart, Peripherals.Gpio, Peripherals.I2c]
    end
  end


  @spec display_greeting(atom(), atom()) :: atom()
  def display_greeting(model_type, node_type) do
    Logger.info("------------------------------------")
    Enum.each(1..10, fn _x ->
      Logger.info("") end)
    Logger.warn("Hello! You are starting a #{node_type} node on a #{model_type} model!")
    Enum.each(1..10, fn _x ->
      Logger.info("") end)
    Logger.info("------------------------------------")
  end
end
