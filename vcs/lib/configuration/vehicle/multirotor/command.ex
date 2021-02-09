defmodule Configuration.Vehicle.Multirotor.Command do
  require Logger
  require Command.Utils, as: CU

  @spec get_relative_channels() :: list()
  def get_relative_channels() do
    [:course_flight, :altitude]
  end

  @spec get_actuation_channel_assignments() :: map()
  def get_actuation_channel_assignments() do
    %{
      0 => [:rollrate, :roll, :course_flight],
      1 => [:pitchrate, :pitch, :altitude],
      2 => [:thrust, :speed],
      3 => [:yawrate, :yaw, :yaw_offset],
      4 => [:gear],
      5 => [],
      # 7 => [:select]
    }
  end

  @spec get_command_channel_assignments() :: map()
  def get_command_channel_assignments() do
    %{
      CU.cs_rates => [:rollrate, :pitchrate, :yawrate, :thrust],
      CU.cs_attitude => [:roll, :pitch, :yaw, :thrust],
      CU.cs_sca => [:course_flight, :speed, :altitude, :yaw_offset],
      # Manual only channels
      CU.cs_direct_manual => [],
      # Manual and Semi-Auto channels
      CU.cs_direct_semi_auto => [:gear],
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
      course_flight: :aileron,
      course_ground: :rudder,
      altitude: :elevator,
      speed: :throttle,
      aileron: :aileron,
      elevator: :elevator,
      throttle: :throttle,
      rudder: :rudder,
      flaps: :flaps,
      gear: :gear
    }
  end

  @spec get_commands() :: list()
  def get_commands() do
    Enum.map(get_all_commands_and_related_actuators(), fn {command, _actuation} -> command end)
    # |> List.delete(:yaw_offset)
  end

end
