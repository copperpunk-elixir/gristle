defmodule Common.Application do
  use Application
  require Logger

  def start(_type, _args) do
    common_startup()
    Logger.debug("Start Application")
    Comms.System.start_link()
    Process.sleep(200)
    vehicle_type = Common.Utils.Configuration.get_vehicle_type()
    MessageSorter.System.start_link(vehicle_type)
    # Cluster.System.start_link(Configuration.Module.get_config(Cluster, nil, nil))
    Process.sleep(200)
    # Logging.System.start_link(Configuration.Module.get_config(Logging, nil, nil))
    Configuration.Module.start_modules([Cluster, Logging, Time], nil, nil)
    # start_remaining_processes()
  end

  @spec common_startup() :: atom()
  def common_startup() do
    RingLogger.attach()
    Common.Utils.File.mount_usb_drive()
    Cluster.Network.Utils.set_host_name()
  end

  @spec start_remaining_processes() :: atom()
  def start_remaining_processes() do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type()
    node_type = Common.Utils.Configuration.get_node_type()
    Logger.warn("Start remaining processes for #{vehicle_type}/#{node_type}")
    case node_type do
      :gcs -> start_gcs(vehicle_type)
      :sim -> start_simulation(vehicle_type)
      :hil_server -> start_hil_server(vehicle_type)
      :hil_client -> start_hil_client(vehicle_type) 
      _other -> start_vehicle(vehicle_type, node_type)
    end
  end

  @spec start_vehicle(atom(), atom()) :: atom()
  def start_vehicle(vehicle_type, node_type) do
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    modules = [Actuation, Pids, Control, Estimation, Navigation, Command, Peripherals.Uart, Peripherals.Gpio]
    Configuration.Module.start_modules(modules, vehicle_type, node_type)
  end

  @spec start_gcs(binary()) :: atom()
  def start_gcs(vehicle_type) do
    node_type = :gcs
    modules = [Display.Scenic, Navigation, Peripherals.Uart]
    Configuration.Module.start_modules(modules, vehicle_type, node_type)
  end


  @spec start_simulation(atom()) ::atom()
  def start_simulation(vehicle_type) do
    node_type = :sim
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    modules = [Actuation,Pids, Control, Estimation, Navigation, Command, Simulation, Peripherals.Uart, Display.Scenic]
    Configuration.Module.start_modules(modules, vehicle_type, node_type)
  end

  @spec start_hil_server(atom()) ::atom()
  def start_hil_server(vehicle_type) do
    node_type = :sim
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    modules = [Actuation, Pids, Control, Estimation, Navigation, Command, Simulation, Peripherals.Uart, Display.Scenic]
    Configuration.Module.start_modules(modules, vehicle_type, node_type)
  end


  @spec start_hil_client(atom()) ::atom()
  def start_hil_client(vehicle_type) do
    node_type = :all
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    modules = [Actuation, Pids, Control, Estimation, Navigation, Command, Simulation, Peripherals.Uart, Peripherals.Gpio]
    Configuration.Module.start_modules(modules, vehicle_type, node_type)
  end

end
