defmodule Command.Commander do
  use GenServer
  require Logger

  @rx_control_state_channel 4
  @rx_armed_state_channel 5
  @transmit_channel 6

  def start_link(config) do
    Logger.debug("Start Command.Commander")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    vehicle_type = config.vehicle_type
    vehicle_module = Module.concat([Configuration.Vehicle,vehicle_type,Command])
    {goals_classification, goals_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :goals)
    rx_output_channel_map = apply(vehicle_module, :get_rx_output_channel_map, [])
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_module: vehicle_module,
        goals_classification: goals_classification,
        goals_time_validity_ms: goals_time_validity_ms,
        control_state: -1,
        transmit_cmds: false,
        reference_cmds: %{},
        rx_output_time_prev: 0,
        pv_values: %{},
        rx_output_channel_map: rx_output_channel_map
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :rx_output, self())
    Comms.Operator.join_group(__MODULE__, :pv_estimate, self())
    rx_output_time_prev = :erlang.monotonic_time(:millisecond)
    {:noreply, %{state | rx_output_time_prev: rx_output_time_prev}}
  end

  @impl GenServer
  def handle_cast({:rx_output, channel_output, _failsafe_active}, state) do
    # Logger.debug("rx_output: #{inspect(channel_output)}")
    current_time = :erlang.monotonic_time(:millisecond)
    dt = (current_time - state.rx_output_time_prev)/1000.0
    {reference_cmds, control_state, transmit_cmds} = convert_rx_output_to_cmds_and_publish(channel_output, dt, state)
    {:noreply, %{state | rx_output_time_prev: current_time, reference_cmds: reference_cmds, control_state: control_state, transmit_cmds: transmit_cmds}}
  end

  @impl GenServer
  def handle_cast({:pv_estimate, pv_values}, state) do
    # Logger.debug("position: #{inspect(pv_values.position)}")
    # Logger.debug("velocity: #{inspect(pv_values.velocity)}")
    # Logger.debug("attitude: #{inspect(pv_values.attitude)}")
    # Logger.debug("bodyrate: #{inspect(pv_values.bodyrate)}")
    {:noreply, %{state | pv_values: pv_values}}
  end

  @spec convert_rx_output_to_cmds_and_publish(list(), float(), map()) :: atom()
  defp convert_rx_output_to_cmds_and_publish(rx_output, dt, state) do
    armed_state_float = Enum.at(rx_output, @rx_armed_state_channel)
    control_state_float = Enum.at(rx_output, @rx_control_state_channel)
    transmit_cmds =
    if (Enum.at(rx_output, @transmit_channel) > 0) do
      true
    else
      false
    end
    if (transmit_cmds == true) do
      control_state = cond do
        (armed_state_float < -0.5) -> -1
        (armed_state_float < 0.5) -> 0
        true ->
          cond do
            control_state_float > 0.5 -> 3
            control_state_float > -0.5 -> 2
            true -> 1
          end
      end
      reference_cmds =
      if (control_state != state.control_state) or (state.transmit_cmds == false) do
        Logger.info("latch cs: #{control_state}")
        latch_commands(control_state, state.pv_values)
      else
        state.reference_cmds
      end

      # channel_map = apply(state.vehicle_module, :get_rx_output_channel_map, [control_state])
      {cmds, reference_cmds} = Enum.reduce(Map.get(state.rx_output_channel_map, control_state), {%{}, %{}}, fn (channel_tuple, {acc, acc_ref}) ->
        channel_index = elem(channel_tuple, 0)
        channel = elem(channel_tuple, 1)
        absolute_or_relative = elem(channel_tuple, 2)
        min_value = elem(channel_tuple, 3)
        max_value = elem(channel_tuple, 4)
        mid_value = (min_value + max_value)/2
        delta_value_each_side = max_value - mid_value
        inverted_multiplier = elem(channel_tuple, 5)
        unscaled_value = inverted_multiplier*Enum.at(rx_output, channel_index)
        scaled_value = mid_value + unscaled_value*delta_value_each_side
        output_value =
          case absolute_or_relative do
            :absolute -> scaled_value
            :relative ->
              value_to_add = scaled_value*dt
              case channel do
                :yaw ->
                  reference_cmds.yaw + value_to_add
                  |> Common.Utils.Math.constrain(min_value, max_value)
                :course_flight ->
                  reference_cmds.course_flight + value_to_add
                  |> Common.Utils.constrain_angle_to_compass()
                :course_ground ->
                  reference_cmds.course_ground + value_to_add
                  |> Common.Utils.constrain_angle_to_compass()
                :speed ->
                  reference_cmds.speed + value_to_add
                  |> Common.Utils.Math.constrain(min_value, max_value)
                :altitude ->
                  reference_cmds.altitude + value_to_add
                  |> Common.Utils.Math.constrain(0, 10000)
                _other -> value_to_add
              end
          end
        {Map.put(acc, channel, output_value), Map.put(acc_ref, channel, output_value)}
      end)
      # if (control_state == 3) do
      #   Comms.Operator.send_global_msg_to_group(__MODULE__,{{:goals_relative, control_state},classification, time_validity_ms, cmds}, {:goals_relative, control_state}, self())
      # else
        Comms.Operator.send_global_msg_to_group(__MODULE__,{{:goals, control_state}, state.goals_classification, state.goals_time_validity_ms, cmds}, {:goals, control_state}, self())
      # end
      # Comms.Operator.send_global_msg_to_group(__MODULE__, {{:tx_goals, control_state}, cmds}, :tx_goals, self())
      {reference_cmds, control_state, transmit_cmds}
    else
      {%{}, state.control_state, transmit_cmds}
    end
  end

  @spec latch_commands(integer(), map()) :: map()
  def latch_commands(new_control_state, pv_values) do
    case new_control_state do
      2 ->
        # yaw = Map.get(pv_values, :attitude, %{})
        # |> Map.get(:yaw, 0)
        %{yaw: 0}
      3 ->
        course = Map.get(pv_values,:velocity, %{})
        |> Map.get(:course, 0)
        speed =
          Map.get(pv_values,:velocity, %{})
          |> Map.get(:speed, 0)
        altitude = Map.get(pv_values, :position, %{})
        |> Map.get(:altitude, 0)
        %{speed: speed, course_flight: course, altitude: altitude}
      _other ->
        %{}
    end
  end
end
