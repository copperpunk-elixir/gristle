defmodule Configuration.Module.Pids do
  @spec get_config(atom(), atom()) :: map()
  def get_config(model_type, _node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(Pids)
    pids = apply(vehicle_module, :get_pids, [model_type])
    attitude = apply(vehicle_module, :get_attitude, [model_type])
    %{
      pids: pids,
      attitude_scalar: attitude,
      actuator_cmds_msg_classification: [0,1],
      pv_cmds_msg_classification: [0,1]
    }
  end
end
