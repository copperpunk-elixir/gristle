defmodule Pids.Controller.TecsBalance do
  require Logger

  @spec init(map()) :: tuple()
  def init(config) do
    {process_variable, control_variable} = Keyword.get(config, :name)
    {:ok, %{
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
        pv_correction_prev: 0,
        speed_prev: nil,
        output: Keyword.fetch!(config, :output_neutral)
     }}

  end

  @spec update(map(), map(), float(), float(), map()) :: map()
  def update(cmds, values, _airspeed, dt, state) do
    speed = values.speed

    # speed_dot =
    # if is_nil(state.speed_prev) do
    #   0
    # else
    # (speed - state.speed_prev)/dt
    # end


    altitude_corr = cmds.altitude_corr
    alt_rate_sp = altitude_corr*state.altitude_kp
    # Logger.debug("alt_rate_sp: #{Common.Utils.eftb(alt_rate_sp,2)}")
    potential_energy = values.potential_energy
    potential_energy_rate = values.potential_energy_rate

    potential_energy_rate_sp = alt_rate_sp*Common.Constants.gravity()
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

    cmd_rate = balance_rate_cmd*state.time_constant

    output = (cmd_p + cmd_i + cmd_d + cmd_rate) / state.time_constant * state.balance_rate_scalar
    |> Common.Utils.Math.constrain(state.output_min, state.output_max)

    # Logger.debug("tecs bal: #{Common.Utils.eftb_deg(output,1)}")
    # Logger.debug("p/i/d/rate/total: #{Common.Utils.eftb(cmd_p,3)}/#{Common.Utils.eftb(cmd_i,3)}/#{Common.Utils.eftb(cmd_d, 3)}/#{Common.Utils.eftb(cmd_rate,3)}/#{Common.Utils.eftb(output, 3)}")

    %{state | output: output, speed_prev: speed}
  end
end
