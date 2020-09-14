defmodule Actuation.SwInterface do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Actuation SwInterface")
    {:ok, process_id} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
        {:ok, %{
        actuators: Map.get(config, :actuators),
        actuator_loop_interval_ms: Map.get(config, :actuator_loop_interval_ms, 0),
        output_modules: config.output_modules
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
     Comms.Operator.join_group(__MODULE__, :direct_actuator_cmds_sorter, self())
     Common.Utils.start_loop(self(), state.actuator_loop_interval_ms, :actuator_loop)
     {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:direct_actuator_cmds_sorter, classification, time_validity_ms, cmds}, state) do
    # Logger.debug("rx direct: #{inspect(cmds)}")
    MessageSorter.Sorter.add_message(:direct_actuator_cmds, classification, time_validity_ms, cmds)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:actuator_loop, state) do
    # Go through every channel and send an update to the ActuatorInterfaceOutput
    direct_actuator_output_map = MessageSorter.Sorter.get_value(:direct_actuator_cmds)
    |> Common.Utils.default_to([])
    indirect_actuator_output_map = MessageSorter.Sorter.get_value(:indirect_actuator_cmds)
    |> Common.Utils.default_to([])
    # Logger.debug("indirect: #{inspect(indirect_actuator_output_map)}")
    # Logger.debug("direct: #{inspect(direct_actuator_output_map)}")
    actuator_output_map = Map.merge(indirect_actuator_output_map, direct_actuator_output_map)
    # Loop over actuator_output_map. Only move those actuators with values
    # This way we can have different MessageSorters for different types of actuation (direct, indirect)
    actuators = state.actuators
    actuators_and_outputs =
      Enum.reduce(actuator_output_map,%{}, fn ({actuator_name, output}, acc) ->
        actuator = Map.fetch!(actuators, actuator_name)
        # Logger.debug("#{actuator_name}: #{output}")
        Map.put(acc, actuator_name, {actuator,output})
    end)
    # Logger.debug("actuators_and_outputs: #{inspect(actuators_and_outputs)}")
    Enum.each(state.output_modules, fn module ->
      apply(module, :update_actuators,[actuators_and_outputs])
    end)
    {:noreply, state}
  end
end
