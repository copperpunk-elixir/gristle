defmodule Swarm.Gsm do
  use GenStateMachine
  require Logger

  @default_state_loop_interval_ms 100
  @desired_state_sorter {:desired_control_state, :state}

  def start_link(config \\ %{}) do
    {:ok, pid} = Common.Utils.start_link_redudant(GenStateMachine, __MODULE__, config)
    # {:ok, pid} = GenStateMachine.start_link(__MODULE__, config, name: __MODULE__)
    begin()
    start_state_loop()
    {:ok, pid}
  end

  def init(config) do
    state = get_state_enum(config.initial_state)
    modules_to_montor = Map.get(config, :modules_to_monitor, [])
    module_health =
      Enum.reduce(modules_to_montor, %{}, fn (module, acc) ->
        Map.put(acc, module, get_module_health_enum(:initializing))
      end)
    data = %{
      state_loop_interval_ms: Map.get(config, :state_loop_interval_ms, @default_state_loop_interval_ms),
      state_loop_timer: nil,
      module_health: module_health
    }
    {:ok, state, data}
  end

  def handle_event(:cast, :begin, _state, _data) do
    Comms.Operator.start_link()
    Comms.Operator.join_group(@desired_state_sorter, self())
    desired_sorter_config = %{
      name: @desired_state_sorter,
      default_message_behavior: :last
    }
    MessageSorter.System.start_sorter(desired_sorter_config)
    :keep_state_and_data
  end

  def handle_event(:cast, :start_state_loop, _state, data) do
    state_loop_timer = Common.Utils.start_loop(self(), data.state_loop_interval_ms, :state_loop)
    {:keep_state, %{data | state_loop_timer: state_loop_timer}}
  end

  def handle_event(:cast, {:add_desired_control_state, control_state, classification, time_validity_ms}, _state, data) do
    MessageSorter.Sorter.add_message(@desired_state_sorter, classification, time_validity_ms, control_state)
    :keep_state_and_data
  end

  def handle_event({:call, from}, :get_state, state, _data) do
    {:keep_state_and_data, [{:reply, from, state}]}
  end

  def handle_event({:call, from}, :get_data, _state, data) do
    {:keep_state_and_data, [{:reply, from, data}]}
  end

  def handle_event(:info, :state_loop, _state, data) do
    # TODO: Add logic to determine if new state is feasible
    Logger.debug("state loop")
    desired_control_state = MessageSorter.Sorter.get_value(@desired_state_sorter)
    # Fake logic
    control_state = desired_control_state
    Control.Controller.add_control_state(control_state)
    {:next_state, control_state, data}
  end

  def add_desired_control_state(control_state, classification, time_validity_ms) do
    Comms.Operator.send_msg_to_group({:add_desired_control_state, control_state, classification, time_validity_ms}, @desired_state_sorter, nil)
  end

  def get_state() do
    GenStateMachine.call(__MODULE__, :get_state)
  end

  def get_data() do
    GenStateMachine.call(__MODULE__, :get_data)
  end

  def get_state_map() do
    [
      :disarmed,
      :ready,
      :rate,
      :attitude,
      :velocity_alt,
      :position
    ]
    |> Common.Utils.list_to_enum()
  end

  def get_module_health_map() do
    [
      :initializing,
      :ready,
      :dead
    ]
    |> Common.Utils.list_to_enum()
  end

  def get_state_enum(state_name) do
    Map.fetch!(get_state_map(), state_name)
  end

  def get_module_health_enum(module_name) do
    Map.fetch!(get_module_health_map(), module_name)
  end

  defp begin() do
    GenStateMachine.cast(__MODULE__, :begin)
  end


  defp start_state_loop() do
    GenStateMachine.cast(__MODULE__, :start_state_loop)
  end

  defp stop_state_loop() do
    GenStateMachine.cast(__MODULE__, :stop_state_loop)
  end
end
