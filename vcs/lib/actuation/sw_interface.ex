defmodule Actuation.SwInterface do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Actuation SwInterface")
    {:ok, process_id} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :start_actuator_loop)
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
  def handle_cast(:start_actuator_loop, state) do
      Common.Utils.start_loop(self(), state.actuator_loop_interval_ms, :actuator_loop)
      {:noreply, state}
  end

  @impl GenServer
  def handle_info(:actuator_loop, state) do
    # Go through every channel and send an update to the ActuatorInterfaceOutput
    actuator_output_map = MessageSorter.Sorter.get_value(:actuator_cmds)
    #
    #
    # Loop over actuator_output_map. Only move those actuators with values
    # This way we can have different MessageSorters for different types of actuation (direct, indirect)
    actuators_and_outputs =
      Enum.reduce(state.actuators,%{}, fn ({actuator_name, actuator}, acc) ->
        output = Map.fetch!(actuator_output_map, actuator_name)
        Map.put(acc, actuator_name, {actuator,output})
    end)
    Enum.each(state.output_modules, fn module ->
      apply(module, :update_actuators,[actuators_and_outputs])
    end)
    {:noreply, state}
  end
end
