defmodule Configuration.Vehicle do
  require Logger

  @spec get_sorter_configs(atom()) :: list()
  def get_sorter_configs(vehicle_type) do
    base_module = Configuration.Vehicle
    vehicle_modules = [Actuation, Control, Navigation]
    Enum.reduce(vehicle_modules, %{}, fn (module, acc) ->
      vehicle_module =
        Module.concat(base_module, vehicle_type)
        |>Module.concat(module)
      Enum.concat(acc,apply(vehicle_module, :get_sorter_configs,[]))
    end)
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

  @spec get_config_for_vehicle_and_module(atom(), atom()) :: map()
  def get_config_for_vehicle_and_module(vehicle_type, module) do
    config_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(module)
    case module do
      Actuation -> apply(config_module, :get_config, [])
      Command ->
        %{
          commander: %{vehicle_type: vehicle_type},
          frsky_rx: %{
            device_description: "Feather M0",
            publish_rx_output_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
          }}
      Control ->
        %{
          controller: %{
            vehicle_type: vehicle_type,
            process_variable_cmd_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
          }}
      Navigation ->
        %{
          navigator: %{
            vehicle_type: vehicle_type,
            navigator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
            default_pv_cmds_level: 3
          }}
      Pids -> apply(config_module, :get_config, [])
    end
  end

  @spec get_command_output_limits(atom(), list()) :: tuple()
  def get_command_output_limits(vehicle_type, channels) do
    vehicle_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(Pids)

    Enum.reduce(channels, %{}, fn (channel, acc) ->
      constraints =
        apply(vehicle_module, :get_constraints, [])
        |> Map.get(channel)
      Map.put(acc, channel, %{min: constraints.output_min, max: constraints.output_max})
    end)
  end
end

