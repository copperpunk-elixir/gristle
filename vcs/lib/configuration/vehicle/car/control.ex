defmodule Configuration.Vehicle.Car.Control do
  require Logger
  require Command.Utils, as: CU

  @spec get_pv_cmds_sorter_default_values() :: map()
  def get_pv_cmds_sorter_default_values() do
    %{
      CU.cs_rates => %{thrust: 0, yawrate: 0, brake: 0.25},
      CU.cs_attitude => %{thrust: 0, yaw: 0},
      CU.cs_sca => %{course_ground: 0, speed: 0}
    }
  end
end
