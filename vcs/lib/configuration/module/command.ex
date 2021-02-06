defmodule Configuration.Module.Command do
  require Logger

  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, _node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module = Module.concat([Configuration.Vehicle, String.to_existing_atom(vehicle_type),Command])
    commands = apply(vehicle_module, :get_commands, [])
    output_limits = get_command_output_limits(model_type, vehicle_type, commands)
    command_multipliers = get_command_output_multipliers(model_type, vehicle_type, commands)
    rx_output_channel_map = apply(vehicle_module, :get_rx_output_channel_map, [output_limits, command_multipliers])
    [
      commander: [
        rx_output_channel_map: rx_output_channel_map
      ]
    ]
  end

  @spec get_command_output_limits(binary(), binary(), list()) :: map()
  def get_command_output_limits(model_type, vehicle_type, commands) do
    model_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    |> Module.concat(Pids)
    |> Module.concat(String.to_existing_atom(model_type))

    Enum.reduce(commands, %{}, fn (channel, acc) ->
      # Logger.warn("#{channel}")
      constraints =
        apply(model_module, :get_constraints, [])
        |> Keyword.get(channel)
      # Logger.warn(inspect(constraints))
      mid = Keyword.get(constraints, :output_mid, constraints[:output_neutral])
      Map.put(acc, channel, %{min: constraints[:output_min], mid: mid, max: constraints[:output_max]})
    end)
  end

  @spec get_command_output_multipliers(binary(), binary(), list()) :: map()
  def get_command_output_multipliers(model_type, vehicle_type, commands) do
    vehicle_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    |> Module.concat(Actuation)

    reversed_actuators = apply(vehicle_module, :get_reversed_actuators, [model_type])
    Enum.reduce(commands, %{}, fn (command_name, acc) ->
      channel =
        case command_name do
          :rollrate -> :aileron
          :pitchrate -> :elevator
          :yawrate -> :rudder
          :thrust -> :throttle
          :roll -> :aileron
          :pitch -> :elevator
          :yaw -> :rudder
          :yaw_offset -> :rudder
          :course_flight -> :aileron
          :course_ground -> :rudder
          :altitude -> :elevator
          :speed -> :throttle
          :aileron -> :aileron
          :elevator -> :elevator
          :throttle -> :throttle
          :rudder -> :rudder
          :flaps -> :flaps
          :gear -> :gear
          :brake -> :brake
        end
      if Enum.member?(reversed_actuators, channel) do
        Map.put(acc, command_name, -1)
      else
        Map.put(acc, command_name, 1)
      end
    end)
  end
end
