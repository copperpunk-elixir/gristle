defmodule Configuration.Module.Control do
  require Command.Utils, as: CU

  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, _node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    pid_module =
      Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
      |> Module.concat(Pids)

    attitude = apply(pid_module, :get_attitude, [model_type])
    motor_moments =
    if vehicle_type == "Multirotor" do
      apply(pid_module, :get_motor_moments, [model_type])
    else
      nil
    end

    [
      controller: [
        attitude_scalar: attitude,
        vehicle_type: vehicle_type,
        motor_moments: motor_moments
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

    Enum.map(CU.cs_rates..CU.cs_sca, fn level ->
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
      default_value: CU.cs_attitude,
      value_type: :number,
      publish_value_interval_ms: 100
    ]
  end

end
