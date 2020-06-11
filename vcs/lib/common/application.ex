defmodule Common.Application do
  use Application
  require Logger

  def start(_type, _args) do
    Logger.debug("Start Application")
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    Cluster

    path = "/mnt"
    Common.Utils.mount_usb_drive(path)
    vehicle_type = Common.Utils.get_filename_with_extension(path, ".vehicle") |> String.to_atom()
    node_type = Common.Utils.get_filename_with_extension(path, ".node") |> String.to_atom()

    MessageSorter.System.start_link(vehicle_type)
    case node_type do
      :gcs -> start_gcs(vehicle_type)
      _other -> start_vehicle(vehicle_type, node_type)
    end
  end

  @spec start_vehicle(atom(), atom()) :: atom()
  def start_vehicle(vehicle_type, node_type) do
    Logger.info("vehicle/node: #{vehicle_type}/#{node_type}")
    actuation_config = Configuration.Vehicle.get_actuation_config(vehicle_type, node_type)
    Logger.info("#{inspect(actuation_config)}")
    pid_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Pids)
    control_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Control)
    estimation_config = Configuration.Generic.get_estimator_config()
    navigation_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Navigation)
    command_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Command)

    Actuation.System.start_link(actuation_config)
    Pids.System.start_link(pid_config)
    Control.System.start_link(control_config)
    Estimation.System.start_link(estimation_config)
    Navigation.System.start_link(navigation_config)
    Command.System.start_link(command_config)
  end

  @spec start_gcs(binary()) :: atom()
  def start_gcs(vehicle_type) do
    command_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Command)
    display_config = Configuration.Generic.get_display_config(vehicle_type)
    Command.System.start_link(command_config)
    Display.Scenic.System.start_link(display_config)
  end
end
