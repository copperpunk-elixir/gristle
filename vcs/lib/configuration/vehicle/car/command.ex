# defmodule Configuration.Vehicle.Car.Command do
#   require Logger

#   @spec get_rx_output_channel_map() :: map()
#   def get_rx_output_channel_map() do
#     output_limits = Configuration.Module.Command.get_command_output_limits(:Car, [:thrust, :yawrate, :yaw, :course_flight, :speed])
#     Logger.debug("output limits: #{inspect(output_limits)}")
#     # channel_number, channel, absolute/relative, min, max
#     %{
#       -1 => [
#         {2, :thrust, :absolute, 0, 0, 0},
#         {0, :yawrate, :absolute, 0, 0, 0}
#       ],
#       0 => [
#         {2, :thrust, :absolute, 0, 0,0},
#         {0, :yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, 1}
#       ],
#       1 => [
#         {2,:thrust, :absolute, 0, output_limits.thrust.max, 1},
#         {0,:yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, 1}
#       ],
#       2 => [
#         {2,:thrust, :absolute, 0, output_limits.thrust.max, 1},
#         {0,:yaw, :absolute, output_limits.yaw.min, output_limits.yaw.max, 1}
#       ],
#       3 => [
#         {0, :course_flight, :relative, output_limits.course_flight.min, output_limits.course_flight.max, 1},
#         {2,:speed, :absolute, 0, 10, 1}
#       ]
#     }
#   end
# end
