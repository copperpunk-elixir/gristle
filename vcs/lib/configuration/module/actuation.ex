defmodule Configuration.Module.Actuation do
  require Logger

  @spec get_config(atom(), atom()) :: map()
  def get_config(model_type, node_type) do
    sw_config = get_actuation_sw_config(model_type, node_type)
    %{
      sw_interface: sw_config
    }
  end

  @spec get_actuation_sw_config(atom(), atom()) :: map()
  def get_actuation_sw_config(model_type, node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(Actuation)

    actuator_names = get_actuator_names(model_type, node_type)
    actuator_names = Map.merge(actuator_names.direct, actuator_names.indirect)
    |> Map.merge(actuator_names.selector)
    # {channels, failsafes} = get_channels_failsafes(actuator_names)
    {min_pw_us, max_pw_us} = get_min_max_pw(node_type)
    actuators = Enum.reduce(actuator_names, %{}, fn ({channel_number, actuator_name}, acc) ->
      Map.put(acc, actuator_name, %{
            channel_number: channel_number,
            reversed: false,
            min_pw_us: min_pw_us,
            max_pw_us: max_pw_us,
            cmd_limit_min: 0.0,
            cmd_limit_max: 1.0,
            failsafe_cmd: get_failsafe_for_actuator(actuator_name)
              })
    end)

    actuators = apply_reversed_actuators(model_type, vehicle_module, actuators)

    output_modules =
      case node_type do
        :sim -> [Peripherals.Uart.Actuation.Operator]
        _other -> [Peripherals.Uart.Actuation.Operator]
      end

    %{
      actuator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
      actuators: actuators,
      output_modules: output_modules
    }
  end

  @spec apply_reversed_actuators(atom(), atom(), map()) :: map()
  def apply_reversed_actuators(model_type, vehicle_module, actuators) do
    reversed_actuators = apply(vehicle_module, :get_reversed_actuators, [model_type])
    Enum.reduce(reversed_actuators, actuators, fn (actuator_name, acc) ->
      if Map.has_key?(acc, actuator_name) do
        put_in(acc, [actuator_name, :reversed], true)
      else
        acc
      end
    end)
  end

  @spec get_min_max_pw(atom()) :: tuple()
  def get_min_max_pw(node_type) do
    case node_type do
      :front_right -> {64, 4080}
      :rear_right -> {64, 4080}
      :rear_left  -> {64, 4080}
      :front_left -> {64, 4080}
      _other -> {1100, 1900}
    end
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
      :select -> Actuation.SwInterface.guardian_control_value()
    end
  end

  @spec get_all_actuator_channels_and_names(atom()) :: map()
  def get_all_actuator_channels_and_names(model_type) do
    case model_type do
      # :FourWheelRobot -> [:front_right, :rear_right, :rear_left, :front_left, :left_direction, :right_direction]
      :Car -> %{ 0 => :steering, 1 => :throttle}
      :Cessna -> %{
                 indirect: %{
                   0 => :aileron,
                   1 => :elevator,
                   2 => :throttle,
                   3 => :rudder},
                 direct: %{
                   4 => :flaps,
                 },
                 selector: %{
                   5 => :select
                 }
             }
      :EC1500 -> %{
                 indirect: %{
                   0 => :aileron,
                   1 => :elevator,
                   2 => :throttle,
                   3 => :rudder},
                 direct: %{
                   4 => :flaps,
                 },
                 selector: %{
                   5 => :select
                 }

             }
    end
  end

  @spec get_actuator_names(atom(), atom()) :: list()
  def get_actuator_names(model_type, node_type) do
    case node_type do
      :all -> get_all_actuator_channels_and_names(model_type)
      :sim -> get_all_actuator_channels_and_names(model_type)
      :hil_server -> get_all_actuator_channels_and_names(model_type)

      :wing -> [:aileron, :throttle]
      :fuselage -> [:throtle, :elevator, :rudder]
      :tail -> [:elevator, :rudder, :aileron]

      :steering -> [:steering, :throttle]
      :throttle -> [:throttle, :steering]

      :front_right -> [:front_right, :rear_right, :right_direction]
      :rear_right -> [:rear_right, :right_direction, :rear_left, :left_direction]
      :rear_left -> [:rear_left, :front_left, :left_direction]
      :front_left -> [:front_left, :left_direction, :front_right, :right_direction]
    end
  end

  @spec get_actuation_sorter_configs(atom()) :: list()
  def get_actuation_sorter_configs(model_type) do
    actuator_names = get_all_actuator_channels_and_names(model_type)
    Logger.info("actuator names: #{inspect(actuator_names)}")
    # {_channels, indirect_failsafes} = get_channels_failsafes(actuator_names.indirect)
    # {_channels, direct_failsafes} = get_channels_failsafes(actuator_names.direct)
    # indirect_names_with_index = Enum.with_index(actuator_names)
    indirect_failsafe_map = Enum.reduce(actuator_names.indirect, %{}, fn({_ch_num, actuator_name}, acc) ->
      failsafe_value = get_failsafe_for_actuator(actuator_name)
      Map.put(acc, actuator_name, failsafe_value)
    end)
    direct_failsafe_map = Enum.reduce(actuator_names.direct, %{}, fn({_ch_num, actuator_name}, acc) ->
      failsafe_value = get_failsafe_for_actuator(actuator_name)
      Map.put(acc, actuator_name, failsafe_value)
    end)

    # return config
    [
      %{
        name: :indirect_actuator_cmds,
        default_message_behavior: :default_value,
        default_value: indirect_failsafe_map,
        value_type: :map
      },
      %{
        name: :direct_actuator_cmds,
        default_message_behavior: :default_value,
        default_value: direct_failsafe_map,
        value_type: :map
      },
      %{
        name: :actuation_selector,
        default_message_behavior: :default_value,
        default_value: Actuation.SwInterface.guardian_control_value(),
        value_type: :number
      }
    ]
  end
end
