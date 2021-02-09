defmodule Pids.Controller.Generic do
  require Logger

  @spec begin(list()) :: tuple()
  def begin(config) do
    {process_variable, control_variable} = Keyword.get(config, :name)
    output_min = Keyword.fetch!(config, :output_min)
    output_max = Keyword.fetch!(config, :output_max)
    output_neutral = Keyword.fetch!(config, :output_neutral)
    delta_output_min = if is_nil(config[:delta_output_min]), do: output_min - output_neutral, else: config[:delta_output_min]
    delta_output_max = if is_nil(config[:delta_output_max]), do: output_max - output_neutral, else: config[:delta_output_max]
    %{
      pid_module: __MODULE__,
      process_variable: process_variable,
      control_variable: control_variable,
      kp: Keyword.get(config, :kp, 0),
      ki: Keyword.get(config, :ki, 0),
      kd: Keyword.get(config, :kd, 0),
      ff: Keyword.get(config, :ff, nil),
      output_min: output_min,
      output_max: output_max,
      output_neutral: output_neutral,
      delta_output_min: delta_output_min,
      delta_output_max: delta_output_max,
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
    delta_output_min = state.delta_output_min
    delta_output_max = state.delta_output_max
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
    cmd_i = state.ki*pv_integrator

    cmd_d =
    if dt != 0 do
      -state.kd*(correction- state.pv_correction_prev)/dt
    else
      0.0
    end
    feed_forward =
      case Map.get(state, :ff) do
        nil -> 0
        f ->
          f.(pv_value+correction, pv_value, airspeed)
      end

    delta_output = cmd_p + cmd_i + cmd_d + feed_forward + state.output_neutral - state.output
    |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)

    output = state.output + delta_output
    |> Common.Utils.Math.constrain(state.output_min, state.output_max)

    if state.process_variable == :course_flight do# and state.control_variable == :thrust do
      Logger.debug("AS/cmd/value/corr/p/i/d/ff/dO/out: #{Common.Utils.eftb(airspeed,2)}/#{Common.Utils.eftb(pv_cmd,3)}/#{Common.Utils.eftb(pv_value,3)}/#{Common.Utils.eftb(correction,3)}/#{Common.Utils.eftb(cmd_p, 3)}/#{Common.Utils.eftb(cmd_i, 3)}/#{Common.Utils.eftb(cmd_d, 3)}/#{Common.Utils.eftb(feed_forward,3)}/#{Common.Utils.eftb(delta_output, 3)}/#{Common.Utils.eftb(output, 3)}")
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
