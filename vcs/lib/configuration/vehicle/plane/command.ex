defmodule Configuration.Vehicle.Plane.Command do
  require Logger
  require Command.Utils, as: CU

  @spec get_rx_output_channel_map(map(), map()) :: list()
  def get_rx_output_channel_map(output_limits, command_multipliers) do
    # channel_number, channel, absolute/relative, min, max
    relative_channels = [:course_flight, :altitude]
    actuation_channel_assignments = %{
      0 => [:aileron, :rollrate, :roll, :course_flight],
      1 => [:elevator, :pitchrate, :pitch, :altitude],
      2 => [:throttle, :thrust, :speed],
      3 => [:rudder, :yawrate, :yaw],
      4 => [:flaps],
      5 => [:gear],
      # 7 => [:select]
    }

    command_channel_assignments = %{
      CU.cs_rates => [:rollrate, :pitchrate, :yawrate, :thrust],
      CU.cs_attitude => [:roll, :pitch, :yaw, :thrust],
      CU.cs_sca => [:course_flight, :speed, :altitude],
      # Manual only channels
      CU.cs_direct_manual => [:aileron, :elevator, :rudder, :throttle],
      # Manual and Semi-Auto channels
      CU.cs_direct_semi_auto => [:flaps, :gear],
      # Auto only channels
      CU.cs_direct_auto => []
    }
    # cs_values = [1, 2, 3, CU.cs_direct_manual, CU.cs_direct_semi_auto, CU.cs_direct_auto]
    Enum.reduce(command_channel_assignments, %{}, fn ({cs, command_channels}, acc) ->
      # channels = Map.get(cs_channels, cs)
      all_channels_config =
        Enum.reduce(actuation_channel_assignments, [], fn ({ch_num, actuation_channels}, acc2) ->
          all_chs = command_channels ++ actuation_channels
          # Logger.debug("all ch: #{inspect(all_chs)}")
          # Find the channels that match between Actuation and Command for a given CS
          shared_channels = all_chs -- Enum.uniq(all_chs)
          if Enum.empty?(shared_channels) do
            acc2
          else
            channel_name = Enum.at(shared_channels, 0)
            relative_or_absolute = if Enum.member?(relative_channels, channel_name), do: :relative, else: :absolute
            ch_config = get_channel_config(Map.get(output_limits, channel_name), command_multipliers, channel_name, ch_num, relative_or_absolute)
            acc2 ++ [ch_config]
          end
        end)
      Map.put(acc, cs, all_channels_config)
    end)
  end

  @spec get_channel_config(map(), map(), atom(), integer(), atom()) :: tuple()
  def get_channel_config(limits, multipliers, channel_name, channel_number, rel_abs) do
    {channel_number, channel_name, rel_abs, limits.min, limits.mid, limits.max, Map.get(multipliers, channel_name)}
  end

  def all_commands_and_related_actuators() do
      %{
        rollrate: :aileron,
        pitchrate: :elevator,
        yawrate: :rudder,
        thrust: :throttle,
        roll: :aileron,
        pitch: :elevator,
        yaw: :rudder,
        yaw_offset: :rudder,
        course_flight: :aileron,
        course_ground: :rudder,
        altitude: :elevator,
        speed: :throttle,
        aileron: :aileron,
        elevator: :elevator,
        throttle: :throttle,
        rudder: :rudder,
        flaps: :flaps,
        gear: :gear,
        brake: :brake
      }
  end

  @spec get_commands() :: list()
  def get_commands() do
    Enum.map(all_commands_and_related_actuators(), fn {command, _actuation} -> command end)
    |> List.delete(:yaw_offset)
    |> List.delete(:brake)
  end


  @spec get_command_multipliers(binary) :: map()
  def get_command_multipliers(model_type) do
    reversed_actuators = apply(Module.concat(Configuration.Vehicle.Plane.Actuation, model_type), :get_reversed_actuators, [])
    Enum.reduce(all_commands_and_related_actuators(), %{}, fn ({command, actuator}, acc) ->
      if Enum.member?(reversed_actuators, actuator) do
        Map.put(acc, command, -1)
      else
        Map.put(acc, command, 1)
      end
    end)
  end
end
