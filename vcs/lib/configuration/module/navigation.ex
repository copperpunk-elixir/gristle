defmodule Configuration.Module.Navigation do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    config_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(Navigation)
    vehicle_limits = apply(config_module, :get_vehicle_limits, [])

    %{
      navigator: %{
        vehicle_type: vehicle_type,
        navigator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
        default_pv_cmds_level: 3
      },
      path_manager: Map.merge(
        %{
          vehicle_type: vehicle_type,
          path_follower: %{
            k_path: 0.12,
            k_orbit: 3.5,
            chi_inf: 0.52
          }
        },
        vehicle_limits),
    }
  end
end
