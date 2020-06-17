# defmodule Configuration.Vehicle do
#   require Logger

#   @spec get_config(atom(), atom()) :: map()
#   def get_config(module, vehicle_type, node_type \\ nil) do
#     config_module =
#       Module.concat(Configuration.Vehicle, vehicle_type)
#       |> Module.concat(module)
#     case module do
#       Control ->
#         %{
#           controller: %{
#             vehicle_type: vehicle_type,
#             process_variable_cmd_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
#           }}
#       Navigation ->
#         %{
#           navigator: %{
#             vehicle_type: vehicle_type,
#             navigator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
#             default_pv_cmds_level: 3
#           }}
#       Pids -> apply(config_module, :get_config, [])
#     end
#   end


  
#   end
