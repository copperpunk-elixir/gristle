defmodule Configuration.Vehicle.Multirotor.Pids.QuadX do
  require Logger

  @spec get_pids() :: list()
  def get_pids() do
    constraints = get_constraints()
    integrator_airspeed_min = 5.0
    [
      rollrate: [aileron: Keyword.merge([type: :Generic, kp: 0.04, ki: 0.0, integrator_range: 0.26, integrator_airspeed_min: integrator_airspeed_min, ff: get_feed_forward(:rollrate, :aileron)], constraints[:aileron])],
      pitchrate: [elevator: Keyword.merge([type: :Generic, kp: 0.04, ki: 0.0, integrator_range: 0.26, integrator_airspeed_min: integrator_airspeed_min, ff: get_feed_forward(:pitchrate, :elevator)], constraints[:elevator])],
      yawrate: [rudder: Keyword.merge([type: :Generic, kp: 1.0, ki: 0.0, integrator_range: 0.26, integrator_airspeed_min: integrator_airspeed_min, ff: get_feed_forward(:yawrate, :rudder)], constraints[:rudder])],
      course_flight: [roll: Keyword.merge([type: :Generic, kp: 0.25, ki: 0.0, integrator_range: 0.052,  integrator_airspeed_min: integrator_airspeed_min, ff: get_feed_forward(:course_flight, :roll)], constraints[:roll])],
      course_ground: [yaw: Keyword.merge([type: :Generic, kp: 0.3, ki: 0.1, integrator_range: 0.0104, integrator_airspeed_min: integrator_airspeed_min], constraints[:yaw])],
      tecs: [
        thrust: Keyword.merge(get_tecs_energy(), constraints[:thrust]),
        pitch: Keyword.merge(get_tecs_balance(), constraints[:pitch])
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
      roll_rollrate: Keyword.merge([scale: 1.0], constraints[:rollrate]),
      pitch_pitchrate: Keyword.merge([scale: 1.0], constraints[:pitchrate]),
      yaw_yawrate: Keyword.merge([scale: 1.0], constraints[:yawrate]),
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
      rollrate: [output_min: -3.0, output_max: 3.0, output_neutral: 0],
      pitchrate: [output_min: -3.0, output_max: 3.0, output_neutral: 0],
      yawrate: [output_min: -1.57, output_max: 1.57, output_neutral: 0],
      roll: [output_min: -0.78, output_max: 0.78, output_neutral: 0.0],
      pitch: [output_min: -0.78, output_max: 0.52, output_neutral: 0.0],
      yaw: [output_min: -0.78, output_max: 0.78, output_neutral: 0.0],
      thrust: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5],
      course_ground: [output_min: -0.52, output_max: 0.52, output_neutral: 0],
      course_flight: [output_min: -0.52, output_max: 0.52, output_neutral: 0],
      speed: [output_min: 0, output_max: 20, output_neutral: 0, output_mid: 10.0],
      altitude: [output_min: -10, output_max: 10, output_neutral: 0]
    ]
  end

  @spec get_tecs_energy() :: list()
  def get_tecs_energy() do
    [type: :TecsEnergy,
     ki: 0.25,
     kd: 0,
     altitude_kp: 1.0,
     energy_rate_scalar: 0.004,
     integrator_range: 100,
     ff: get_feed_forward(:tecs, :thrust)]
  end

  @spec get_tecs_balance() :: list()
  def get_tecs_balance() do
    [type: :TecsBalance,
     ki: 0.1,
     kd: 0.0,
     altitude_kp: 0.75,
     balance_rate_scalar: 0.5,
     time_constant: 2.0,
     integrator_range: 0.4,
     integrator_factor: 5.0,
     min_climb_speed: 10
    ]
  end

  @spec get_feed_forward(atom(), atom()) :: function()
  def get_feed_forward(pv, cv) do
    ff_list =
      [
        rollrate: [
          aileron:
          fn(cmd, _value, _airspeed) ->
            0.5*cmd/15.0
          end
        ],
        pitchrate: [
          elevator:
          fn (cmd, _value, _airspeed) ->
            0.5*cmd/15.0
          end
        ],
        yawrate: [
          rudder:
          fn(cmd, _value, _airspeed) ->
            0.5*cmd/1.57
          end
        ],
        course_flight: [
          roll:
          fn (cmd, _value, airspeed) ->
            # Logger.debug("ff cmd/as/output: #{Common.Utils.Math.rad2deg(cmd)]/#{airspeed]/#{Common.Utils.Math.rad2deg(:math.atan(cmd*airspeed/Common.Constants.gravity()))}")
            :math.atan(0.5*cmd*airspeed/Common.Constants.gravity())
          end
        ],
        tecs: [
          thrust:
          fn (_cmd, _value, speed_cmd) ->
            if (speed_cmd > 0), do: speed_cmd*speed_cmd/400.0, else: 0.0
          end
        ]
      ]
    get_in(ff_list,[pv, cv])
 end
end