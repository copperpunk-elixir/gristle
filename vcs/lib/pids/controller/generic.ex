defmodule Pids.Controller.Generic do
  require Logger

  @spec begin(list()) :: tuple()
  def begin(config) do
    {process_variable, control_variable} = Keyword.get(config, :name)
    %{
      pid_module: __MODULE__,
      process_variable: process_variable,
      control_variable: control_variable,
      kp: Keyword.get(config, :kp, 0),
      ki: Keyword.get(config, :ki, 0),
      kd: Keyword.get(config, :kd, 0),
      ff: Keyword.get(config, :ff, nil),
      output_min: Keyword.fetch!(config, :output_min),
      output_max: Keyword.fetch!(config, :output_max),
      output_neutral: Keyword.fetch!(config, :output_neutral),
      integrator_range_min: -Keyword.get(config, :integrator_range, 0),
      integrator_range_max: Keyword.get(config, :integrator_range, 0),
      integrator_airspeed_min: Keyword.get(config, :integrator_airspeed_min, 10000),
      pv_integrator: 0,
      pv_correction_prev: 0,
      output: Keyword.fetch!(config, :output_neutral)
    }
  end

  @spec update(float(), float(), float(), float(), map()) :: map()
  def update(pv_cmd, pv_value, airspeed, dt, state) do
    delta_output_min = state.output_min - state.output_neutral
    delta_output_max = state.output_max - state.output_neutral
    correction = pv_cmd - pv_value
    in_range = Common.Utils.Math.in_range?(correction, state.integrator_range_min, state.integrator_range_max)
    pv_add =
    if in_range do
      correction*dt
    else
      0.0
    end

    pv_integrator =
    if airspeed > state.integrator_airspeed_min do
      state.pv_integrator + pv_add
    else
      0.0
    end

    cmd_p = state.kp*correction
    |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)

    cmd_i = state.ki*pv_integrator
    |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)

    cmd_d =
    if dt != 0 do
      -state.kd*(correction- state.pv_correction_prev)/dt
      |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)
    else
      0.0
    end
    delta_output = cmd_p + cmd_i + cmd_d
    feed_forward =
      case Map.get(state, :ff) do
        nil -> 0
        f ->
          f.(pv_value+correction, pv_value, airspeed)
          |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)
      end
    # Logger.debug("delta: #{state.process_variable}/#{state.control_variable}: #{delta_output}")
    output = state.output_neutral + feed_forward + delta_output
    # Logger.debug("corr/dt/p/i/d/total: #{correction}/#{dt}/#{cmd_p}/#{cmd_i}/#{cmd_d}/#{output}")
    output = Common.Utils.Math.constrain(output, state.output_min, state.output_max)
    output = if state.process_variable == :speed do
      max_delta_output = 0.02
      delta_output = output-state.output
      |> Common.Utils.Math.constrain(-max_delta_output, max_delta_output)
      # Logger.debug("corr/p/i/d/total: #{Common.Utils.eftb(correction,3)}/#{Common.Utils.eftb(cmd_p, 3)}/#{Common.Utils.eftb(cmd_i, 3)}/#{Common.Utils.eftb(cmd_d, 3)}/#{Common.Utils.eftb(state.output+delta_output, 3)}")
      state.output + delta_output
    else
      output
    end
    if state.process_variable == :rollrate do
      Logger.debug("cmd/value/corr/p/ff/total: #{Common.Utils.eftb(pv_cmd,3)}/#{Common.Utils.eftb(pv_value,3)}/#{Common.Utils.eftb(correction,3)}/#{Common.Utils.eftb(cmd_p, 3)}/#{Common.Utils.eftb(feed_forward,3)}/#{Common.Utils.eftb(output-state.output_neutral, 3)}")
    end

    pv_correction_prev = correction
    pv_integrator =
    if (state.ki != 0) do
      cmd_i / state.ki
    else
      0.0
    end

    %{state | output: output,  pv_correction_prev: pv_correction_prev, pv_integrator: pv_integrator}
  end

  def parameters_to_write() do
    [:kp, :ki, :kd, :output_min, :output_max, :correction_min, :correction_max, :output_neutral]
  end

end
