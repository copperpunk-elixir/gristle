defmodule Configuration.Module.Command do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    %{
      commander: %{vehicle_type: vehicle_type},
    }
  end

  @spec get_command_output_limits(atom(), list()) :: map()
  def get_command_output_limits(vehicle_type, channels) do
    vehicle_module =
      case vehicle_type do
        :Plane ->
          model_type = Common.Utils.Configuration.get_model_type()
          Module.concat(Configuration.Vehicle.Plane.Pids, model_type)
        _other ->
          Module.concat(Configuration.Vehicle, vehicle_type)
          |> Module.concat(Pids)
      end

    Enum.reduce(channels, %{}, fn (channel, acc) ->
      IO.puts("channel: #{channel}")
      constraints =
        apply(vehicle_module, :get_constraints, [])
        |> Map.get(channel)
      Map.put(acc, channel, %{min: constraints.output_min, max: constraints.output_max})
    end)
  end

  @spec get_command_output_multipliers(atom(), list()) :: map()
  def get_command_output_multipliers(vehicle_type, channels) do
    vehicle_module =
      case vehicle_type do
        :Plane ->
          model_type = Common.Utils.Configuration.get_model_type()
          Module.concat(Configuration.Vehicle.Plane.Actuation, model_type)
      end

    reversed_actuators = apply(vehicle_module, :get_reversed_actuators, [])
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
        end
      if Enum.member?(reversed_actuators, channel) do
        Map.put(acc, command_name, -1)
      else
        Map.put(acc, command_name, 1)
      end
    end)
  end
end
