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
    cluster_config = Configuration.Generic.get_cluster_config()
    Cluster.System.start_link(cluster_config)
  end

  @spec start_remaining_processes() :: atom()
  def start_remaining_processes() do
    vehicle_type = Common.Utils.get_vehicle_type()
    node_type = Common.Utils.get_node_type()

    case node_type do
      :gcs -> start_gcs(vehicle_type)
      :sim -> start_simulation(vehicle_type)
      _other -> start_vehicle(vehicle_type, node_type)
    end
  end

  @spec start_vehicle(atom(), atom()) :: atom()
  def start_vehicle(vehicle_type, node_type) do
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    actuation_config = Configuration.Vehicle.get_actuation_config(vehicle_type, node_type)
    pid_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Pids)
    control_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Control)
    estimation_config = Configuration.Vehicle.get_estimation_config(node_type)
    navigation_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Navigation)
    command_config = Configuration.Vehicle.get_command_config(vehicle_type, node_type)

    Actuation.System.start_link(actuation_config)
    Pids.System.start_link(pid_config)
    Control.System.start_link(control_config)
    Estimation.System.start_link(estimation_config)
    Navigation.System.start_link(navigation_config)
    Command.System.start_link(command_config)
  end

  @spec start_gcs(binary()) :: atom()
  def start_gcs(vehicle_type) do
    # command_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Command)
    display_config = Configuration.Generic.get_display_config(vehicle_type)
    # Command.System.start_link(command_config)
    Display.Scenic.System.start_link(display_config)
  end


  @spec start_simulation(atom()) ::atom()
  def start_simulation(vehicle_type) do
    node_type = :sim
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    actuation_config = Configuration.Vehicle.get_actuation_config(vehicle_type, node_type)
    pid_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Pids)
    control_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Control)
    estimation_config = Configuration.Vehicle.get_estimation_config(node_type)
    navigation_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Navigation)
    command_config = Configuration.Vehicle.get_command_config(vehicle_type, node_type)
    simulation_config = Configuration.Generic.get_simulation_config(vehicle_type)
    display_config = Configuration.Generic.get_display_config(vehicle_type)


    Actuation.System.start_link(actuation_config)
    Pids.System.start_link(pid_config)
    Control.System.start_link(control_config)
    Estimation.System.start_link(estimation_config)
    Navigation.System.start_link(navigation_config)
    Command.System.start_link(command_config)
    Simulation.System.start_link(simulation_config)
    Display.Scenic.System.start_link(display_config)
  end
end
