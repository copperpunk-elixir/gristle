defmodule Navigation.Path.Protobuf.MissionProtoTest do
  use ExUnit.Case
  require Logger

  setup do
    Common.Application.common_startup()
    node_type = :gcs
    Process.sleep(100)
    vehicle_type = Common.Utils.Configuration.get_vehicle_type()
    Logging.System.start_link(Configuration.Module.get_config(Logging, nil, nil))

    Configuration.Module.start_modules([Display.Scenic,Navigation, Peripherals.Uart], vehicle_type, node_type)
    {:ok, []}
  end

  # test "Create Mission Protobuf" do
  #   airport = "montague"
  #   runway = "18R"
  #   aircraft_type = :EC1500
  #   track_type = :hourglass
  #   num_wps = 0
  #   mission = Navigation.Path.Mission.get_complete_mission(airport, runway, aircraft_type, track_type, num_wps)
  #   pb_encoded = Navigation.Path.Mission.encode(mission, false)
  #   Logger.debug("msg len: #{String.length(pb_encoded)}")
  #   pb_decoded = Navigation.Path.Protobuf.Mission.decode(pb_encoded)
  #   assert pb_decoded.name == mission.name
  #   Enum.each(Enum.with_index(mission.waypoints), fn {wp, index} ->
  #     assert wp.name == Map.get(Enum.at(pb_decoded.waypoints,index), :name)
  #   end)
  # end

  test "Send Protobuf" do
    Comms.System.start_operator(__MODULE__)
    Process.sleep(200)
    # airport = "montague"
    # runway = "18R"
    # model_type = :EC1500
    # track_type = :hourglass
    # num_wps = 0
    # Navigation.PathPlanner.send_path_mission(airport, runway, model_type, track_type, num_wps, true)
    Navigation.PathPlanner.load_montague_18R(:hourglass)
    # mission = Navigation.Path.Mission.get_complete_mission(airport, runway, aircraft_type, track_type, num_wps)
    # pb_encoded = Navigation.Path.Mission.encode(mission, true)
    # pb_encoded = Enum.reduce(0..900,"",fn (x,acc) ->
    #   acc <> "#{rem(x,10)}"
    # end)
    # Logger.debug("pb_encoded: #{inspect(pb_encoded)}")
    # Process.sleep(100)
    # Peripherals.Uart.Telemetry.Operator.construct_and_send_proto_message(:mission_proto, pb_encoded)
    Process.sleep(100000)
  end
end
