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
  def update(pv_cmds, pv_values, airspeed, dt, state) do
    output = 0*pv_cmds.speed*pv_values.speed*airspeed*dt + 0.05
    %{state | output: output}
  end
end
