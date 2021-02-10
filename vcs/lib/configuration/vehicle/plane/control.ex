defmodule Configuration.Vehicle.Plane.Control do
  require Logger
  require Command.Utils, as: CU

  @spec get_pv_cmds_sorter_default_values() :: map()
  def get_pv_cmds_sorter_default_values() do
    %{
      CU.cs_rates => %{thrust: 0, rollrate: 0, pitchrate: 0, yawrate: 0},
      CU.cs_attitude => %{thrust: 0, roll: 0.175, pitch: 0.05, yaw: 0.09},
      CU.cs_sca => %{course_flight: 0, speed: 0, altitude: 0}
    }
  end
end
