defmodule Watchdog.Active do
  use GenServer
  require Logger

  def start_link(config) do
    name = config.name
    Logger.info("Start Watchdog.Active: #{name} GenServer")
    {:ok, process_id} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, via_tuple(name))
    GenServer.cast(via_tuple(name), :begin)
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    loop_interval_ms = 5*config.expected_interval_ms
    {:ok, %{
        name: config.name,
        expected_interval_ms: config.expected_interval_ms,
        loop_interval_ms: loop_interval_ms,
        local_or_global: config.local_or_global,
        count: loop_interval_ms,
        fed: false
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    name = Module.concat(__MODULE__, state.name)
    Logging.Logger.log_terminate(reason, state, name)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator({__MODULE__, state.name})
    send_status(state.name, state.local_or_global, false)
    Common.Utils.start_loop(self(), state.loop_interval_ms, :loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:feed, state) do
    count = Common.Utils.Math.constrain(state.count-2*state.expected_interval_ms, 0, 2*state.loop_interval_ms)
    {:noreply, %{state | count: count}}
  end

  @impl GenServer
  def handle_call(:is_fed, _from, state) do
    {:reply, state.fed, state}
  end

  @impl GenServer
  def handle_info(:loop, state) do
    fed = if (state.count >= state.loop_interval_ms) do
      false
    else
      true
    end
    # Only send watchdog status if there was a change of state
    if (fed != state.fed) do
      send_status(state.name, state.local_or_global, fed)
    end
    # Logger.debug("#{state.name} count: #{state.count}")
    {:noreply, %{state | count: state.count + state.loop_interval_ms, fed: fed}}
  end

  @spec send_status(atom(), atom(), boolean()) ::atom()
  def send_status(name, local_or_global, is_fed) do
    Logger.warn("#{name} watchdog is fed?: #{is_fed}")
    function =
      case local_or_global do
        :local -> :send_local_msg_to_group
        :global -> :send_global_msg_to_group
    end
    apply(Comms.Operator, function,[{__MODULE__, name}, {{:watchdog_status, name}, is_fed}, self()])
  end

  @spec feed(atom()) :: atom()
  def feed(name) do
    GenServer.cast(via_tuple(name), :feed)
  end

  @spec is_fed?(atom()) :: boolean()
  def is_fed?(name) do
    GenServer.call(via_tuple(name), :is_fed)
  end

  def via_tuple(name) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,name)
  end

end
