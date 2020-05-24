defmodule Command.Commander do
  use GenServer
  require Logger

  @rx_control_state_channel 4
  @transmit_channel 5

  def start_link(config) do
    Logger.debug("Start Command.Commander")
    {:ok, pid} = Common.Utils.start_link_redudant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    vehicle_type = config.vehicle_type
    vehicle_module = Module.concat([Vehicle, vehicle_type])
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_module: vehicle_module,
        commands: %{
        },
        pv_values: %{}
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    MessageSorter.System.start_link()
    # Start FrSky Sorter
    Comms.Operator.join_group(__MODULE__, :rx_output, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:rx_output, channel_output, _failsafe_active}, state) do
    # Logger.debug("rx_output: #{inspect(channel_output)}")
    convert_rx_output_to_cmds_and_publish(channel_output, state.vehicle_module, state.pv_values)
    {:noreply, state}
  end

  @spec convert_rx_output_to_cmds_and_publish(list(), atom(), map()) :: atom()
  defp convert_rx_output_to_cmds_and_publish(rx_output, vehicle_module, pv_values) do
    control_state_float = Enum.at(rx_output, @rx_control_state_channel)
    transmit_float = Enum.at(rx_output, @transmit_channel)
    if (transmit_float > 0) do
      control_state = cond do
        control_state_float > 0.5 -> 3
        control_state_float > -0.5 -> 2
        true -> 1
      end
      channel_map = Enum.with_index(apply(vehicle_module, :get_rx_output_channel_map, [control_state]))
      cmds = Enum.reduce(channel_map, %{}, fn ({channel_tuple, index}, acc) ->
        channel = elem(channel_tuple, 0)
        absolute_or_relative = elem(channel_tuple, 1)
        min_value = elem(channel_tuple, 2)
        max_value = elem(channel_tuple, 3)
        inverted_multiplier = elem(channel_tuple, 4)
        unscaled_value = inverted_multiplier*Enum.at(rx_output, index)
        scaled_value = if (unscaled_value > 0) do
          unscaled_value*max_value
        else
          -unscaled_value*min_value
        end
        output_value =
          case absolute_or_relative do
            :absolute -> scaled_value
            :relative -> Map.get(pv_values, channel, 0) + scaled_value
          end
        Map.put(acc, channel, output_value)
      end)
      Comms.Operator.send_global_msg_to_group(__MODULE__,{{:goals, control_state},cmds}, {:goals, control_state}, self())
    end
  end
end