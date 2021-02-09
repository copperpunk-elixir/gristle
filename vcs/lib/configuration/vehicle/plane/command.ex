defmodule Configuration.Vehicle.Plane.Command do
  require Logger
  require Command.Utils, as: CU

  @spec get_relative_channels() :: list()
  def get_relative_channels() do
    [:course_tilt, :altitude]
  end

  @spec get_actuation_channel_assignments() :: map()
  def get_actuation_channel_assignments() do
    %{
      0 => [:aileron, :rollrate, :roll, :course_tilt],
      1 => [:elevator, :pitchrate, :pitch, :altitude],
      2 => [:throttle, :thrust, :speed],
      3 => [:rudder, :yawrate, :yaw, :course_rotate],
      4 => [:flaps],
      5 => [:gear],
      # 7 => [:select]
    }
  end

  @spec get_command_channel_assignments() :: map()
  def get_command_channel_assignments() do
    %{
      CU.cs_rates => [:rollrate, :pitchrate, :yawrate, :thrust],
      CU.cs_attitude => [:roll, :pitch, :yaw, :thrust],
      CU.cs_sca => [:course_tilt, :speed, :altitude, :course_rotate],
      # Manual only channels
      CU.cs_direct_manual => [:aileron, :elevator, :rudder, :throttle],
      # Manual and Semi-Auto channels
      CU.cs_direct_semi_auto => [:flaps, :gear],
      # Auto only channels
      CU.cs_direct_auto => []
    }
  end

  def get_all_commands_and_related_actuators() do
      %{
        rollrate: :aileron,
        pitchrate: :elevator,
        yawrate: :rudder,
        thrust: :throttle,
        roll: :aileron,
        pitch: :elevator,
        yaw: :rudder,
        yaw_offset: :rudder,
        course_tilt: :aileron,
        course_rotate: :rudder,
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
    Enum.map(get_all_commands_and_related_actuators(), fn {command, _actuation} -> command end)
    |> List.delete(:yaw_offset)
    |> List.delete(:brake)
  end
end
