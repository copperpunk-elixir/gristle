defmodule Command.Commander do
  use GenServer
  require Logger

  @rx_control_state_channel 8
  @transmit_channel 7

  @pilot_manual 0
  @pilot_semi_auto 1
  @pilot_auto 2
  @cs_direct_manual 100
  @cs_direct_semi_auto 101
  @cs_direct_auto 102

  def start_link(config) do
    Logger.debug("Start Command.Commander")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    model_type = config.model_type
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module = Module.concat([Configuration.Vehicle,vehicle_type,Command])
    {goals_class, goals_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :goals)
    {direct_cmds_class, direct_cmds_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, {:direct_actuator_cmds, :flaps})
    {direct_select_class, direct_select_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, {:direct_actuator_cmds, :select})
    {indirect_override_class, indirect_override_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :indirect_override_cmds)


    rx_output_channel_map = apply(vehicle_module, :get_rx_output_channel_map, [model_type])
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_module: vehicle_module,
        goals_class: goals_class,
        goals_time_ms: goals_time_ms,
        direct_cmds_class: direct_cmds_class,
        direct_cmds_time_ms: direct_cmds_time_ms,
        indirect_override_cmds_class: indirect_override_class,
        indirect_override_cmds_time_ms: indirect_override_time_ms,
        direct_select_class: direct_select_class,
        direct_select_time_ms: direct_select_time_ms,
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
    Comms.Operator.join_group(__MODULE__, :pv_3_local, self())
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
  def handle_cast({:pv_3_local, pv_values}, state) do
    {:noreply, %{state | pv_values: pv_values}}
  end

  @spec convert_rx_output_to_cmds_and_publish(list(), float(), map()) :: atom()
  defp convert_rx_output_to_cmds_and_publish(rx_output, dt, state) do
    control_state_float = Enum.at(rx_output, @rx_control_state_channel)
    transmit_value = Enum.at(rx_output, @transmit_channel)
    pilot_control_mode = cond do
      transmit_value > 0.0 -> @pilot_manual
      transmit_value > -0.5 -> @pilot_semi_auto
      true -> @pilot_auto
    end
    # The direct_cmds control_state will determine which actuators are controlled directly from here
    # Any actuator not under direct control will have its command sent by either the Navigator (primary)
    # or the Pids.Moderator (secondary)
    indirect_override_cs = if (pilot_control_mode == @pilot_manual), do: @cs_direct_manual, else: @cs_direct_auto
    direct_cmds_cs = if (pilot_control_mode == @pilot_auto), do: @cs_direct_auto, else: @cs_direct_semi_auto
    # Logger.warn("ind cs/ dir cs: #{indirect_override_cs}/#{direct_cmds_cs}")
        # Logger.debug("cs_float: #{control_state_float}")
    if (pilot_control_mode != @pilot_auto) do
      control_state = cond do
        control_state_float < -0.95 -> 0
        control_state_float > -0.80 and control_state_float < -0.70 -> 1
        control_state_float > 0.20 and control_state_float < 0.30 -> 2
        control_state_float > 0.95 -> 3
        true -> -1
      end
      reference_cmds =
      if (control_state != state.control_state) do
        Logger.info("latch cs: #{control_state}")
        latch_commands(control_state, state.pv_values)
      else
        state.reference_cmds
      end

      {indirect_cmds, reference_cmds} =
        Enum.reduce(Map.get(state.rx_output_channel_map, control_state), {%{}, %{}}, fn (channel_tuple, {acc, acc_ref}) ->
          {channel, scaled_value} = get_channel_and_scaled_value(rx_output, channel_tuple)
          output_value =
            case elem(channel_tuple, 2) do
              :absolute -> scaled_value
              :relative -> get_relative_value(channel_tuple, scaled_value, reference_cmds, dt)
            end
          {Map.put(acc, channel, output_value), Map.put(acc_ref, channel, output_value)}
        end)
      direct_cmds = Enum.reduce(Map.get(state.rx_output_channel_map, direct_cmds_cs), %{}, fn (channel_tuple, acc) ->
        {channel, output_value} = get_channel_and_scaled_value(rx_output, channel_tuple)
        Map.put(acc, channel, output_value)
      end)
      indirect_override_cmds = Enum.reduce(Map.get(state.rx_output_channel_map, indirect_override_cs), %{}, fn (channel_tuple, acc) ->
        {channel, output_value} = get_channel_and_scaled_value(rx_output, channel_tuple)
        Map.put(acc, channel, output_value)
      end)

      # Publish Goals
      if pilot_control_mode == @pilot_manual do
        # If under manual control, tell all nodes to retain control
        # If a node's Actuation process is dead, it will not receive this, and thus it will be
        # under Guardian control anyway
        Comms.Operator.send_global_msg_to_group(__MODULE__, {:direct_actuator_cmds_sorter, state.direct_select_class, state.direct_select_time_ms, %{select: Actuation.SwInterface.self_control_value()}}, self())
      else
        Comms.Operator.send_global_msg_to_group(__MODULE__,{:goals_sorter, control_state, state.goals_class, state.goals_time_ms, indirect_cmds}, self())
      end
      # Indirect Override Cmds
      unless Enum.empty?(indirect_override_cmds) do
        Comms.Operator.send_global_msg_to_group(__MODULE__, {:indirect_override_cmds_sorter, state.indirect_override_cmds_class, state.indirect_override_cmds_time_ms, indirect_override_cmds}, self())
      end
      # Direct Cmds
      unless Enum.empty?(direct_cmds) do
        Comms.Operator.send_global_msg_to_group(__MODULE__, {:direct_actuator_cmds_sorter, state.direct_cmds_class, state.direct_cmds_time_ms, direct_cmds}, self())
      end
      {reference_cmds, control_state, true}
    else
      {%{}, state.control_state, false}
    end
  end


  @spec get_channel_and_scaled_value(list(), tuple()) :: tuple()
  def get_channel_and_scaled_value(rx_output, channel_tuple) do
    channel_index = elem(channel_tuple, 0)
    channel = elem(channel_tuple, 1)
    min_value = elem(channel_tuple, 3)
    max_value = elem(channel_tuple, 4)
    mid_value = (min_value + max_value)/2
    delta_value_each_side = max_value - mid_value
    inverted_multiplier = elem(channel_tuple, 5)
    unscaled_value = inverted_multiplier*Enum.at(rx_output, channel_index)
    scaled_value = mid_value + unscaled_value*delta_value_each_side
    {channel, scaled_value}
  end

  @spec get_relative_value(tuple(), float(), map(), float()) :: float()
  def get_relative_value(channel_tuple, scaled_value, reference_cmds, dt) do
    channel = elem(channel_tuple, 1)
    min_value = elem(channel_tuple, 3)
    max_value = elem(channel_tuple, 4)
    value_to_add = scaled_value*dt
    case channel do
      :yaw ->
        Map.get(reference_cmds, :yaw, 0) + value_to_add
        |> Common.Utils.Math.constrain(min_value, max_value)
      :course_flight ->
        Map.get(reference_cmds, :course_flight, 0) + value_to_add
        |> Common.Utils.Motion.constrain_angle_to_compass()
      :course_ground ->
        Map.get(reference_cmds, :course_ground, 0) + value_to_add
        |> Common.Utils.Motion.constrain_angle_to_compass()
      :speed ->
        Map.get(reference_cmds, :speed, 0) + value_to_add
        |> Common.Utils.Math.constrain(min_value, max_value)
      :altitude ->
        Map.get(reference_cmds, :altitude, 0) + value_to_add
        |> Common.Utils.Math.constrain(0, 10000)
      _other -> value_to_add
    end
  end

  @spec latch_commands(integer(), map()) :: map()
  def latch_commands(new_control_state, pv_values) do
    case new_control_state do
      2 ->
        %{yaw: 0}
      3 ->
        course = Map.get(pv_values, :course, 0)
        speed = Map.get(pv_values,:speed, 0)
        altitude = Map.get(pv_values, :altitude, 0)
        %{speed: speed, course_flight: course, altitude: altitude}
      _other ->
        %{}
    end
  end
end
