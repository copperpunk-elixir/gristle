defmodule Configuration.Vehicle.Multirotor.Control do
  require Logger

  @spec get_pv_cmds_sorter_default_values() :: map()
  def get_pv_cmds_sorter_default_values() do
    %{
      1 => %{thrust: 0, rollrate: 0, pitchrate: 0, yawrate: 0},
      2 => %{thrust: 0, roll: 0, pitch: 0, yaw: 0},
      3 => %{course_flight: 0, speed: 0, altitude: 0, yaw: 0}
    }
  end
end
