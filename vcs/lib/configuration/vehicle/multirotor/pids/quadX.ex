defmodule Configuration.Vehicle.Multirotor.Pids.QuadX do
  require Logger

  @spec get_pids() :: list()
  def get_pids() do
    constraints = get_constraints()
    # integrator_airspeed_min = 5.0
    rate_integrator_airspeed_min = 0.5
    [
      rollrate: [aileron: Keyword.merge([type: :Generic, kp: 0.020, ki: 0.01, kd: 0.00010, integrator_range: 6.3, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:rollrate, :aileron)], constraints[:aileron])],
      pitchrate: [elevator: Keyword.merge([type: :Generic, kp: 0.020, ki: 0.01, kd: 0.00010, integrator_range: 6.3, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:pitchrate, :elevator)], constraints[:elevator])],
      yawrate: [rudder: Keyword.merge([type: :Generic, kp: 0.5, ki: 0.02, kd: 0.0001, integrator_range: 3.15, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:yawrate, :rudder)], constraints[:rudder])],
      course: [
        pitch: Keyword.merge([type: :Generic, kp: 0.1, ki: 0.01, kd: 0.00010, integrator_range: 0.78, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:tecs, :pitch)], constraints[:pitch]),
        roll: Keyword.merge([type: :Generic, kp: 0.1, ki: 0.01, kd: 0.00010, integrator_range: 0.78, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:tecs, :roll)], constraints[:roll])
      ],
      tecs: [
        thrust: Keyword.merge([type: :Generic, kp: 0.007, ki: 0.001, kd: 0*0.010, integrator_range: 25, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:tecs, :thrust)], constraints[:thrust])
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
      rudder: [output_min: -1.0, output_max: 1.0, output_neutral: 0.0, delta_output_min: -0.05, delta_output_max: 0.05],
      throttle: [output_min: 0, output_max: 1.0, output_neutral: 0],
      flaps: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5],
      gear: [output_min: 0, output_max: 1.0, output_neutral: 0.0],
      rollrate: [output_min: -5.0, output_max: 5.0, output_neutral: 0],
      pitchrate: [output_min: -5.0, output_max: 5.0, output_neutral: 0],
      yawrate: [output_min: -1.5, output_max: 1.5, output_neutral: 0],
      roll: [output_min: -0.52, output_max: 0.52, output_neutral: 0.0],
      pitch: [output_min: -0.38, output_max: 0.38, output_neutral: 0.0],
      yaw: [output_min: -0.52, output_max: 0.52, output_neutral: 0.0],
      # yaw_offset: [output_min: -:math.pi(), output_max: :math.pi(), output_neutral: 0.0],
      thrust: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5, delta_output_min: -0.01, delta_output_max: 0.01],
      course_rotate: [output_min: -3.14, output_max: 3.14, output_neutral: 0],
      course_tilt: [output_min: -0.52, output_max: 0.52, output_neutral: 0],
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
        tecs: [
          thrust:
          fn (_cmd, _value, _speed_cmd) ->
            cond do
              Control.Arm.get(:takeoff) -> 0.5
              Control.Arm.get(:armed) -> 0.1
              true -> -1
            end
          end,
          pitch:
          fn (cmd, _value, _speed_cmd) ->
            if (cmd > 0), do: 0.30*cmd*cmd/64.0, else: 0.0
          end,
          roll:
          fn (cmd, _value, _speed_cmd) ->
            if (cmd > 0), do: 0.30*cmd*cmd/64.0, else: 0.0
          end
        ]
      ]
    get_in(ff_list,[pv, cv])
 end
end
