defmodule Configuration.Module.Actuation do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, node_type) do
    # hw_config = %{
    #   interface_driver_name: :feather,
    #   driver_config: %{
    #     baud: 115_200,
    #     write_timeout: 1,
    #     read_timeout: 1
    #   }
    # }

    sw_config = get_actuation_sw_config(vehicle_type, node_type)
    %{
      # hw_interface: hw_config,
      sw_interface: sw_config
    }
  end

  @spec get_actuation_sw_config(atom(), atom()) :: map()
  def get_actuation_sw_config(vehicle_type, node_type) do
    actuator_names = get_actuator_names(vehicle_type, node_type)
    {channels, failsafes} = get_channels_failsafes(actuator_names)
    {min_pw_us, max_pw_us} = get_min_max_pw(node_type)
    actuators = Enum.reduce(0..length(actuator_names)-1, %{}, fn (index, acc) ->
      Map.put(acc, Enum.at(actuator_names, index), %{
            channel_number: Enum.at(channels, index),
            reversed: false,
            min_pw_us: min_pw_us,
            max_pw_us: max_pw_us,
            cmd_limit_min: 0.0,
            cmd_limit_max: 1.0,
            failsafe_cmd: Enum.at(failsafes, index)
              })
    end)

    model_type = Common.Utils.Configuration.get_model_type()
    model_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(Actuation)
    |> Module.concat(model_type)

    actuators = apply_reversed_actuators(model_module, actuators)

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

  @spec apply_reversed_actuators(atom(), map()) :: map()
  def apply_reversed_actuators(model_module, actuators) do
    reversed_actuators = apply(model_module, :get_reversed_actuators, [])
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

  @spec get_channels_failsafes(list()) :: tuple()
  def get_channels_failsafes(actuator_names) do
    {channels_rev, failsafes_rev} = Enum.reduce(actuator_names, {[],[]}, fn (actuator_name, acc) ->
      {channels, failsafes} = acc
      channel = Enum.at(channels,0,-1) + 1
      failsafe = get_failsafe_for_actuator(actuator_name)
      {[channel | channels], [failsafe | failsafes]}
    end)
    {Enum.reverse(channels_rev), Enum.reverse(failsafes_rev)}
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
    end
  end

  @spec get_all_actuator_names_for_vehicle(atom()) :: list()
  def get_all_actuator_names_for_vehicle(vehicle_type) do
    case vehicle_type do
      :FourWheelRobot -> [:front_right, :rear_right, :rear_left, :front_left, :left_direction, :right_direction]
      :Car -> [:steering, :throttle]
      :Plane -> [:aileron,  :elevator, :throttle, :rudder]
    end
  end

  @spec get_actuator_names(atom(), atom()) :: list()
  def get_actuator_names(vehicle_type, node_type) do
    case node_type do
      :all -> get_all_actuator_names_for_vehicle(vehicle_type)
      :sim -> get_all_actuator_names_for_vehicle(vehicle_type)

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
  def get_actuation_sorter_configs(vehicle_type) do
    actuator_names = get_all_actuator_names_for_vehicle(vehicle_type)
    {_channels, failsafes} = get_channels_failsafes(actuator_names)
    names_with_index = Enum.with_index(actuator_names)
    failsafe_map = Enum.reduce(names_with_index, %{}, fn({actuator_name, index}, acc) ->
      Map.put(acc, actuator_name, Enum.at(failsafes,index))
    end)
    # return config
    [
      %{
        name: :actuator_cmds,
        default_message_behavior: :default_value,
        default_value: failsafe_map,
        value_type: :map
      }
    ]
  end
end
