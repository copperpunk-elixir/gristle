defmodule Pids.Controller.TecsBalance do
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
        time_constant: Map.get(config, :tc, 1.0),
        balance_rate_scalar: config.balance_rate_scalar,
        output_min: config.output_min,
        output_max: config.output_max,
        output_neutral: config.output_neutral,
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
    speed_dot =
    if is_nil(state.speed_prev) do
      0
    else
    (values.speed - state.speed_prev)/dt
    end


    kinetic_energy_rate = speed_dot/Common.Constants.gravity()
    kinetic_energy_rate_sp = cmds.speed_dot/Common.Constants.gravity()

    balance_corr = (cmds.potential_energy - cmds.kinetic_energy) - (values.potential_energy - values.kinetic_energy)
    balance_rate_cmd = cmds.potential_energy_rate - kinetic_energy_rate_sp
    balance_rate_values = values.potential_energy_rate - kinetic_energy_rate
    balance_rate_corr = balance_rate_cmd - balance_rate_values
    Logger.debug("pe_sp/pe/ke_sp/ke: #{Common.Utils.eftb(cmds.potential_energy,3)}/#{Common.Utils.eftb(values.potential_energy,3)}/#{Common.Utils.eftb(cmds.kinetic_energy,3)}/#{Common.Utils.eftb(values.kinetic_energy, 3)}")

    cmd_p = balance_corr#*state.kp
    cmd_i = 0.0
    cmd_d = balance_rate_corr*state.kd
    cmd_rate = balance_rate_cmd*state.time_constant

    output = (cmd_p + cmd_i + cmd_d + cmd_rate) / state.time_constant * state.balance_rate_scalar
    |> Common.Utils.Math.constrain(state.output_min, state.output_max)

    Logger.debug("p/i/d/total: #{Common.Utils.eftb(cmd_p,3)}/#{Common.Utils.eftb(cmd_i,3)}/#{Common.Utils.eftb(cmd_d, 3)}/#{Common.Utils.eftb(output, 3)}")

    %{state | output: output, speed_prev: values.speed}
  end
end
