defmodule Swarm.Gsm do
  use GenStateMachine
  require Logger

  @default_state_loop_interval_ms 100
  # TODO: desired_control_state_sorter should be defined in the config file instead of here
  @desired_control_state_sorter :desired_control_state
  @control_state_sorter :control_state
  @control_state_classification [0]

  def start_link(config \\ %{}) do
    Logger.debug("Start GSM")
    {:ok, pid} = Common.Utils.start_link_redudant(GenStateMachine, __MODULE__, config)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  def init(config) do
    state = -1
    modules_to_montor = Map.get(config, :modules_to_monitor, [])
    module_health =
      Enum.reduce(modules_to_montor, %{}, fn (module, acc) ->
        Map.put(acc, module, -1) 
      end)
    data = %{
      state_loop_interval_ms: Map.get(config, :state_loop_interval_ms, @default_state_loop_interval_ms),
      state_loop_timer: nil,
      module_health: module_health
    }
    {:ok, state, data}
  end

  def handle_event(:cast, :begin, _state, data) do
    Comms.Operator.start_link(%{name: __MODULE__})
    Comms.Operator.join_group(__MODULE__, @desired_control_state_sorter, self())
    MessageSorter.System.start_link()
    desired_sorter_config = %{
      name: @desired_control_state_sorter,
      default_message_behavior: :last,
      value_type: :number
    }
    MessageSorter.System.start_sorter(desired_sorter_config)
    state_loop_timer = Common.Utils.start_loop(self(), data.state_loop_interval_ms, :state_loop)
    {:keep_state, %{data | state_loop_timer: state_loop_timer}}
  end

  def handle_event(:cast, {:add_desired_control_state, control_state, classification, time_validity_ms}, _state, _data) do
    Logger.debug("cast adcs: #{control_state}")
    MessageSorter.Sorter.add_message(@desired_control_state_sorter, classification, time_validity_ms, control_state)
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
    desired_control_state = MessageSorter.Sorter.get_value(@desired_control_state_sorter)
    # Fake logic
    control_state =
    if desired_control_state != nil && desired_control_state != state do
      desired_control_state
    else
      state
    end
    MessageSorter.Sorter.add_message(@control_state_sorter, @control_state_classification, 2*@default_state_loop_interval_ms, control_state)
    Logger.debug("GSM control state: #{control_state}")
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
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_desired_control_state, control_state, classification, time_validity_ms}, @desired_control_state_sorter, nil)
  end
end
