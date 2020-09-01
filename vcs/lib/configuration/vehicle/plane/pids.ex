defmodule Configuration.Vehicle.Plane.Pids do
  require Logger

  @spec get_config() :: map()
  def get_config() do
    model_type = Common.Utils.Configuration.get_model_type()
    model_module =
      Module.concat(Configuration.Vehicle.Plane.Pids, model_type)
    pids = apply(model_module, :get_pids, [])
    attitude = apply(model_module, :get_attitude, [])

    %{
      pids: pids,
      attitude_scalar: attitude,
      actuator_cmds_msg_classification: [0,1],
      pv_cmds_msg_classification: [0,1]
    }
  end
end
