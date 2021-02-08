defmodule Configuration.Module.Navigation do
  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module =
      Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
      |> Module.concat(Navigation)
    vehicle_limits = apply(vehicle_module, :get_vehicle_limits, [model_type])
    path_follower = apply(vehicle_module, :get_path_follower, [model_type])
    [
      node_type: node_type,
      navigator: [
        navigator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
        default_pv_cmds_level: 2
      ],
      path_manager:
        [
          path_follower: path_follower,
          model_type: model_type,
          peripheral_paths_update_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
        ] ++ vehicle_limits,
      path_planner: []
    ]
  end
end
