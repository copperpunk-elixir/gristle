defmodule Configuration.Module.Command do
  @spec get_config(atom(), atom()) :: map()
  def get_config(model_type, _node_type) do
    # vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    %{
      commander: %{model_type: model_type},
    }
  end

  @spec get_command_output_limits(atom(), atom(), list()) :: map()
  def get_command_output_limits(model_type, vehicle_type, channels) do
    model_module = Module.concat(Configuration.Vehicle, vehicle_type)
    |> Module.concat(Pids)
    |> Module.concat(model_type)

    Enum.reduce(channels, %{}, fn (channel, acc) ->
      constraints =
        apply(model_module, :get_constraints, [])
        |> Map.get(channel)
      Map.put(acc, channel, %{min: constraints.output_min, max: constraints.output_max})
    end)
  end

  @spec get_command_output_multipliers(atom(), atom(), list()) :: map()
  def get_command_output_multipliers(model_type, vehicle_type, channels) do
    vehicle_module = Module.concat(Configuration.Vehicle, vehicle_type)
    |> Module.concat(Actuation)

    reversed_actuators = apply(vehicle_module, :get_reversed_actuators, [model_type])
    Enum.reduce(channels, %{}, fn (command_name, acc) ->
      channel =
        case command_name do
          :rollrate -> :aileron
          :pitchrate -> :elevator
          :yawrate -> :rudder
          :thrust -> :throttle
          :roll -> :aileron
          :pitch -> :elevator
          :yaw -> :rudder
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
        end
      if Enum.member?(reversed_actuators, channel) do
        Map.put(acc, command_name, -1)
      else
        Map.put(acc, command_name, 1)
      end
    end)
  end
end
