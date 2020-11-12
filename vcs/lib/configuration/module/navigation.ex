defmodule Configuration.Module.Navigation do
  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module =
      Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
      |> Module.concat(Navigation)
    vehicle_limits = apply(vehicle_module, :get_vehicle_limits, [model_type])

    [
      node_type: node_type,
      navigator: %{
        navigator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        default_pv_cmds_level: 2
      },
      path_manager:
        [
          path_follower: [
            k_path: 0.05,
            k_orbit: 3.5,
            chi_inf: 0.52,
            lookahead_dt: 0.5
          ]
        ] ++ vehicle_limits,
      path_planner: []
    ]
  end
end
