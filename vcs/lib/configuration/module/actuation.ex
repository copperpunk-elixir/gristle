defmodule Configuration.Module.Actuation do
  require Logger

  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, node_type) do
    [
      sw_interface: get_actuation_sw_config(model_type, node_type)
    ]
  end

  @spec get_actuation_sw_config(binary(), binary()) :: list()
  def get_actuation_sw_config(model_type, node_type) do
    [node_type, node_metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    vehicle_module = get_vehicle_module(model_type)

    actuator_names = get_actuators_for_node(model_type, node_type)

    {min_pw_us, max_pw_us} = get_min_max_pw(model_type)

    indirect_actuators =
      Enum.reduce(actuator_names.indirect, %{}, fn ({channel_number, actuator_name}, acc) ->
        Map.put(acc, actuator_name, get_default_actuator_config(actuator_name, channel_number, min_pw_us, max_pw_us))
      end)
      |> apply_reversed_actuators(model_type, vehicle_module)

    direct_actuators =
      Enum.reduce(actuator_names.direct, %{}, fn ({channel_number, actuator_name}, acc) ->
        Map.put(acc, actuator_name, get_default_actuator_config(actuator_name, channel_number, min_pw_us, max_pw_us))
      end)
      |> apply_reversed_actuators(model_type, vehicle_module)

    actuator_sorter_intervals = apply(vehicle_module, :get_actuator_sorter_intervals,[])

    output_modules = get_output_modules(node_type, node_metadata)

    [
      actuator_loop_interval_ms: actuator_sorter_intervals[:actuator_loop_interval_ms],
      indirect_actuator_sorter_interval_ms: actuator_sorter_intervals[:indirect_actuator_sorter_interval_ms],
      direct_actuator_sorter_interval_ms: actuator_sorter_intervals[:direct_actuator_sorter_interval_ms],
      indirect_override_sorter_interval_ms: actuator_sorter_intervals[:indirect_actuator_sorter_interval_ms],
      actuators: %{
        indirect: indirect_actuators,
        direct: direct_actuators
      },
      output_modules: output_modules
    ]
  end

  @spec get_output_modules(binary(), binary()) :: list()
  def get_output_modules(node_type, node_metadata) do
    case node_type do
      "sim" ->  Configuration.Module.Simulation.get_modules(node_metadata)
      "server" ->
        Configuration.Module.Simulation.get_modules(node_metadata)
        ++ [Peripherals.Uart.ActuationCommand.Operator]
      "all" -> [Peripherals.Uart.ActuationCommand.Operator]
      _other -> [Peripherals.Uart.Actuation.Operator]
    end
  end

  @spec get_default_actuator_config(atom(), integer(), float(), float()) :: map()
  def get_default_actuator_config(name, channel_number, min_pw_us, max_pw_us) do
    %{
      channel_number: channel_number,
      reversed: false,
      min_pw_us: min_pw_us,
      max_pw_us: max_pw_us,
      cmd_limit_min: 0.0,
      cmd_limit_max: 1.0,
      failsafe_cmd: get_failsafe_for_actuator(name)
    }
  end

  @spec apply_reversed_actuators(map(), binary(), atom()) :: map()
  def apply_reversed_actuators(actuators, model_type, vehicle_module) do
    reversed_actuators = apply(vehicle_module, :get_reversed_actuators, [model_type])
    Enum.reduce(reversed_actuators, actuators, fn (actuator_name, acc) ->
      if Map.has_key?(acc, actuator_name) do
        put_in(acc, [actuator_name, :reversed], true)
      else
        acc
      end
    end)
  end

  @spec get_min_max_pw(binary()) :: tuple()
  def get_min_max_pw(model_type) do
    vehicle_module = get_vehicle_module(model_type)
    model_module = Module.concat(vehicle_module, String.to_existing_atom(model_type))
    apply(model_module, :get_min_max_pw, [])
  end

  @spec get_failsafe_for_actuator(atom()) :: float()
  def get_failsafe_for_actuator(actuator_name) do
    case actuator_name do
      :aileron -> 0.5
      :elevator -> 0.5
      :rudder -> 0.5
      :steering -> 0.5
      :front_right -> 0.5
      :rear_right -> 0.5
      :rear_left -> 0.5
      :front_left -> 0.5
      :left_direction -> 0.5
      :right_direction -> 0.5
      :throttle -> 0.0
      :flaps -> 0.0
      :gear -> 0.0
      :motor1 -> 0.0
      :motor2 -> 0.0
      :motor3 -> 0.0
      :motor4 -> 0.0
      :brake -> 0.0
    end
  end

  @spec get_all_actuator_channels_and_names(binary()) :: map()
  def get_all_actuator_channels_and_names(model_type) do
    vehicle_module = get_vehicle_module(model_type)
    model_module = Module.concat(vehicle_module, String.to_existing_atom(model_type))
    apply(model_module, :get_all_actuator_channels_and_names, [])
  end

  @spec get_actuators_for_node(binary(), binary()) :: list()
  def get_actuators_for_node(model_type, node_type) do
    case node_type do
      "all" -> get_all_actuator_channels_and_names(model_type)
      "sim" -> get_all_actuator_channels_and_names(model_type)

      "left-side" -> get_all_actuator_channels_and_names(model_type)
      "right-side" -> get_all_actuator_channels_and_names(model_type)

      "steering" -> get_all_actuator_channels_and_names(model_type)
      "throttle" -> get_all_actuator_channels_and_names(model_type)
    end
  end

  @spec get_sorter_configs(binary()) :: list()
  def get_sorter_configs(model_type) do
    actuator_names = get_all_actuator_channels_and_names(model_type)
    indirect_failsafe_map = Enum.reduce(actuator_names.indirect, %{}, fn({_ch_num, actuator_name}, acc) ->
      failsafe_value = get_failsafe_for_actuator(actuator_name)
      Map.put(acc, actuator_name, failsafe_value)
    end)

    indirect_sorter = [
      name: :indirect_actuator_cmds,
      default_message_behavior: :default_value,
      default_value: indirect_failsafe_map,
      value_type: :map,
      publish_value_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
    ]

    indirect_override_sorter = [
      name: :indirect_override_actuator_cmds,
      default_message_behavior: :default_value,
      default_value: indirect_failsafe_map,
      value_type: :map,
      publish_value_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
    ]

    direct_sorters = Enum.reduce(actuator_names.direct, [], fn({_ch_num, actuator_name}, acc) ->
      failsafe_value = get_failsafe_for_actuator(actuator_name)
      sorter = [
        name: {:direct_actuator_cmds, actuator_name},
        default_message_behavior: :default_value,
        default_value: failsafe_value,
        value_type: :number,
        publish_value_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
      ]
      [sorter] ++ acc
      # Map.put(acc, actuator_name, failsafe_value)
    end)
    # return config
    [indirect_sorter, indirect_override_sorter] ++ direct_sorters
  end

  @spec get_vehicle_module(binary()) :: atom()
  def get_vehicle_module(model_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    Common.Utils.mod_bin_mod_concat(Configuration.Vehicle, vehicle_type, Actuation)
  end
end
