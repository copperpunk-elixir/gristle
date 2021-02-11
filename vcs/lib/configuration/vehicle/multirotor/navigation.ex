defmodule Configuration.Vehicle.Multirotor.Navigation do
  require Logger
  require Command.Utils, as: CU

  @spec get_goals_sorter_default_values() :: map()
  def get_goals_sorter_default_values() do
    %{
      CU.cs_rates => %{thrust: 0, rollrate: 0, pitchrate: 0, yawrate: 0},
      CU.cs_attitude => %{thrust: 0, roll: 0, pitch: 0, yaw: 0},
      CU.cs_sca => %{course_flight: 0, speed: 0, altitude: 0}
    }
  end
end
