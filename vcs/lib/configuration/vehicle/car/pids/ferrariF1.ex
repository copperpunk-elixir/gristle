defmodule Configuration.Vehicle.Car.Pids.FerrariF1 do
  require Logger

  @spec get_pids() :: list()
  def get_pids() do
    constraints = get_constraints()
    # integrator_airspeed_min = 5.0
    rate_integrator_airspeed_min = 0.5
    [
      yawrate: [rudder: Keyword.merge([type: :Generic, kp: 0.05, ki: 0.02, kd: 0*0.0001, integrator_range: 0.08, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:yawrate, :rudder)], constraints[:rudder])],
      tecs: [
        thrust: Keyword.merge([type: :Generic, kp: 0.05, ki: 0.004, kd: 0*0.010, integrator_range: 25, integrator_airspeed_min: rate_integrator_airspeed_min, ff: get_feed_forward(:tecs, :thrust)], constraints[:thrust]),
        brake: Keyword.merge([type: :Generic, kp: -0.1, ki: -0.1, kd: 0*0.010, integrator_range: 25, integrator_airspeed_min: 1.0, ff: get_feed_forward(:tecs, :brake)], constraints[:brake]),
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
      brake: [output_min: 0, output_max: 1.0, output_neutral: 0.0, output_mid: 0.5, delta_output_min: -0.1, delta_output_max: 0.1],
      course_ground: [output_min: -2.08, output_max: 2.08, output_neutral: 0],
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
          fn (cmd, _value, _speed_cmd) ->
            # Logger.debug("speed cmd/value: #{cmd}/#{value}/#{cmd/50}")
            :math.sqrt(cmd/20.0)
          end,
          brake:
          fn (cmd, value, _speed_cmd) ->
            # Logger.debug("speed cmd/value: #{Common}")
            cond do
              (value - cmd) > 5 ->
                Logger.debug("here1")
                Common.Utils.Math.constrain(0.1*(value-cmd), 0, 0.5)
              cmd < 1 and value < 1 ->
                Logger.debug("here2")
                1.0
              true ->
                Logger.debug("here3")
                0.0
            end
          end
        ]
      ]
    get_in(ff_list,[pv, cv])
 end
end
