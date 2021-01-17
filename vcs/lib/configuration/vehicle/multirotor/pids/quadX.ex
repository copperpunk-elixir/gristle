defmodule Configuration.Vehicle.Multirotor.Pids.QuadX do
  require Logger

  @spec get_pids() :: list()
  def get_pids() do
    constraints = get_constraints()
    integrator_airspeed_min = 5.0
    rate_integrator_airspeed_min = -1.0
    [
      rollrate: [aileron: Keyword.merge([type: :Generic, kp: 0.020, ki: 0.01, kd: 0.00010, integrator_range: 6.3, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:rollrate, :aileron)], constraints[:aileron])],
      pitchrate: [elevator: Keyword.merge([type: :Generic, kp: 0.020, ki: 0.01, kd: 0.00010, integrator_range: 6.3, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:pitchrate, :elevator)], constraints[:elevator])],
      yawrate: [rudder: Keyword.merge([type: :Generic, kp: 1.00, ki: 0.02, kd: 0.0001, integrator_range: 3.1, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:yawrate, :rudder)], constraints[:rudder])],
      # course_flight: [roll: Keyword.merge([type: :Generic, kp: 0.25, ki: 0.0, integrator_range: 0.052,  integrator_airspeed_min: integrator_airspeed_min, ff: get_feed_forward(:course_flight, :roll)], constraints[:roll])],
      # course_ground: [yaw: Keyword.merge([type: :Generic, kp: 0.3, ki: 0.1, integrator_range: 0.0104, integrator_airspeed_min: integrator_airspeed_min], constraints[:yaw])],
      tecs: [
        thrust: Keyword.merge([type: :Generic, kp: 0.007, ki: 0.001, kd: 0*0.010, integrator_range: 5, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:tecs, :thrust)], constraints[:thrust]),
        tilt: Keyword.merge([type: :Generic, kp: 0.03, ki: 0*0.01, kd: 0.00010, integrator_range: 6.3, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:tecs, :tilt)], constraints[:pitch])
      ]
    ]
  end

  @spec get_motor_moments() :: map()
  def get_motor_moments() do
    # Resulting moments from increasing thrust for Roll,Pitch,Yaw
    # Values should be relative to moment arm, i.e., a symmetrical quad can
    # use 1's, but if the arms are different lengths/locations, the values should
    # be adjusted accordingly
    # 3  1
    # 2  4
    %{
      motor1: {-1, 1, 1},
      motor2: {1, -1, 1},
      motor3: {1, 1, -1},
      motor4: {-1, -1, -1}
    }
  end

  @spec get_attitude() :: list
  def get_attitude() do
    constraints = get_constraints()
    [
      roll_rollrate: Keyword.merge([scale: 4.0], constraints[:rollrate]),
      pitch_pitchrate: Keyword.merge([scale: 4.0], constraints[:pitchrate]),
      yaw_yawrate: Keyword.merge([scale: 2.0], constraints[:yawrate]),
    ]
  end

  @spec get_constraints() :: list()
  def get_constraints() do
    [
      aileron: [output_min: -1.0, output_max: 1.0, output_neutral: 0.0],
      elevator: [output_min: -1.0, output_max: 1.0, output_neutral: 0.0],
      rudder: [output_min: -1.0, output_max: 1.0, output_neutral: 0.0],
      throttle: [output_min: 0, output_max: 1.0, output_neutral: 0],
      flaps: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5],
      gear: [output_min: 0, output_max: 1.0, output_neutral: 0.0],
      rollrate: [output_min: -5.0, output_max: 5.0, output_neutral: 0],
      pitchrate: [output_min: -5.0, output_max: 5.0, output_neutral: 0],
      yawrate: [output_min: -1.5, output_max: 1.5, output_neutral: 0],
      roll: [output_min: -0.52, output_max: 0.52, output_neutral: 0.0],
      pitch: [output_min: -0.35, output_max: 0.35, output_neutral: 0.0],
      yaw: [output_min: -0.78, output_max: 0.78, output_neutral: 0.0],
      thrust: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5, delta_output_min: -0.5],
      course_ground: [output_min: -0.52, output_max: 0.52, output_neutral: 0],
      course_flight: [output_min: -0.52, output_max: 0.52, output_neutral: 0],
      speed: [output_min: 0, output_max: 8, output_neutral: 0, output_mid: 5.0],
      altitude: [output_min: -10, output_max: 10, output_neutral: 0]
    ]
  end

  @spec get_feed_forward(atom(), atom()) :: function()
  def get_feed_forward(pv, cv) do
    ff_list =
      [
        rollrate: [
          aileron:
          fn(cmd, _value, _airspeed) ->
            0*0.5*cmd/10.0
          end
        ],
        pitchrate: [
          elevator:
          fn (cmd, _value, _airspeed) ->
            0*0.5*cmd/80.0
          end
        ],
        yawrate: [
          rudder:
          fn(cmd, _value, _airspeed) ->
            0*0.5*cmd/7.3
          end
        ],
        # course_flight: [
        #   roll:
        #   fn (cmd, _value, airspeed) ->
        #     # Logger.debug("ff cmd/as/output: #{Common.Utils.Math.rad2deg(cmd)]/#{airspeed]/#{Common.Utils.Math.rad2deg(:math.atan(cmd*airspeed/Common.Constants.gravity()))}")
        #     :math.atan(0.5*cmd*airspeed/Common.Constants.gravity())
        #   end
        # ],
        tecs: [
          thrust:
          fn (cmd, _value, speed_cmd) ->
            cond do
              Pids.Tecs.Arm.get(:takeoff) -> 0.5
              Pids.Tecs.Arm.get(:armed) -> 0.1
              true -> 0
            end
            # if (cmd > 0), do: 0*cmd/10.0, else: 0.0
          end,
          tilt:
          fn (cmd, _value, _speed_cmd) ->
            if (cmd > 0), do: 0.30*cmd*cmd/64.0, else: 0.0
          end
        ]
      ]
    get_in(ff_list,[pv, cv])
 end
end
