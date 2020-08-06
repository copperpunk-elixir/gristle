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
    output_module =
      case config.node_type do
        :sim -> [Simulation.XplaneSend, Actuation.HwInterface]
        _other -> [Actuation.HwInterface]
      end
    {:ok, %{
        actuators: Map.get(config, :actuators),
        actuator_loop_interval_ms: Map.get(config, :actuator_loop_interval_ms, 0),
        output_module: output_module
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
    # actuator_interface_output_process_name = state.config.actuator_interface_output.process_name
    actuator_output_map = MessageSorter.Sorter.get_value(:actuator_cmds)
    # Logger.warn("act_sw loop. actuator output map: #{inspect(actuator_output_map)}")
    actuators_and_outputs =
      Enum.reduce(state.actuators,%{}, fn ({actuator_name, actuator}, acc) ->
        output = Map.fetch!(actuator_output_map, actuator_name)
      # output = get_output_for_actuator_name(actuator_name)
      # if (actuator_name == :steering) do
      # Logger.debug("move_actuator #{actuator_name} to #{Common.Utils.eftb(output, 3)}")
      # end
      # Actuation.HwInterface.set_output_for_actuator(actuator, output)
      # Enum.each(state.output_module, fn module ->
      #   apply(module, :set_output_for_actuator, [actuator,actuator_name, output])
      # end)
        Map.put(acc, actuator_name, {actuator,output})
    end)
    Enum.each(state.output_module, fn module ->
      apply(module, :update_actuators,[actuators_and_outputs])
    end)
    {:noreply, state}
  end

  # def get_output_for_actuator_name(actuator_name) do
  #   actuator_output_map = MessageSorter.Sorter.get_value(:actuator_cmds)
  #   Map.get(actuator_output_map, actuator_name, nil)
  # end
end
