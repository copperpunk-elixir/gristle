defmodule Configuration.Module.Navigation do
  require Command.Utils, as: CU

  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module = Common.Utils.mod_bin_mod_concat(Configuration.Vehicle, vehicle_type, Navigation)
    vehicle_limits = get_vehicle_limits(vehicle_module, model_type)
    path_follower = get_path_follower(vehicle_module, model_type)

    [
      node_type: node_type,
      navigator: [
        navigator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
        default_control_cmds_level: CU.cs_attitude
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

  @spec get_vehicle_limits(binary(), binary()) :: map()
  def get_vehicle_limits(vehicle_module, model_type) do

    model_module = Module.concat(vehicle_module, String.to_existing_atom(model_type))
    apply(model_module, :get_vehicle_limits, [])
  end

  @spec get_path_follower(binary(), binary()) :: list()
  def get_path_follower(vehicle_module, model_type) do
    model_module = Module.concat(vehicle_module, String.to_existing_atom(model_type))
    apply(model_module, :get_path_follower, [])
  end


  @spec get_sorter_configs(binary()) :: list()
  def get_sorter_configs(vehicle_type) do
    get_goals_sorter_configs(vehicle_type) ++ [get_peripheral_paths_sorter_config()]
  end

  @spec get_goals_sorter_configs(binary()) :: list()
  def get_goals_sorter_configs(vehicle_type) do
    vehicle_module =
      Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
      |> Module.concat(Control)

    goals_default_values = apply(vehicle_module, :get_control_cmds_sorter_default_values, [])
    goals_interval = Configuration.Generic.get_loop_interval_ms(:medium)

    Enum.map(CU.cs_rates..CU.cs_sca, fn level ->
      [
        name: {:goals, level},
        default_message_behavior: :default_value,
        default_value: goals_default_values[level],
        value_type: :map,
        publish_value_interval_ms: goals_interval
      ]
    end)
  end

  @spec get_peripheral_paths_sorter_config() :: list()
  def get_peripheral_paths_sorter_config() do
    [
      name: :peripheral_paths,
      default_message_behavior: :default_value,
      default_value: nil,
      value_type: :map,
      publish_value_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
    ]
  end
end
