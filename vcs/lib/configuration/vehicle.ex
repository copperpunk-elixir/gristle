defmodule Configuration.Vehicle do
  require Logger

  @spec get_sorter_configs(atom()) :: list()
  def get_sorter_configs(vehicle_type) do
    base_module = Configuration.Vehicle
    vehicle_modules = [Control, Navigation]
    Enum.reduce(vehicle_modules, %{}, fn (module, acc) ->
      vehicle_module =
        Module.concat(base_module, vehicle_type)
        |>Module.concat(module)
      Enum.concat(acc,apply(vehicle_module, :get_sorter_configs,[]))
    end)
    |> Enum.concat(get_actuation_sorter_configs(vehicle_type))
  end

  def add_pid_input_constraints(pids, constraints) do
    Enum.reduce(pids, pids, fn ({pv, pv_cvs},acc) ->
      pid_config_with_input_constraints = 
        Enum.reduce(pv_cvs, pv_cvs, fn ({cv, pid_config}, acc2) ->
          # IO.puts("pv/cv/config: #{pv}/#{cv}/#{inspect(pid_config)}}")
          input_min = get_in(constraints, [pv, :output_min])
          input_max =get_in(constraints, [pv, :output_max])
          # IO.puts("input min/max: #{get_in(constraints, [pv, :output_min])}/#{get_in(constraints, [pv, :output_max])}")
          pid_config =
          if input_min == nil or input_max == nil do
            pid_config
          else
            Map.merge(pid_config, %{input_min: input_min, input_max: input_max})
          end
          Map.put(acc2, cv, pid_config)
        end)
      Map.put(acc,pv,pid_config_with_input_constraints)
    end)
  end

  @spec get_config_for_vehicle_and_module(atom(), atom()) :: map()
  def get_config_for_vehicle_and_module(vehicle_type, module) do
    config_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(module)
    case module do
      Command ->
        %{
          commander: %{vehicle_type: vehicle_type},
          frsky_rx: %{
            device_description: "Feather M0",
            publish_rx_output_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
          }}
      Control ->
        %{
          controller: %{
            vehicle_type: vehicle_type,
            process_variable_cmd_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
          }}
      Navigation ->
        %{
          navigator: %{
            vehicle_type: vehicle_type,
            navigator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
            default_pv_cmds_level: 3
          }}
      Pids -> apply(config_module, :get_config, [])
    end
  end

  @spec get_command_output_limits(atom(), list()) :: tuple()
  def get_command_output_limits(vehicle_type, channels) do
    vehicle_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(Pids)

    Enum.reduce(channels, %{}, fn (channel, acc) ->
      constraints =
        apply(vehicle_module, :get_constraints, [])
        |> Map.get(channel)
      Map.put(acc, channel, %{min: constraints.output_min, max: constraints.output_max})
    end)
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

  @spec get_actuation_config(atom(), atom()) :: map()
  def get_actuation_config(vehicle_type, node_type) do
    hw_config = %{
      interface_driver_name: :pololu,
      driver_config: %{
        baud: 115_200,
        write_timeout: 10,
        read_timeout: 10
      }
    }

    actuator_names = get_actuator_names(vehicle_type, node_type)
    sw_config = get_actuation_sw_config(actuator_names)
    %{
      hw_interface: hw_config,
      sw_interface: sw_config
    }
  end

  @spec get_actuation_sw_config(atom()) :: map()
  def get_actuation_sw_config(actuator_names) do
    {channels, failsafes} = get_channels_failsafes(actuator_names)
    actuators = Enum.reduce(0..length(actuator_names)-1, %{}, fn (index, acc) ->
      Map.put(acc, Enum.at(actuator_names, index), %{
            channel_number: Enum.at(channels, index),
            reversed: false,
            min_pw_ms: 1100,
            max_pw_ms: 1900,
            cmd_limit_min: 0.0,
            cmd_limit_max: 1.0,
            failsafe_cmd: Enum.at(failsafes, index)
              })
    end)

    #return config
    %{
      actuator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
      actuators: actuators
    }
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
      :wing -> [:aileron, :throttle]
      :fuselang -> [:throtle, :elevator, :rudder]
      :tail -> [:elevator, :rudder, :aileron]

      :steering -> [:steering, :throttle]
      :throttle -> [:throttle, :steering]

      :front_right -> [:front_right, :rear_right, :right_direction]
      :rear_right -> [:rear_right, :right_direction, :rear_left, :left_direction]
      :rear_left -> [:rear_left, :front_left, :left_direction]
      :front_left -> [:front_left, :left_direction, :front_right, :right_direction]
    end
  end
end
