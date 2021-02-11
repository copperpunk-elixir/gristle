defmodule Pids.Moderator do
  use GenServer
  require Logger
  require Command.Utils, as: CU

  def start_link(config) do
    Logger.debug("Start Pids.Moderator")
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(pid, {:begin, config})
    {:ok, pid}
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
    {pv_msg_class, pv_msg_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :pv_cmds)
    attitude_scalar = Enum.reduce(Keyword.fetch!(config, :attitude_scalar), %{}, fn ({cv_pv, scalar}, acc) ->
      Map.put(acc, cv_pv, Enum.into(scalar, %{}))
    end)
    vehicle_type = String.to_existing_atom(config[:vehicle_type])
    bodyrate_module = Module.concat(Pids.Bodyrate, vehicle_type)
    attitude_module = Module.concat(Pids.Attitude, vehicle_type)
    high_level_module = Module.concat(Pids.HighLevel, vehicle_type)
    state = %{
      attitude_scalar: attitude_scalar,
      act_msg_class: act_msg_class,
      act_msg_time_ms: act_msg_time_ms,
      pv_msg_class: pv_msg_class,
      pv_msg_time_ms: pv_msg_time_ms,
      bodyrate_module: bodyrate_module,
      attitude_module: attitude_module,
      high_level_module: high_level_module,
      motor_moments: config[:motor_moments]
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, CU.cs_rates}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, CU.cs_attitude}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_cmds_values, CU.cs_sca}, self())
    Pids.Tecs.Arm.start_link()
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_cmds_values, level}, pv_cmd_map, pv_value_map, airspeed, dt}, state) do
    case level do
      CU.cs_sca ->
        attitude_output_map = apply(state.high_level_module, :calculate_outputs, [pv_cmd_map, pv_value_map, airspeed, dt])
        # Logger.debug("#{Common.Utils.eftb_map_deg(level_2_output_map,2)}")

        pv_cmd_map = Map.put(pv_cmd_map, :course, attitude_output_map.course)
        # Logger.info("#{Common.Utils.eftb_map_deg(pv_cmd_map,2)}")

        send_cmds(attitude_output_map, state.pv_msg_class, state.pv_msg_time_ms, {:pv_cmds, CU.cs_attitude})
        store_cmds_with_telemetry(pv_cmd_map, CU.cs_sca)
      CU.cs_attitude ->
        # Logger.warn("2cmd #{Common.Utils.eftb_map_deg(pv_cmd_map,2)}")
        # Logger.warn("2val #{Common.Utils.eftb_map_deg(pv_value_map.attitude,2)}")
        # Logger.warn("2val #{Common.Utils.eftb_map_deg(pv_value_map.bodyrate,2)}")
        rates_output_map = apply(state.attitude_module, :calculate_outputs, [pv_cmd_map, pv_value_map.attitude, state.attitude_scalar])

        # Logger.debug(Common.Utils.eftb_map(level_1_output_map,2))
        # output_map turns into input_map for Level I calcs
        rates_cmd_map = rates_output_map
        actuator_outputs = apply(state.bodyrate_module, :calculate_outputs, [rates_cmd_map, pv_value_map.bodyrate, airspeed, dt, state.motor_moments])
        # Logger.debug(Common.Utils.eftb_map(actuator_outputs, 2))
        send_cmds(actuator_outputs, state.act_msg_class, state.act_msg_time_ms, :indirect_actuator_cmds)
        store_cmds_with_telemetry(pv_cmd_map, CU.cs_attitude)
        store_cmds_with_telemetry(rates_cmd_map, CU.cs_rates)
      CU.cs_rates ->
        # Logger.debug("PID Level 1")
        actuator_outputs = apply(state.bodyrate_module, :calculate_outputs, [pv_cmd_map, pv_value_map.bodyrate, airspeed, dt, state.motor_moments])
        # Logger.debug(Common.Utils.eftb_map(actuator_outputs, 2))
        send_cmds(actuator_outputs, state.act_msg_class, state.act_msg_time_ms, :indirect_actuator_cmds)
        store_cmds_with_telemetry(pv_cmd_map, CU.cs_rates)
      _other ->
        Logger.warn("PID level unknown - How did we get here?")
    end
    {:noreply, state}
  end

  defp send_cmds(output_map, msg_class, msg_time_ms, cmd_type) do
    MessageSorter.Sorter.add_message(cmd_type, msg_class, msg_time_ms, output_map)
  end

  @spec store_cmds_with_telemetry(map(), integer()) :: atom()
  def store_cmds_with_telemetry(cmds, level) do
    Peripherals.Uart.Telemetry.Operator.store_data(%{{:cmds, level} => cmds})
  end
end
