defmodule Swarm.Gsm do
  use GenStateMachine
  require Logger

  @default_state_loop_interval_ms 100
  # TODO: desired_state_sorter should be defined in the config file instead of here
  @desired_state_sorter :desired_control_state 

  def start_link(config \\ %{}) do
    {:ok, pid} = Common.Utils.start_link_redudant(GenStateMachine, __MODULE__, config)
    # {:ok, pid} = GenStateMachine.start_link(__MODULE__, config, name: __MODULE__)
    begin()
    start_state_loop()
    {:ok, pid}
  end

  def init(config) do
    state = config.initial_state
    modules_to_montor = Map.get(config, :modules_to_monitor, [])
    module_health =
      Enum.reduce(modules_to_montor, %{}, fn (module, acc) ->
        Map.put(acc, module, :initializing)
      end)
    data = %{
      state_loop_interval_ms: Map.get(config, :state_loop_interval_ms, @default_state_loop_interval_ms),
      state_loop_timer: nil,
      module_health: module_health
    }
    {:ok, state, data}
  end

  def handle_event(:cast, :begin, _state, _data) do
    Comms.Operator.start_link(%{name: __MODULE__})
    Comms.Operator.join_group(__MODULE__, @desired_state_sorter, self())
    MessageSorter.System.start_link()
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

  def handle_event(:cast, {:add_desired_control_state, control_state, classification, time_validity_ms}, _state, _data) do
    Logger.debug("cast adcs: #{control_state}")
    MessageSorter.Sorter.add_message(@desired_state_sorter, classification, time_validity_ms, control_state)
    :keep_state_and_data
  end

  def handle_event({:call, from}, :get_state, state, _data) do
    {:keep_state_and_data, [{:reply, from, state}]}
  end

  def handle_event({:call, from}, :get_data, _state, data) do
    {:keep_state_and_data, [{:reply, from, data}]}
  end

  def handle_event(:info, :state_loop, state, data) do
    # TODO: Add logic to determine if new state is feasible
    Logger.debug("state loop")
    desired_control_state = MessageSorter.Sorter.get_value(@desired_state_sorter)
    # Fake logic
    control_state =
    if desired_control_state != nil do
      control_state = desired_control_state
      Control.Controller.add_control_state(control_state)
      control_state
    else
      state
    end
    {:next_state, control_state, data}
  end

  def get_state() do
    GenStateMachine.call(__MODULE__, :get_state)
  end

  def get_data() do
    GenStateMachine.call(__MODULE__, :get_data)
  end

  # Used only for testing
  def add_desired_control_state(control_state, classification, time_validity_ms) do
    IO.puts("Add desired cs: #{inspect(control_state)}")
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_desired_control_state, control_state, classification, time_validity_ms}, @desired_state_sorter, nil)
  end

  defp begin() do
    GenStateMachine.cast(__MODULE__, :begin)
  end


  defp start_state_loop() do
    GenStateMachine.cast(__MODULE__, :start_state_loop)
  end

  # defp stop_state_loop() do
  #   GenStateMachine.cast(__MODULE__, :stop_state_loop)
  # end
end
