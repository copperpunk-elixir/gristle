defmodule Configuration.Module.Pids do
  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, _node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module =
      Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
      |> Module.concat(Pids)
    pids = apply(vehicle_module, :get_pids, [model_type])
    attitude = apply(vehicle_module, :get_attitude, [model_type])
    motor_moments =
    if vehicle_type == "Multirotor" do
      apply(vehicle_module, :get_motor_moments, [model_type])
    else
      nil
    end
    [
      pids: pids,
      attitude_scalar: attitude,
      actuator_cmds_msg_classification: [0,1],
      pv_cmds_msg_classification: [0,1],
      vehicle_type: vehicle_type,
      motor_moments: motor_moments
    ]
  end
end
