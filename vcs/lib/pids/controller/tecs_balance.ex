defmodule Pids.Controller.TecsBalance do
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
        # altitude_kp: Map.get(config, :altitude_kp, 0),
        time_constant: Map.get(config, :tc, 1.0),
        balance_rate_scalar: config.balance_rate_scalar,
        min_climb_speed: config.min_climb_speed,
        max_climb_rate: config.max_climb_rate,
        output_min: config.output_min,
        output_max: config.output_max,
        output_neutral: config.output_neutral,
        integrator_range_min: -Map.get(config, :integrator_range, 0),
        integrator_range_max: Map.get(config, :integrator_range, 0),
        pv_integrator: 0,
        pv_correction_prev: 0,
        output: config.output_neutral
     }}

  end

  @spec update(map(), map(), float(), float(), map()) :: map()
  def update(cmds, values, _airspeed, dt, state) do
    alt_rate_sp = Common.Utils.Math.constrain(cmds.altitude_corr, -state.max_climb_rate, state.max_climb_rate)
    # Logger.debug("alt_rate_sp: #{Common.Utils.eftb(alt_rate_sp,2)}")
    # Logger.debug("KE_w/PE_w: #{ke_weighting}/#{pe_weighting}")
    potential_energy_rate = values.potential_energy_rate
    potential_energy_rate_sp = alt_rate_sp*Common.Constants.gravity()

    potential_energy = values.potential_energy
    potential_energy_sp = values.potential_energy + potential_energy_rate_sp*dt

    balance_corr = potential_energy_sp - potential_energy
    balance_rate_cmd = potential_energy_rate_sp
    balance_rate_corr = balance_rate_cmd - potential_energy_rate
    # Logger.debug("pe_sp/pe/ke_sp/ke: #{Common.Utils.eftb(potential_energy_sp,3)}/#{Common.Utils.eftb(potential_energy,3)}/#{Common.Utils.eftb(kinetic_energy_sp,3)}/#{Common.Utils.eftb(kinetic_energy, 3)}")
    # Logger.debug("rate: pe_sp/pe/ke_sp/ke: #{Common.Utils.eftb(potential_energy_rate_sp,3)}/#{Common.Utils.eftb(potential_energy_rate,3)}/#{Common.Utils.eftb(kinetic_energy_rate_sp,3)}/#{Common.Utils.eftb(kinetic_energy_rate, 3)}")

    # Proportional
    cmd_p = balance_corr
    # Integrator
    in_range = Common.Utils.Math.in_range?(balance_corr, state.integrator_range_min, state.integrator_range_max)
    pv_integrator =
    if in_range do
      pv_add = balance_corr*dt
      state.pv_integrator + pv_add
    else
      0.0
    end

    cmd_i = state.ki*pv_integrator
    |> Common.Utils.Math.constrain(state.output_min, state.output_max)

    # Derivative
    cmd_d = balance_rate_corr*state.kd

    cmd_rate = 0#balance_rate_cmd*state.time_constant

    output = (cmd_p + cmd_i + cmd_d + cmd_rate) / state.time_constant * state.balance_rate_scalar
    |> Common.Utils.Math.constrain(state.output_min, state.output_max)

    # Logger.debug("p/i/d/rate/total: #{Common.Utils.eftb(cmd_p,3)}/#{Common.Utils.eftb(cmd_i,3)}/#{Common.Utils.eftb(cmd_d, 3)}/#{Common.Utils.eftb(cmd_rate,3)}/#{Common.Utils.eftb(output, 3)}")

    %{state | output: output}
  end
end
