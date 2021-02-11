defmodule Control.Controller do
  use GenServer
  require Logger
  require Command.Utils, as: CU

  def start_link(config) do
    Logger.debug("Start Control.Controller GenServer")
    {:ok, process_id} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, process_id}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    {act_msg_class, act_msg_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :indirect_actuator_cmds)
    {control_cmds_msg_class, control_cmds_msg_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :control_cmds)
    attitude_scalar = Enum.reduce(Keyword.fetch!(config, :attitude_scalar), %{}, fn ({cv_pv, scalar}, acc) ->
      Map.put(acc, cv_pv, Enum.into(scalar, %{}))
    end)
    vehicle_type = String.to_existing_atom(config[:vehicle_type])

    state = %{
      control_cmds: %{},
      control_state: 0,
      yaw: nil,
      airspeed: 0,
      attitude_scalar: attitude_scalar,
      act_msg_class: act_msg_class,
      act_msg_time_ms: act_msg_time_ms,
      control_cmds_msg_class: control_cmds_msg_class,
      control_cmds_msg_time_ms: control_cmds_msg_time_ms,
      bodyrate_module: Module.concat(Pids.Bodyrate, vehicle_type),
      attitude_module: Module.concat(Pids.Attitude, vehicle_type),
      high_level_module: Module.concat(Pids.HighLevel, vehicle_type),
      motor_moments: config[:motor_moments]
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:estimation_values, :attitude_bodyrate}, self())
    Comms.Operator.join_group(__MODULE__, {:estimation_values, :position_velocity}, self())
    Control.Arm.start_link()

    Registry.register(MessageSorterRegistry, {:control_state, :value}, 200)
    Registry.register(MessageSorterRegistry, {{:control_cmds, CU.cs_rates}, :value}, Configuration.Generic.get_loop_interval_ms(:fast))
    Registry.register(MessageSorterRegistry, {{:control_cmds, CU.cs_attitude}, :value}, Configuration.Generic.get_loop_interval_ms(:fast))
    Registry.register(MessageSorterRegistry, {{:control_cmds, CU.cs_sca}, :value}, Configuration.Generic.get_loop_interval_ms(:fast))
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, :control_state, control_state, _status}, state) do
    {:noreply, %{state | control_state: control_state}}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, {:control_cmds, level}, control_cmds, _status}, state) do
    # Logger.info("rx level: #{level}")
    control_cmds = Map.put(state.control_cmds, level, control_cmds)
    {:noreply, %{state | control_cmds: control_cmds}}
  end

  @impl GenServer
  def handle_cast({{:estimation_values, :attitude_bodyrate}, attitude, bodyrate, dt}, state) do
    # Logger.debug("Control rx att/attrate/dt: #{inspect(attitude)}/#{inspect(bodyrate)}/#{dt}")
    # Logger.debug("cs: #{state.control_state}")

    {cmd_level, values, function} =
      case state.control_state do
        CU.cs_sca ->
          values = Map.merge(attitude, bodyrate)
          |> Map.put(:airspeed, state.airspeed)
          {CU.cs_attitude, values, :process_attitude}
        CU.cs_attitude ->
          values = Map.merge(attitude, bodyrate)
          |> Map.put(:airspeed, state.airspeed)
          {CU.cs_attitude, values, :process_attitude}
        CU.cs_rates ->
          values = Map.put(bodyrate, :airspeed, state.airspeed)
          {CU.cs_rates, values, :process_rates}
        other -> {other, %{}, nil}
      end

    # Logger.debug("control cmd lev #{pv_cmd_level}")
    control_cmds = Map.get(state.control_cmds, cmd_level, %{})
    unless Enum.empty?(control_cmds) do
      # Logger.debug("control_cmds#{cmd_level}: #{Common.Utils.eftb_map(control_cmds, 3)}")
      apply(__MODULE__, function, [control_cmds, values, dt, state])
    end
    {:noreply, %{state | yaw: attitude.yaw}}
  end

  @impl GenServer
  def handle_cast({{:estimation_values, :position_velocity}, position, velocity, dt}, state) do
    # Logger.debug("Control rx vel/pos/dt: #{inspect(position)}/#{inspect(velocity)}/#{dt}")
    airspeed = velocity.airspeed
    if (state.control_state == CU.cs_sca) do
      yaw = state.yaw
      unless is_nil(yaw) do
        values = Map.merge(velocity, %{altitude: position.altitude, yaw: yaw, airspeed: airspeed})
        control_cmds = Map.get(state.control_cmds, CU.cs_sca, %{})
        unless Enum.empty?(control_cmds) do
          # Logger.debug("control cmds 3: #{Common.Utils.eftb_map(control_cmds, 3)}")
          process_speed_course_altitude(control_cmds, values, dt, state)
        end
      end
    end
    {:noreply, %{state | airspeed: airspeed}}
  end

  @spec process_rates(map(), map(), float(),  map()) :: atom()
  def process_rates(rates_cmds, values, dt, state) do
    actuator_outputs = apply(state.bodyrate_module, :calculate_outputs, [rates_cmds, values, dt, state.motor_moments])
    # Logger.debug(Common.Utils.eftb_map(actuator_outputs, 2))
    send_cmds(actuator_outputs, state.act_msg_class, state.act_msg_time_ms, :indirect_actuator_cmds)
    store_cmds_with_telemetry(rates_cmds, CU.cs_rates)
    :ok
  end

  @spec process_attitude(map(), map(), float(), map()) :: atom()
  def process_attitude(attitude_cmds, values, dt, state) do
    rates_output = apply(state.attitude_module, :calculate_outputs, [attitude_cmds, values, state.attitude_scalar])
    # Logger.debug(Common.Utils.eftb_map(level_1_output_map,2))
    # output_map turns into input_map for Level I calcs
    rates_cmds = rates_output
    actuator_outputs = apply(state.bodyrate_module, :calculate_outputs, [rates_cmds, values, dt, state.motor_moments])
    # Logger.debug(Common.Utils.eftb_map(actuator_outputs, 2))
    send_cmds(actuator_outputs, state.act_msg_class, state.act_msg_time_ms, :indirect_actuator_cmds)
    store_cmds_with_telemetry(attitude_cmds, CU.cs_attitude)
    store_cmds_with_telemetry(rates_cmds, CU.cs_rates)
    :ok
  end

  @spec process_speed_course_altitude(map(), map(), float(), map()) :: atom()
  def process_speed_course_altitude(sca_cmds, values, dt, state) do
    attitude_output = apply(state.high_level_module, :calculate_outputs, [sca_cmds, values, dt])
    # Logger.debug("#{Common.Utils.eftb_map_deg(level_2_output_map,2)}")

    sca_cmds = Map.put(sca_cmds, :course, attitude_output.course)
    # Logger.info("#{Common.Utils.eftb_map_deg(sca_cmds,2)}")

    send_cmds(attitude_output, state.control_cmds_msg_class, state.control_cmds_msg_time_ms, {:control_cmds, CU.cs_attitude})
    store_cmds_with_telemetry(sca_cmds, CU.cs_sca)
    :ok
  end

  defp send_cmds(output_map, msg_class, msg_time_ms, cmd_type) do
    MessageSorter.Sorter.add_message(cmd_type, msg_class, msg_time_ms, output_map)
  end

  @spec store_cmds_with_telemetry(map(), integer()) :: atom()
  def store_cmds_with_telemetry(cmds, level) do
    Peripherals.Uart.Telemetry.Operator.store_data(%{{:cmds, level} => cmds})
  end
end
