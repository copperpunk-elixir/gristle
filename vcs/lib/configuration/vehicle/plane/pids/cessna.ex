defmodule Configuration.Vehicle.Plane.Pids.Cessna do
  require Logger
  require Common.Constants

  @spec get_pids() :: list()
  def get_pids() do
    constraints = get_constraints()
    integrator_airspeed_min = 5.0
    [
      rollrate: [aileron: Keyword.merge([type: :Generic, kp: 0.3, ki: 1.0, integrator_range: 0.26, integrator_airspeed_min: integrator_airspeed_min, ff: get_feed_forward(:rollrate, :aileron)], constraints[:aileron])],
      pitchrate: [elevator: Keyword.merge([type: :Generic, kp: 0.3, ki: 1.0, integrator_range: 0.26, integrator_airspeed_min: integrator_airspeed_min, ff: get_feed_forward(:pitchrate, :elevator)], constraints[:elevator])],
      yawrate: [rudder: Keyword.merge([type: :Generic, kp: 0.3, ki: 0.0, integrator_range: 0.26, integrator_airspeed_min: integrator_airspeed_min, ff: get_feed_forward(:yawrate, :rudder)], constraints[:rudder])],
      course_tilt: [roll: Keyword.merge([type: :Generic, kp: 0.0, ki: 0.0, integrator_range: 0.052,  integrator_airspeed_min: integrator_airspeed_min, ff: get_feed_forward(:course_tilt, :roll)], constraints[:roll])],
      course_rotate: [yaw: Keyword.merge([type: :Generic, kp: 1.0, ki: 0.1, integrator_range: 0.0104, integrator_airspeed_min: integrator_airspeed_min], constraints[:yaw])],
      tecs: [
        thrust: Keyword.merge(get_tecs_energy(), constraints[:thrust]),
        pitch: Keyword.merge(get_tecs_balance(), constraints[:pitch])
      ]
    ]
  end

  @spec get_attitude() :: list
  def get_attitude() do
    constraints = get_constraints()
    [
      roll_rollrate: Keyword.merge([scale: 2.0], constraints[:rollrate]),
      pitch_pitchrate: Keyword.merge([scale: 2.0], constraints[:pitchrate]),
      yaw_yawrate: Keyword.merge([scale: 2.0], constraints[:yawrate]),
    ]
  end

  @spec get_constraints() :: list()
  def get_constraints() do
    [
      aileron: [output_min: 0, output_max: 1.0, output_neutral: 0.5],
      elevator: [output_min: 0, output_max: 1.0, output_neutral: 0.5],
      rudder: [output_min: 0, output_max: 1.0, output_neutral: 0.5],
      throttle: [output_min: 0, output_max: 1.0, output_neutral: 0, output_mid: 0.5],
      flaps: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5],
      gear: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5],
      rollrate: [output_min: -1.57, output_max: 1.57, output_neutral: 0],
      pitchrate: [output_min: -1.57, output_max: 1.57, output_neutral: 0],
      yawrate: [output_min: -1.57, output_max: 1.57, output_neutral: 0],
      roll: [output_min: -0.78, output_max: 0.78, output_neutral: 0.0],
      pitch: [output_min: -0.52, output_max: 0.52, output_neutral: 0.0],
      yaw: [output_min: -0.78, output_max: 0.78, output_neutral: 0.0],
      thrust: [output_min: 0, output_max: 1, output_neutral: 0.0, output_mid: 0.5],
      course_rotate: [output_min: -0.52, output_max: 0.52, output_neutral: 0],
      course_tilt: [output_min: -0.52, output_max: 0.52, output_neutral: 0],
      speed: [output_min: 0, output_max: 55, output_neutral: 0, output_mid: 27.5],
      altitude: [output_min: -10, output_max: 10, output_neutral: 0]
    ]
  end

  @spec get_tecs_energy() :: list()
  def get_tecs_energy() do
    [type: :TecsEnergy,
      ki: 0.1,
      kd: 0,
      altitude_kp: 1.0,
      energy_rate_scalar: 0.002,
      integrator_range: 300,
      ff: get_feed_forward(:tecs, :thrust)]
  end

  @spec get_tecs_balance() :: list()
  def get_tecs_balance() do
    [type: :TecsBalance,
     ki: 0.1,
     kd: 0.0,
     altitude_kp: 0.25,
     balance_rate_scalar: 0.2,
     time_constant: 2.0,
     integrator_range: 0.4,
     integrator_factor: 5.0,
      min_climb_speed: 30
    ]
    end

  @spec get_feed_forward(atom(), atom()) :: function()
  def get_feed_forward(pv, cv) do
    ff_list =
      [
        rollrate: [
          aileron:
          fn(cmd, _value, _airspeed) ->
            0.5*cmd/1.57
          end
        ],
        pitchrate: [
          elevator:
          fn (cmd, _value, _airspeed) ->
            0.5*cmd/1.57
          end
        ],
        yawrate: [
          rudder:
          fn(cmd, _value, _airspeed) ->
            0.5*cmd/1.57
          end
        ],
        course_tilt: [
          roll:
          fn (cmd, _value, airspeed) ->

            airspeed = max(airspeed, 5)
            # Logger.debug("ff cmd/as/output: #{Common.Utils.Math.rad2deg(cmd)}/#{airspeed}/#{Common.Utils.Math.rad2deg(:math.atan(cmd*airspeed/Common.Constants.gravity()))}")
            # TODO - Add logic for low-speed flight. We would want more control authority, not less.
            :math.atan(0.5*cmd*airspeed/Common.Constants.gravity)
          end
        ],
        tecs: [
          thrust:
          fn (cmd, _value, speed_cmd) ->
            if (speed_cmd > 0), do: cmd*0.001 + 0.5, else: 0.0
          end
        ]
      ]
    get_in(ff_list,[pv, cv])
   end
end
