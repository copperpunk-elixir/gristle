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
    vehicle_module = Module.concat([Configuration.Vehicle,vehicle_type,Command])
    {rx_output_classification, rx_output_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :rx_output)
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_module: vehicle_module,
        rx_output_classification: rx_output_classification,
        rx_output_time_validity_ms: rx_output_time_validity_ms,
        commands: %{
        },
        pv_values: %{}
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    Comms.Operator.join_group(__MODULE__, :rx_output, self())
    Comms.Operator.join_group(__MODULE__, :pv_estimate, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:rx_output, channel_output, _failsafe_active}, state) do
    # Logger.debug("rx_output: #{inspect(channel_output)}")
    convert_rx_output_to_cmds_and_publish(channel_output, state.vehicle_module, state.rx_output_classification, state.rx_output_time_validity_ms, state.pv_values)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:pv_estimate, pv_values}, state) do
    # Logger.debug("position: #{inspect(pv_values.position)}")
    # Logger.debug("velocity: #{inspect(pv_values.velocity)}")
    # Logger.debug("attitude: #{inspect(pv_values.attitude)}")
    # Logger.debug("bodyrate: #{inspect(pv_values.body_rate)}")
    {:noreply, %{state | pv_values: pv_values}}
  end

  @spec convert_rx_output_to_cmds_and_publish(list(), atom(), list(), integer(), map()) :: atom()
  defp convert_rx_output_to_cmds_and_publish(rx_output, vehicle_module,classification, time_validity_ms, pv_values) do
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
        mid_value = (min_value + max_value)/2
        delta_value_each_side = max_value - mid_value
        inverted_multiplier = elem(channel_tuple, 4)
        unscaled_value = inverted_multiplier*Enum.at(rx_output, index)
        scaled_value = mid_value + unscaled_value*delta_value_each_side
        output_value =
          case absolute_or_relative do
            :absolute -> scaled_value
            :relative -> Map.get(pv_values, channel, 0) + scaled_value
          end
        Map.put(acc, channel, output_value)
      end)
      Comms.Operator.send_global_msg_to_group(__MODULE__,{{:goals, control_state},classification, time_validity_ms, cmds}, {:goals, control_state}, self())
    end
  end
end
