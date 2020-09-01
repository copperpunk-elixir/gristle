defmodule Configuration.Vehicle.Plane.Pids.Cessna do
  require Logger

  @spec get_pids() :: map()
  def get_pids() do
    constraints = get_constraints()

    %{
      rollrate: %{aileron: Map.merge(%{type: :Generic, kp: 0.6, ki: 1.0, integrator_range: 0.26, ff: get_feed_forward(:rollrate, :aileron)}, constraints.aileron)},
      pitchrate: %{elevator: Map.merge(%{type: :Generic, kp: 0.6, ki: 1.0, integrator_range: 0.26, ff: get_feed_forward(:pitchrate, :elevator)}, constraints.elevator)},
      yawrate: %{rudder: Map.merge(%{type: :Generic, kp: 0.3, ki: 0.0, integrator_range: 0.26, ff: get_feed_forward(:yawrate, :rudder)}, constraints.rudder)},
      course_flight: %{roll: Map.merge(%{type: :Generic, kp: 0.0, ki: 0.0, ff: get_feed_forward(:course_flight, :roll)}, constraints.roll)},
      course_ground: %{yaw: Map.merge(%{type: :Generic, kp: 1.0, ki: 0.1}, constraints.yaw)},
      tecs: %{
        thrust: Map.merge(%{type: :TecsEnergy, kp: 0.001, ki: 0.01, kd: 0, integrator_range: 100, ff: get_feed_forward(:tecs, :thrust)}, constraints.thrust),
        pitch: Map.merge(%{type: :TecsBalance, kp: 0.001, ki: 0.01, kd: 0, balance_rate_scalar: 0.001}, constraints.pitch)
      }
    }

  end

  @spec get_attitude() :: map
  def get_attitude() do
    constraints = get_constraints()
    %{
      roll_rollrate: Map.merge(%{scale: 2.0}, constraints.rollrate),
      pitch_pitchrate: Map.merge(%{scale: 2.0}, constraints.pitchrate),
      yaw_yawrate: Map.merge(%{scale: 2.0}, constraints.yawrate),
    }
  end

  @spec get_constraints() :: map()
  def get_constraints() do
    %{
      aileron: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      elevator: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      rudder: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      throttle: %{output_min: 0, output_max: 1.0, output_neutral: 0},
      rollrate: %{output_min: -1.57, output_max: 1.57, output_neutral: 0},
      pitchrate: %{output_min: -1.57, output_max: 1.57, output_neutral: 0},
      yawrate: %{output_min: -1.57, output_max: 1.57, output_neutral: 0},
      roll: %{output_min: -0.78, output_max: 0.78, output_neutral: 0.0},
      pitch: %{output_min: -0.78, output_max: 0.78, output_neutral: 0.0},
      yaw: %{output_min: -0.78, output_max: 0.78, output_neutral: 0.0},
      thrust: %{output_min: 0, output_max: 1, output_neutral: 0.0},
      course_ground: %{output_min: -0.52, output_max: 0.52, output_neutral: 0},
      course_flight: %{output_min: -0.52, output_max: 0.52, output_neutral: 0},
      speed: %{output_min: 0, output_max: 55, output_neutral: 0},
      altitude: %{output_min: -10, output_max: 10, output_neutral: 0}
    }
  end

  @spec get_feed_forward(atom(), atom()) :: function()
  def get_feed_forward(pv, cv) do
    ff_map =
      %{
        rollrate: %{
          aileron:
          fn(cmd, _value, _airspeed) ->
            0.5*cmd/1.57
          end
        },
        pitchrate: %{
          elevator:
          fn (cmd, _value, _airspeed) ->
            0.5*cmd/1.57
          end
        },
        yawrate: %{
          rudder:
          fn(cmd, _value, _airspeed) ->
            0.5*cmd/1.57
          end
        },
        course_flight: %{
          roll:
          fn (cmd, _value, airspeed) ->
            # Logger.debug("ff cmd/as/output: #{Common.Utils.Math.rad2deg(cmd)}/#{airspeed}/#{Common.Utils.Math.rad2deg(:math.atan(cmd*airspeed/Common.Constants.gravity()))}")
            :math.atan(0.5*cmd*airspeed/Common.Constants.gravity())
          end
        },
        tecs: %{
          thrust:
          fn (cmd, _value, speed_cmd) ->
            if (speed_cmd > 0), do: cmd*0.001 + 0.5, else: 0.0
          end
        }
      }
    get_in(ff_map,[pv, cv])
   end
end
