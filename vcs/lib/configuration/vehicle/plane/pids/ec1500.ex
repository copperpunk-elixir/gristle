defmodule Configuration.Vehicle.Plane.Pids.EC1500 do
  require Logger

  @spec get_pids() :: map()
  def get_pids() do
    constraints = get_constraints()

    pids = %{
      rollrate: %{aileron: Map.merge(%{kp: 0.2, ki: 0.0, kd: 0.0, ff: get_feed_forward(:rollrate, :aileron)}, constraints.aileron)},
      pitchrate: %{elevator: Map.merge(%{kp: 0.1, ki: 0.005, kd: 0.0, ff: get_feed_forward(:pitchrate, :elevator)}, constraints.elevator)},
      yawrate: %{rudder: Map.merge(%{kp: 0.1, ki: 0.0, kd: 0.0, ff: get_feed_forward(:yawrate, :rudder)}, constraints.rudder)},
      thrust: %{throttle: Map.merge(%{kp: 1.0}, constraints.throttle)},
      roll: %{rollrate: Map.merge(%{kp: 2.0, kd: 0*0.025}, constraints.rollrate)},
      pitch: %{pitchrate: Map.merge(%{kp: 3.0, kd: 0*0.025}, constraints.pitchrate)},
      yaw: %{yawrate: Map.merge(%{kp: 2.0, kd: 0.00}, constraints.yawrate)},
      course_flight: %{roll: Map.merge(%{kp: 0.0, ki: 0.0, kd: 0.0, ff: get_feed_forward(:course_flight, :roll)}, constraints.roll),
                       yaw: Map.merge(%{kp: 0.1}, constraints.yaw)},
      course_ground: %{roll: Map.merge(%{kp: 0.0}, constraints.roll),
                       yaw: Map.merge(%{kp: 1.0, ki: 0.1,ff: get_feed_forward(:course_ground, :yaw)}, constraints.yaw)},
      speed: %{thrust: Map.merge(%{kp: 0.15, ki: 0.01, weight: 1.0}, constraints.thrust)},
      altitude: %{pitch: Map.merge(%{kp: 0.030, ki: 0.001, kd: 0, weight: 1.0}, constraints.pitch)}
    }

    Configuration.Module.Pids.add_pid_input_constraints(pids, constraints)
  end

  @spec get_constraints() :: map()
  def get_constraints() do
    %{
      aileron: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      elevator: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      rudder: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      throttle: %{output_min: 0, output_max: 1.0, output_neutral: 0},
      rollrate: %{output_min: -2.0, output_max: 2.0, output_neutral: 0},
      pitchrate: %{output_min: -1.57, output_max: 1.57, output_neutral: 0},
      yawrate: %{output_min: -1.57, output_max: 1.57, output_neutral: 0},
      roll: %{output_min: -0.78, output_max: 0.78, output_neutral: 0.0},
      pitch: %{output_min: -0.78, output_max: 0.78, output_neutral: 0},
      yaw: %{output_min: -0.52, output_max: 0.52, output_neutral: 0.0},
      thrust: %{output_min: -1, output_max: 1, output_neutral: 0.0},
      course_ground: %{output_min: -0.52, output_max: 0.52, output_neutral: 0},
      course_flight: %{output_min: -0.52, output_max: 0.52, output_neutral: 0},
      speed: %{output_min: -10, output_max: 10, output_neutral: 0},
      altitude: %{output_min: -10, output_max: 10, output_neutral: 0},
    }
  end

  @spec get_feed_forward(atom(), atom()) :: function()
  def get_feed_forward(pv, cv) do
    ff_map =
      %{
        rollrate: %{
          aileron:
          fn(cmd, _value, _airspeed) ->
            0.5*cmd/2.0
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
        course_ground: %{
          yaw:
          fn(cmd, _value, _airspeed) ->
            cmd
          end
        }
      }
    get_in(ff_map,[pv, cv])
 end
end
