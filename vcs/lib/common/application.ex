defmodule Common.Application do
  use Application
  require Logger

  def start(_type, _args) do
    Logger.debug("Start Application")
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    Common.Utils.mount_usb_drive()
    vehicle_type = Common.Utils.get_vehicle_type()
    MessageSorter.System.start_link(vehicle_type)
    Cluster.System.start_link(Configuration.Module.get_config(Cluster, nil, nil))
  end

  @spec start_remaining_processes() :: atom()
  def start_remaining_processes() do
    vehicle_type = Common.Utils.get_vehicle_type()
    node_type = Common.Utils.get_node_type()
    Logger.warn("Start remaining processes for #{vehicle_type}/#{node_type}")
    case node_type do
      :gcs -> start_gcs(vehicle_type)
      :sim -> start_simulation(vehicle_type)
      _other -> start_vehicle(vehicle_type, node_type)
    end
  end

  @spec start_vehicle(atom(), atom()) :: atom()
  def start_vehicle(vehicle_type, node_type) do
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    Configuration.Module.start_modules([Actuation, Pids, Control, Estimation, Navigation, Command], vehicle_type, node_type)
  end

  @spec start_gcs(binary()) :: atom()
  def start_gcs(vehicle_type) do
    display_config = Configuration.Module.get_config(Display, vehicle_type, nil)
    Display.Scenic.System.start_link(display_config)
  end


  @spec start_simulation(atom()) ::atom()
  def start_simulation(vehicle_type) do
    node_type = :sim
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    Configuration.Module.start_modules([Actuation, Pids, Control, Estimation, Navigation, Simulation, Display.Scenic], vehicle_type, node_type)
  end
end
