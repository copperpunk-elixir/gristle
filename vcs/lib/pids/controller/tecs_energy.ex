defmodule Pids.Controller.TecsEnergy do
  require Logger

  @spec init(map()) :: tuple()
  def init(config) do
    {process_variable, control_variable} = Map.get(config, :name)
    {:ok, %{
        pid_module: __MODULE__,
        process_variable: process_variable,
        control_variable: control_variable,
        kp: Map.get(config, :kp, 0),
        ki: Map.get(config, :ki, 0),
        kd: Map.get(config, :kd, 0),
        ff: Map.get(config, :ff, nil),
        output_min: config.output_min,
        output_max: config.output_max,
        integrator_range_min: -Map.get(config, :integrator_range, 0),
        integrator_range_max: Map.get(config, :integrator_range, 0),
        pv_integrator: 0,
        pv_correction_prev: 0,
        # vv_prev: nil,
        speed_prev: nil,
        # climb_rate_max: config.climb_rate_max,
        # height_cmd_prev: nil,
        output: config.output_neutral
     }}

  end

  @spec update(map(), map(), float(), float(), map()) :: map()
  def update(pv_cmds, pv_values, _airspeed, dt, state) do
    speed = pv_values.speed
    vv = pv_values.vertical
    altitude = pv_values.altitude

    speed_dot =
    if is_nil(state.speed_prev) do
      0
    else
      (speed - state.speed_prev)/dt
    end

    # vv_dot =
    # if is_nil(state.vv_prev) do
    #   0.0
    # else
    # (pv_values.vertical - state.vv_prev)/dt
    # end

    speed_cmd = pv_cmds.speed
    alt_cmd = pv_cmds.altitude

    energy= 0.5*speed*speed + Common.Constants.gravity()*altitude
    energy_sp = 0.5*speed_cmd*speed_cmd + Common.Constants.gravity()*alt_cmd

    flight_path_angle =
    if (speed > 5.0) do
      vv/speed
    else
      0.0
    end

    speed_dot_sp = (speed_cmd - speed)/dt
    flight_path_angle_sp =
    if (speed_cmd > 1.0) do
      (alt_cmd - altitude)/speed_cmd
    else
      0.0
    end

    energy_rate = speed_dot/Common.Constants.gravity() + flight_path_angle
    energy_rate_sp = speed_dot_sp/Common.Constants.gravity() + flight_path_angle_sp

    energy_corr = energy_sp - energy
    energy_rate_corr = energy_rate_sp - energy_rate
    Logger.debug("e/e_sp/edot/edot_sp: #{Common.Utils.eftb(energy,3)}/#{Common.Utils.eftb(energy_sp,3)}/#{Common.Utils.eftb(energy_rate,3)}/#{Common.Utils.eftb(energy_rate_sp, 3)}")


    cmd_p = energy_corr*state.kp
    cmd_i = 0.0
    cmd_d = energy_rate_corr*state.kd

    delta_output = cmd_p + cmd_i + cmd_d
    feed_forward =
      case Map.get(state, :ff) do
        nil -> 0
        f ->
          f.(energy_rate_sp, energy_rate, speed_cmd)
          |> Common.Utils.Math.constrain(state.output_min, state.output_max)
      end

    output = feed_forward + delta_output
    |> Common.Utils.Math.constrain(state.output_min, state.output_max)
    Logger.debug("p/i/d/ff/total: #{Common.Utils.eftb(cmd_p,3)}/#{Common.Utils.eftb(cmd_i,3)}/#{Common.Utils.eftb(cmd_d, 3)}/#{Common.Utils.eftb(feed_forward,3)}/#{Common.Utils.eftb(output, 3)}")
    %{state | output: output, speed_prev: speed}

  end

  # @spec update_height_sp(float(), float(), float(), map()) :: map()
  # def update_height_sp(height_cmd, height, dt, state) do
  #   climb_rate_max = state.climb_rate_max
  #   height_cmd_prev = if is_nil(state.height_cmd_prev), do: height_cmd, else: state.height_cmd_prev
  #   d_cmd = height_cmd - state.height_cmd_prev
  #   climb_rate = Common.Utils.Math.constrain(d_cmd/dt, -climb_rate_max, climb_rate_max)
  #   height_cmd = height + climb_rate*dt
  #   height_rate_cmd = (height_cmd - height)*state.height_kp + state.height_ff*(height_cmd - height_cmd_prev)/dt
  #   |> Common.Utils.Math.constrain(-climb_rate_max, climb_rate_max)
  #   height_cmd_prev = height_cmd
  #   %{state | height_cmd: height_cmd, height_rate_cmd: height_rate_cmd, height_cmd_prev: height_cmd_prev}
  # end

  # @spec update_speed_sp() :: map()
  # def update_speed_sp() do
  # end
end
