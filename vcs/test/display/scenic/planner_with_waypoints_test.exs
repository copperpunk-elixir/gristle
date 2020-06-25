defmodule Display.Scenic.PlannerWithWaypointsTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    # Need estimation and command
    # config = Configuration.Module.get_config(Estimation, vehicle_type,node_type)
    # Estimation.System.start_link(config)
        config = Configuration.Module.get_config(Display.Scenic, vehicle_type, nil)
    Display.Scenic.System.start_link(config)

    {:ok, [vehicle_type: vehicle_type ]}
  end

  test "load gcs", context do
    Process.sleep(400)
    Comms.System.start_operator(__MODULE__)

    # Create mission
    speed = 10
    alt = 100
    lat1 = Common.Utils.Math.deg2rad(47.53)
    lon1 = Common.Utils.Math.deg2rad(-120.32)
    # North
    lat2 = Common.Utils.Math.deg2rad(47.54)
    lon2 = Common.Utils.Math.deg2rad(-120.32)
    # East
    lat3 = Common.Utils.Math.deg2rad(47.54)
    lon3 = Common.Utils.Math.deg2rad(-120.29)
    # South
    lat4 = Common.Utils.Math.deg2rad(47.53)
    lon4 = Common.Utils.Math.deg2rad(-120.29)


    wp1 = Navigation.Path.Waypoint.new(lat1, lon1, speed, 0, alt, "wp1")
    wp2 = Navigation.Path.Waypoint.new(lat2, lon2, speed, 0, alt, "wp2")
    wp3 = Navigation.Path.Waypoint.new(lat3, lon3, speed, :math.pi, alt, "wp3")
    wp4 = Navigation.Path.Waypoint.new(lat4, lon4, speed, :math.pi, alt, "wp4")


    mission = Navigation.Path.Mission.new_mission("box", [wp1, wp2,wp3,wp4])

    Navigation.PathManager.load_mission(mission, __MODULE__)
    calculated = %{speed: 1.0, course: 0.0}
    position = %{latitude: Common.Utils.Math.deg2rad(47.535), longitude: Common.Utils.Math.deg2rad(-120.30), altitude: 0}
    attitude = %{yaw: 0.0}


    bounding_box = Display.Scenic.Planner.calculate_lat_lon_bounding_box(mission, position, true)
    Logger.debug("bounding box: #{inspect(bounding_box)}")
    {min_lat, max_lat, min_lon, max_lon} = bounding_box
    assert min_lat = lat1
    assert max_lon = lon2

    origin = Display.Scenic.Planner.calculate_origin(bounding_box, 800, 600)
    Logger.debug("origin lat/lon: #{origin.lat}/#{origin.lon}")

    Comms.Operator.send_global_msg_to_group(
      __MODULE__,
      {:pv_estimate, %{position: position, attitude: attitude, calculated: calculated}},
      :pv_estimate,
      self())

    vehicle_type = context[:vehicle_type]
    Process.sleep(400000)
  end
end
