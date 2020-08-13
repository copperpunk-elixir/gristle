defmodule Common.Application do
  use Application
  require Logger

  def start(_type, _args) do
    Logger.debug("Start Application")
    Comms.System.start_link()
    Process.sleep(200)
    Common.Utils.mount_usb_drive()
    vehicle_type = Common.Utils.get_vehicle_type()
    MessageSorter.System.start_link(vehicle_type)
    # Cluster.System.start_link(Configuration.Module.get_config(Cluster, nil, nil))
    Logging.System.start_link(Configuration.Module.get_config(Logging, nil, nil))
    start_remaining_processes()
  end

  @spec start_remaining_processes() :: atom()
  def start_remaining_processes() do
    vehicle_type = Common.Utils.get_vehicle_type()
    node_type = Common.Utils.get_node_type()
    Logger.warn("Start remaining processes for #{vehicle_type}/#{node_type}")
    case node_type do
      :gcs -> start_gcs(vehicle_type)
      :sim -> start_simulation(vehicle_type)
      :hil -> start_hil(vehicle_type)
      _other -> start_vehicle(vehicle_type, node_type)
    end
  end

  @spec start_vehicle(atom(), atom()) :: atom()
  def start_vehicle(vehicle_type, node_type) do
    RingLogger.attach()
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    Configuration.Module.start_modules([Actuation, Pids, Control, Estimation, Navigation, Command, Telemetry], vehicle_type, node_type)
  end

  @spec start_gcs(binary()) :: atom()
  def start_gcs(vehicle_type) do
    Logger.add_backend(:console)
    node_type = :gcs
    Configuration.Module.start_modules([Display.Scenic, Navigation, Telemetry], vehicle_type, node_type)
  end


  @spec start_simulation(atom()) ::atom()
  def start_simulation(vehicle_type) do
    RingLogger.attach()
    node_type = :sim
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    Configuration.Module.start_modules([Actuation,Pids, Control, Estimation, Navigation, Command, Simulation, Telemetry, Display.Scenic], vehicle_type, node_type)
  end

  @spec start_hil(atom()) ::atom()
  def start_hil(vehicle_type) do
    RingLogger.attach()
    node_type = :all
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    Configuration.Module.start_modules([Actuation, Pids, Control, Estimation, Navigation, Command, Display.Scenic, Telemetry], vehicle_type, node_type)
  end

end
