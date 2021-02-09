defmodule Configuration.Module.Control do
  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, _node_type) do
    [
      controller: []
    ]
  end

  @spec get_sorter_configs(binary()) :: list()
  def get_sorter_configs(vehicle_type) do
    get_pv_cmds_sorter_configs(vehicle_type) ++ [get_control_state_sorter_config()]
  end

  @spec get_pv_cmds_sorter_configs(binary()) :: list()
  def get_pv_cmds_sorter_configs(vehicle_type) do
    vehicle_module =
      Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
      |> Module.concat(Control)

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
