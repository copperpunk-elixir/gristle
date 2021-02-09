defmodule Configuration.Module.Control do
  require Command.Utils, as: CU

  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, _node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module = Common.Utils.mod_bin_mod_concat(Configuration.Vehicle, vehicle_type, Command)
    command_channel_assignments = apply(vehicle_module, :get_command_channel_assignments, [])
    pv_keys = Map.take(command_channel_assignments, [CU.cs_rates, CU.cs_attitude, CU.cs_sca])
    [
      controller: [
        pv_keys: pv_keys
      ]
    ]
  end

  @spec get_sorter_configs(binary()) :: list()
  def get_sorter_configs(vehicle_type) do
    get_pv_cmds_sorter_configs(vehicle_type) ++ [get_control_state_sorter_config()]
  end

  @spec get_pv_cmds_sorter_configs(binary()) :: list()
  def get_pv_cmds_sorter_configs(vehicle_type) do
    vehicle_module = Common.Utils.mod_bin_mod_concat(Configuration.Vehicle, vehicle_type, Control)

    pv_cmds_default_values = apply(vehicle_module, :get_pv_cmds_sorter_default_values, [])
    pv_cmds_interval = Configuration.Generic.get_loop_interval_ms(:fast)

    Enum.map(1..3, fn level ->
      [
        name: {:pv_cmds, level},
        default_message_behavior: :default_value,
        default_value: pv_cmds_default_values[level],
        value_type: :map,
        publish_value_interval_ms: pv_cmds_interval
      ]
    end)
  end

  @spec get_control_state_sorter_config() :: map()
  def get_control_state_sorter_config() do
    [
      name: :control_state,
      default_message_behavior: :default_value,
      default_value: 2,
      value_type: :number,
      publish_value_interval_ms: 100
    ]
  end

end
