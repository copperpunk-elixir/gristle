defmodule Configuration.Vehicle.Plane.Pids do
  require Logger

  @spec get_config() :: map()
  def get_config() do
    aircraft_type = Common.Utils.get_aircraft_type()
    aircraft_module =
      Module.concat(Configuration.Vehicle.Plane.Pids, aircraft_type)
    pids = apply(aircraft_module, :get_pids, [])

    %{
      pids: pids,
      actuator_cmds_msg_classification: [0,1],
      pv_cmds_msg_classification: [0,1]
    }
  end
end
