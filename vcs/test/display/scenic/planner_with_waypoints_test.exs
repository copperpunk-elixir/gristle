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
    Process.sleep(200)
    Comms.System.start_operator(__MODULE__)

    # Create mission
    speed = 10
    alt = 100
    lat1 = 45.00#Common.Utils.Math.deg2rad(45.00)
    lon1 = -120.0#Common.Utils.Math.deg2rad(-120.0)
    # North
    lat2 = 45.01#Common.Utils.Math.deg2rad(45.01)
    lon2 = -120.0#Common.Utils.Math.deg2rad(-120.0)
    # East
    lat3 = 45.01#Common.Utils.Math.deg2rad(45.01)
    lon3 = -119.99#Common.Utils.Math.deg2rad(-119.99)
    # South
    lat4 = 45.0#Common.Utils.Math.deg2rad(45.00)
    lon4 = -119.99#Common.Utils.Math.deg2rad(-119.99)


    wp1 = Navigation.Waypoint.new_waypoint(lat1, lon1, speed, 0, alt, "wp1")
    wp2 = Navigation.Waypoint.new_waypoint(lat2, lon2, speed, 0, alt, "wp2")
    wp3 = Navigation.Waypoint.new_waypoint(lat3, lon3, speed, :math.pi, alt, "wp3")
    wp4 = Navigation.Waypoint.new_waypoint(lat4, lon4, speed, :math.pi, alt, "wp4")


    mission = Navigation.Mission.new_mission("box", [wp1, wp2,wp3,wp4])

    calculated = %{speed: 1.0, course: 0.0}
    position = %{latitude: 45.002, longitude: -120.0, altitude: 0}
    attitude = %{yaw: 0.75}


    bounding_box = Display.Scenic.Planner.calculate_lat_lon_bounding_box(mission, position, true)
    Logger.debug("bounding box: #{inspect(bounding_box)}")
    {min_lat, max_lat, min_lon, max_lon} = bounding_box
    assert min_lat = lat1
    assert max_lon = lon2

    origin = Display.Scenic.Planner.calculate_origin_and_pixel_ratio(bounding_box, 800, 600)
    Logger.debug("origin lat/lon: #{origin.lat}/#{origin.lon}")
    Comms.Operator.send_global_msg_to_group(
      __MODULE__,
      {:add_mission, mission},
      :add_mission,
      self())


    # Comms.Operator.send_global_msg_to_group(
    #   __MODULE__,
    #   {:pv_estimate, %{position: position, attitude: attitude, calculated: calculated}},
    #   :pv_estimate,
    #   self())

    vehicle_type = context[:vehicle_type]
    Process.sleep(400000)
  end
end
