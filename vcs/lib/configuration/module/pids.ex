defmodule Configuration.Module.Pids do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    config_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(Pids)
    apply(config_module, :get_config, [])
  end

  def add_pid_input_constraints(pids, constraints) do
    Enum.reduce(pids, pids, fn ({pv, pv_cvs},acc) ->
      pid_config_with_input_constraints =
        Enum.reduce(pv_cvs, pv_cvs, fn ({cv, pid_config}, acc2) ->
          # IO.puts("pv/cv/config: #{pv}/#{cv}/#{inspect(pid_config)}}")
          input_min = get_in(constraints, [pv, :output_min])
          input_max =get_in(constraints, [pv, :output_max])
          # IO.puts("input min/max: #{get_in(constraints, [pv, :output_min])}/#{get_in(constraints, [pv, :output_max])}")
          pid_config =
          if input_min == nil or input_max == nil do
            pid_config
          else
            Map.merge(pid_config, %{input_min: input_min, input_max: input_max})
          end
          Map.put(acc2, cv, pid_config)
        end)
      Map.put(acc,pv,pid_config_with_input_constraints)
    end)
  end
end
