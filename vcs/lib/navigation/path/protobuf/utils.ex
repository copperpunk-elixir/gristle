defmodule Navigation.Path.Protobuf.Utils do
  require Logger

  @spec new_mission(binary()) :: map()
  def new_mission(mission_pb) do
    Navigation.Path.Mission.new_mission(mission_pb.name, mission_pb.waypoints, mission_pb.vehicle_turn_rate)
    |> rectify_mission()
  end

  @spec rectify_mission(map()) :: map()
  def rectify_mission(mission) do
    wps = Enum.map(mission.waypoints, fn wp ->
      # goto = if (wp.goto<0), do: nil, else: wp.goto
      goto= if (wp.goto == ""), do: nil, else: wp.goto
      type = wp.type |> to_string() |> String.downcase |> String.to_existing_atom()
      %{wp | type: type, goto: goto}
    end)
    %{mission | waypoints: wps}
  end

  @spec decode_mission(binary()) :: struct()
  def decode_mission(msg) do
    mission_pb = Navigation.Path.Protobuf.Mission.decode(:binary.list_to_bin(msg))
    # Logger.debug("misson: #{mission_pb.name}")
    mission_pb
  end
end
