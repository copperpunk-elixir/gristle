defmodule Actuation.SwInterface do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Actuation SwInterface GenServer")
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
     actuators_direct_and_indirect = Keyword.get(config, :actuators, %{})
     direct_actuators = Map.get(actuators_direct_and_indirect, :direct, %{})
     indirect_actuators = Map.get(actuators_direct_and_indirect, :indirect, %{})
     actuators = Map.merge(direct_actuators, indirect_actuators)
     state = %{
       actuators: actuators,
       direct_actuator_cmds: %{},
       indirect_actuator_cmds: %{},
       indirect_override_actuator_cmds: %{}
     }
     Comms.System.start_operator(__MODULE__)
     Comms.Operator.join_group(__MODULE__, :direct_actuator_cmds_sorter, self())
     Comms.Operator.join_group(__MODULE__, :indirect_override_cmds_sorter, self())

     actuator_loop_interval_ms = Keyword.fetch!(config, :actuator_loop_interval_ms)
     Enum.each(direct_actuators, fn {actuator_name, _actuator} ->
       Registry.register(MessageSorterRegistry, {:direct_actuator_cmds, actuator_name}, Keyword.fetch!(config, :direct_actuator_sorter_interval_ms))
     end)
     Registry.register(MessageSorterRegistry, :indirect_actuator_cmds, Keyword.fetch!(config, :indirect_actuator_sorter_interval_ms))
     Registry.register(MessageSorterRegistry, :indirect_override_actuator_cmds, Keyword.fetch!(config, :indirect_override_sorter_interval_ms))

     Common.Utils.start_loop(self(), actuator_loop_interval_ms, :actuator_loop)
     {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:direct_actuator_cmds_sorter, classification, time_validity_ms, cmds}, state) do
    # Logger.debug("rx direct: #{inspect(classification)}/#{time_validity_ms}: #{inspect(cmds)}")
    Enum.each(cmds, fn {name, value} ->
      # Logger.debug("dacs #{name}: #{value}")
      MessageSorter.Sorter.add_message({:direct_actuator_cmds, name}, classification, time_validity_ms, value)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:indirect_override_cmds_sorter, classification, time_validity_ms, cmds}, state) do
    # Logger.info("indirect override sorter: #{inspect(cmds)}")
    MessageSorter.Sorter.add_message(:indirect_override_actuator_cmds, classification, time_validity_ms, cmds)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, {:direct_actuator_cmds, name}, cmd, _status}, state) do
    direct_actuator_cmds = Map.put(state.direct_actuator_cmds, name, cmd)
    # Logger.debug("dir: #{inspect(direct_actuator_cmds)}")
    {:noreply, %{state | direct_actuator_cmds: direct_actuator_cmds}}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, :indirect_actuator_cmds, cmds, _status}, state) do
    {:noreply, %{state | indirect_actuator_cmds: cmds}}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, :indirect_override_actuator_cmds, cmds, status}, state) do
    cmds = if status == :current, do: cmds, else: %{}
    # Logger.debug("indirect override: #{inspect(cmds)}")
    {:noreply, %{state | indirect_override_actuator_cmds: cmds}}
  end

  @impl GenServer
  def handle_info(:actuator_loop, state) do
    actuator_output_map = Map.merge(state.indirect_actuator_cmds, state.indirect_override_actuator_cmds)
    |> Map.merge(state.direct_actuator_cmds)

    # Logger.debug("aom: #{inspect(actuator_output_map)}")

    # Loop over actuator_output_map. Only move those actuators with values
    actuators = state.actuators
    actuators_and_outputs =
      Enum.reduce(actuator_output_map, %{}, fn ({actuator_name, output}, acc) ->
        actuator = Map.fetch!(actuators, actuator_name)
        # Logger.debug("#{actuator_name}: #{output}")
        Map.put(acc, actuator_name, {actuator,output})
    end)

    Comms.Operator.send_local_msg_to_group(__MODULE__, {:update_actuators, actuators_and_outputs}, self())
    {:noreply, state}
  end
end
