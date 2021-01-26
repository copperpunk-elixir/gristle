defmodule Navigation.Path.LawnmowerWaypointsTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    model_type = "CessnaZ2m"
    {:ok, [model_type: model_type]}
  end

  test "relative wps test", context do
    model_type = context[:model_type]
    airport = "cone_field"
    runway = "36L"
    wps = Navigation.Path.Mission.get_lawnmower_waypoints(airport, runway, model_type, 4, 25, 100)
    Enum.each(wps, fn wp ->
      Logger.debug("#{inspect(wp)}")
    end)
    Process.sleep(100)
  end
end
