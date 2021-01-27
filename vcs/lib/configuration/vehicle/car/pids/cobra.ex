defmodule Configuration.Vehicle.Car.Pids.Cobra do
  require Logger

  @spec get_pids() :: list()
  def get_pids() do
    constraints = get_constraints()
    # integrator_airspeed_min = 5.0
    rate_integrator_airspeed_min = 0.5
    [
      yawrate: [rudder: Keyword.merge([type: :Generic, kp: 0.05, ki: 0*0.02, kd: 0*0.0001, integrator_range: 3.15, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:yawrate, :rudder)], constraints[:rudder])],
      tecs: [
        thrust: Keyword.merge([type: :Generic, kp: 0*0.007, ki: 0*0.001, kd: 0*0.010, integrator_range: 25, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:tecs, :thrust)], constraints[:thrust]),
        brake: Keyword.merge([type: :Generic, kp: 0*0.007, ki: 0*0.001, kd: 0*0.010, integrator_range: 25, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:tecs, :brake)], constraints[:brake]),
      ]
    ]
  end

  @spec get_attitude() :: list
  def get_attitude() do
    constraints = get_constraints()
    [
      yaw_yawrate: Keyword.merge([scale: 2.0], constraints[:yawrate]),
    ]
  end

  @spec get_constraints() :: list()
  def get_constraints() do
    [
      rudder: [output_min: 0.0, output_max: 1.0, output_neutral: 0.5],
      throttle: [output_min: 0, output_max: 1.0, output_neutral: 0],
      yawrate: [output_min: -3.2, output_max: 3.2, output_neutral: 0],
      yaw: [output_min: -1.04, output_max: 1.04, output_neutral: 0.0],
      thrust: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5, delta_output_min: -0.1, delta_output_max: 0.1],
      brake: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5],
      course_ground: [output_min: -1.04, output_max: 1.04, output_neutral: 0],
      speed: [output_min: 0, output_max: 20, output_neutral: 0, output_mid: 10.0],
    ]
  end

  @spec get_feed_forward(atom(), atom()) :: function()
  def get_feed_forward(pv, cv) do
    ff_list =
      [
        yawrate: [
          rudder:
          fn(cmd, _value, _airspeed) ->
            # Logger.debug("yawrate cmd: #{Common.Utils.eftb_deg(cmd,1)}")
            0.5*cmd/4.0
          end
        ],
        tecs: [
          thrust:
          fn (cmd, value, _speed_cmd) ->
            # Logger.debug("speed cmd/value: #{cmd}/#{value}/#{cmd/50}")
            cmd/50.0
          end,
          brake:
          fn (_cmd, _value, _speed_cmd) ->
            0
          end
        ]
      ]
    get_in(ff_list,[pv, cv])
 end
end
