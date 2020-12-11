defmodule Navigation.Path.RelativeTrackWaypointsTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    model_type = "CessnaZ2m"
    {:ok, [model_type: model_type]}
  end

  test "relative wps test", context do
    model_type = context[:model_type]
    airport = "flight_school"
    runway = "18L"
    track_type = "racetrack_left"
    wps = Navigation.Path.Mission.get_track_waypoints(airport, runway, track_type, model_type, true)
    Enum.each(wps, fn wp ->
      Logger.debug("#{inspect(wp)}")
    end)
    Process.sleep(100)
  end
end
