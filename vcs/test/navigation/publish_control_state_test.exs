defmodule Navigation.PublishControlStateTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(vehicle_type)
    Comms.System.start_operator(__MODULE__)
    # nav_config = Configuration.Module.get_config(Navigation, vehicle_type, :all)
    # Navigation.System.start_link(nav_config)
    # config = Configuration.Module.get_config(Display.Scenic, vehicle_type, nil)
    # config = Configuration.Module.get_config(Estimation, vehicle_type, :all)
    # Estimation.System.start_link(config)
    # Display.Scenic.System.start_link(config)
    Configuration.Module.start_modules([Pids, Control, Estimation, Navigation, Command, Display.Scenic], vehicle_type, node_type)
    Process.sleep(400)
    {:ok, []}
  end

  test "Check Goals message sorter for content", context do
    Process.sleep(4000)
    Navigation.PathManager.load_random_takeoff()
    Process.sleep(4000)
  end
end
