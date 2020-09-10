defmodule Pids.Controller.TecsEnergy do
  require Logger

  @spec init(map()) :: tuple()
  def init(config) do
    {process_variable, control_variable} = Map.get(config, :name)
    {:ok, %{
        pid_module: __MODULE__,
        process_variable: process_variable,
        control_variable: control_variable,
        ki: Map.get(config, :ki, 0),
        kd: Map.get(config, :kd, 0),
        ff: Map.get(config, :ff, nil),
        altitude_kp: Map.get(config, :altitude_kp, 0),
        time_constant: Map.get(config, :tc, 1.0),
        energy_rate_scalar: config.energy_rate_scalar,
        output_min: config.output_min,
        output_max: config.output_max,
        integrator_range_min: -Map.get(config, :integrator_range, 0),
        integrator_range_max: Map.get(config, :integrator_range, 0),
        pv_integrator: 0,
        pv_correction_prev: 0,
        speed_prev: nil,
        output: config.output_neutral
     }}

  end

  @spec update(map(), map(), float(), float(), map()) :: map()
  def update(cmds, values, _airspeed, dt, state) do
    speed = values.speed
    energy_rate_scalar = state.energy_rate_scalar

    speed_dot =
    if is_nil(state.speed_prev) do
      0
    else
      (speed - state.speed_prev)/dt
    end

    altitude_corr = cmds.altitude_corr
    alt_rate = altitude_corr*state.altitude_kp
    potential_energy_rate_sp = alt_rate*Common.Constants.gravity()

    kinetic_energy_rate = speed*speed_dot
    energy_rate = kinetic_energy_rate + values.potential_energy_rate

    kinetic_energy_rate_sp = cmds.kinetic_energy_rate
    energy_rate_sp = kinetic_energy_rate_sp + potential_energy_rate_sp

    energy_corr = cmds.energy - values.energy
    energy_rate_corr = energy_rate_sp - energy_rate
    # Logger.debug("e/e_sp/edot/edot_sp: #{Common.Utils.eftb(values.energy,3)}/#{Common.Utils.eftb(cmds.energy,3)}/#{Common.Utils.eftb(energy_rate,3)}/#{Common.Utils.eftb(energy_rate_sp, 3)}")

    cmd_p = energy_corr*energy_rate_scalar

    in_range = Common.Utils.Math.in_range?(energy_corr, state.integrator_range_min, state.integrator_range_max)
    pv_integrator =
    if in_range do
      pv_add = energy_corr*dt
      state.pv_integrator + pv_add*energy_rate_scalar
    else
      0.0
    end

    cmd_i = state.ki*pv_integrator

    cmd_d = energy_rate_corr*state.kd*energy_rate_scalar

    delta_output = (cmd_p + cmd_i + cmd_d) / state.time_constant
    feed_forward =
      case Map.get(state, :ff) do
        nil -> 0
        f ->
          f.(energy_rate_sp, energy_rate, cmds.speed)
          |> Common.Utils.Math.constrain(state.output_min, state.output_max)
      end

    output = feed_forward + delta_output
    |> Common.Utils.Math.constrain(state.output_min, state.output_max)

    # Prevent integrator wind-up
    pv_integrator =
    if (state.ki > 0) do
      # Logger.debug("pv_int: #{pv_integrator}/ #{cmd_i/state.ki}")
      Common.Utils.Math.constrain(cmd_i/state.ki, state.output_min, state.output_max)
    else
      0.0
    end

    # Logger.debug("p/i/d/ff/total: #{Common.Utils.eftb(cmd_p,3)}/#{Common.Utils.eftb(cmd_i,3)}/#{Common.Utils.eftb(cmd_d, 3)}/#{Common.Utils.eftb(feed_forward,3)}/#{Common.Utils.eftb(output, 3)}")
    %{state | output: output, speed_prev: speed, pv_correction_prev: energy_corr, pv_integrator: pv_integrator}

  end
end