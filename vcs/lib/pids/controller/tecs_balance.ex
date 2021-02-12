defmodule Pids.Controller.TecsBalance do
  require Logger
  require Common.Constants

  @spec begin(list()) :: tuple()
  def begin(config) do
    {process_variable, control_variable} = Keyword.get(config, :name)
    %{
      pid_module: __MODULE__,
      process_variable: process_variable,
      control_variable: control_variable,
      ki: Keyword.get(config, :ki, 0),
      kd: Keyword.get(config, :kd, 0),
      altitude_kp: Keyword.get(config, :altitude_kp, 0),
      time_constant: Keyword.get(config, :tc, 1.0),
      balance_rate_scalar: Keyword.fetch!(config, :balance_rate_scalar),
      min_climb_speed: Keyword.fetch!(config, :min_climb_speed),
      output_min: Keyword.fetch!(config, :output_min),
      output_max: Keyword.fetch!(config, :output_max),
      output_neutral: Keyword.fetch!(config, :output_neutral),
      integrator_range_min: -Keyword.get(config, :integrator_range, 0),
      integrator_range_max: Keyword.get(config, :integrator_range, 0),
      pv_integrator: 0,
      integrator_factor: Keyword.get(config, :integrator_factor, 1),
      pv_correction_prev: 0,
      output: Keyword.fetch!(config, :output_neutral)
    }
  end

  @spec update(map(), map(), float(), float(), map()) :: map()
  def update(cmds, values, _airspeed, dt, state) do
    altitude_corr = cmds.altitude_corr
    alt_rate_sp = altitude_corr*state.altitude_kp
    # Logger.debug("alt_rate_sp: #{Common.Utils.eftb(alt_rate_sp,2)}")
    potential_energy = values.potential_energy
    potential_energy_rate = values.potential_energy_rate

    potential_energy_rate_sp = alt_rate_sp*Common.Constants.gravity
    potential_energy_sp = values.potential_energy + potential_energy_rate_sp*dt

    balance_cmd = potential_energy_sp
    balance_values = potential_energy
    balance_corr = balance_cmd - balance_values
    balance_rate_cmd = potential_energy_rate_sp
    balance_rate_values = potential_energy_rate
    balance_rate_corr = balance_rate_cmd - balance_rate_values
    # Logger.debug("pe_sp/pe: #{Common.Utils.eftb(potential_energy_sp,1)}/#{Common.Utils.eftb(potential_energy,1)}")
    # Logger.debug("rate: pe_sp/pe: #{Common.Utils.eftb(potential_energy_rate_sp,3)}/#{Common.Utils.eftb(potential_energy_rate,3)}")

    # Proportional
    cmd_p = balance_corr
    # Integrator
    # Logger.debug("bcorr/pv_int: #{Common.Utils.eftb(balance_corr,3)}/#{Common.Utils.eftb(state.integrator_range_max,3)}")
    in_range = Common.Utils.Math.in_range?(balance_corr, state.integrator_range_min, state.integrator_range_max)

    error_positive = cmd_p > 0
    i_positive = state.pv_integrator > 0

    pv_mult = if !i_positive and !error_positive, do: 1.0, else: state.integrator_factor

    pv_add = balance_corr*dt
    pv_integrator = cond do
      in_range -> state.pv_integrator + pv_add*pv_mult
      error_positive != i_positive -> state.pv_integrator + pv_add*pv_mult
      true -> state.pv_integrator
    end
    # Logger.debug("pv int: #{Common.Utils.eftb(pv_integrator,3)}")

    cmd_i = state.ki*pv_integrator
    |> Common.Utils.Math.constrain(-0.175, 0.175)
    # Logger.info("cmd i pre/post: #{Common.Utils.eftb(cmd_i_mult*pv_integrator,3)}/#{Common.Utils.eftb(cmd_i, 3)}")
    pv_integrator =
    if (state.ki != 0), do: cmd_i / state.ki, else: 0
    # Derivative
    cmd_d = balance_rate_corr*state.kd

    cmd_rate = 0*balance_rate_cmd*state.time_constant

    output = (cmd_p + cmd_i + cmd_d + cmd_rate) / state.time_constant * state.balance_rate_scalar
    |> Common.Utils.Math.constrain(state.output_min, state.output_max)

    # Logger.debug("tecs bal: #{Common.Utils.eftb_deg(output,1)}")
    # Logger.debug("p/i/d/rate/total: #{Common.Utils.eftb_deg(cmd_p,3)}/#{Common.Utils.eftb_deg(cmd_i,3)}/#{Common.Utils.eftb_deg(cmd_d, 3)}/#{Common.Utils.eftb(cmd_rate,3)}/#{Common.Utils.eftb_deg(output, 3)}")
    # Logger.debug("p/i/total: #{Common.Utils.eftb_deg(cmd_p,3)}/#{Common.Utils.eftb_deg(cmd_i,3)}/#{Common.Utils.eftb_deg(output, 3)}")

    %{state | pv_integrator: pv_integrator, output: output}
  end
end
