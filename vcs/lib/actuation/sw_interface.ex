defmodule Actuation.SwInterface do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Actuation SwInterface")
    {:ok, process_id} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    # start_message_sorters()
    start_actuator_loop()
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        actuators: Map.get(config, :actuators),
        actuator_timer: nil,
        actuator_loop_interval_ms: Map.get(config, :actuator_loop_interval_ms, 0)
     }}
  end

  # @impl GenServer
  # def handle_cast(:start_message_sorters, state) do
  #   # MessageSorter.System.start_link()
  #   # failsafe_map = Enum.reduce(state.actuators, %{}, fn({actuator_name, actuator}, acc) ->
  #   #   Map.put(acc, actuator_name, actuator.failsafe_cmd)
  #   # end)
  #   # MessageSorter.System.start_sorter(
  #   #   %{
  #   #     name: :actuator_cmds,
  #   #     default_message_behavior: :default_value,
  #   #     default_value: failsafe_map,
  #   #     value_type: :map
  #   #   }
  #   # )
  #   # Enum.each(state.actuators, fn {actuator_name, actuator} ->
  #   #   MessageSorter.System.start_sorter(%{name: {:actuator_cmds, actuator_name}, default_message_behavior: :default_value, default_value: actuator.failsafe_cmd})
  #   # end)
  #   {:noreply, state}
  # end

    @impl GenServer
  def handle_cast(:start_actuator_loop, state) do
      actuator_timer = Common.Utils.start_loop(self(), state.actuator_loop_interval_ms, :actuator_loop)
      state = %{state | actuator_timer: actuator_timer}
      {:noreply, state}
  end

  # @impl GenServer
  # def handle_cast(:stop_actuator_loop, state) do
  #   actuator_timer = Common.Utils.stop_loop(state.actuator_timer)
  #   state = %{state | actuator_timer: actuator_timer}
  #   {:noreply, state}
  # end

  @impl GenServer
  def handle_info(:actuator_loop, state) do
    # Go through every channel and send an update to the ActuatorInterfaceOutput
    # actuator_interface_output_process_name = state.config.actuator_interface_output.process_name
    actuator_output_map = MessageSorter.Sorter.get_value(:actuator_cmds)
    # Logger.warn("act_sw loop. actuator output map: #{inspect(actuator_output_map)}")
    Enum.each(state.actuators, fn {actuator_name, actuator} ->
      output = Map.fetch!(actuator_output_map, actuator_name)
      # output = get_output_for_actuator_name(actuator_name)
      Logger.debug("move_actuator #{actuator_name} to #{output}")
      Actuation.HwInterface.set_output_for_actuator(actuator, output)
    end)
    {:noreply, state}
  end

  def get_output_for_actuator_name(actuator_name) do
    actuator_output_map = MessageSorter.Sorter.get_value(:actuator_cmds)
    Map.get(actuator_output_map, actuator_name, nil)
  end

  # defp start_message_sorters() do
  #   GenServer.cast(__MODULE__, :start_message_sorters)
  # end

  defp start_actuator_loop() do
    GenServer.cast(__MODULE__, :start_actuator_loop)
  end

  # defp stop_actuator_loop() do
  #   GenServer.cast(__MODULE__, :stop_actuator_loop)
  # end
end
