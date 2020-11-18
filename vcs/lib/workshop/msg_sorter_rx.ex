defmodule Workshop.MsgSorterRx do
  use GenServer
  require Logger

  def start_link(name) do
    Logger.info("Start Workshop.MsgSorterRx: GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, via_tuple(name))
    GenServer.cast(via_tuple(name), {:begin, nil})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, _config}, _state) do
    state = %{
      values: %{}
    }
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, name, value, status}, state) do
    Logger.debug("received sorter: #{inspect(name)} with value: #{inspect(value)}/#{status}")
    state = put_in(state, [:values, name], value)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:join_message_sorter, name, interval_ms}, state) do
    Logger.debug("MsgSorterRx join sorter: #{inspect(name)}")
    # MessageSorter.Sorter.join(name, self(), interval_ms)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:request_value, name}, state) do
    MessageSorter.Sorter.get_value_async(name, self())
    Logger.info("sorterrx request from: #{inspect(self())}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_value, name}, _from, state) do
    {:reply, get_in(state, [:values, name]), state}
  end

  @spec join_message_sorter(any(), integer()) :: atom()
  def join_message_sorter(name, interval_ms) do
    GenServer.cast(via_tuple(name), {:join_message_sorter, name, interval_ms})
  end

  @spec get_value(any()) :: any()
  def get_value(name) do
    GenServer.call(via_tuple(name), {:get_value, name})
  end

  @spec request_value(any()) :: atom()
  def request_value(name) do
    GenServer.cast(via_tuple(name), {:request_value, name})
  end

  def via_tuple(name) do
    Comms.ProcessRegistry.via_tuple(__MODULE__, name)
  end

end
