defmodule Configuration.Vehicle.Car.Command do
  require Logger
  require Command.Utils, as: CU

  @spec get_relative_channels() :: list()
  def get_relative_channels() do
    [:course_ground]
  end

  @spec get_actuation_channel_assignments() :: map()
  def get_actuation_channel_assignments() do
    %{
      0 => [:rudder, :yawrate, :yaw, :course_ground],
      1 => [:brake],
      2 => [:throttle, :thrust, :speed],
      # 7 => [:select]
    }
  end

  @spec get_command_channel_assignments() :: map()
  def get_command_channel_assignments() do
    %{
      CU.cs_rates => [:yawrate, :thrust, :brake],
      CU.cs_attitude => [:yaw, :thrust, :brake],
      CU.cs_sca => [:course_ground, :speed],
      # Manual only channels
      CU.cs_direct_manual => [:rudder, :throttle, :brake],
      # Manual and Semi-Auto channels
      CU.cs_direct_semi_auto => [],
      # Auto only channels
      CU.cs_direct_auto => []
    }
  end

  def get_all_commands_and_related_actuators() do
      %{
        yawrate: :rudder,
        thrust: :throttle,
        yaw: :rudder,
        course_ground: :rudder,
        speed: :throttle,
        throttle: :throttle,
        rudder: :rudder,
        brake: :brake
      }
  end

  @spec get_commands() :: list()
  def get_commands() do
    Enum.map(get_all_commands_and_related_actuators(), fn {command, _actuation} -> command end)
  end
end
