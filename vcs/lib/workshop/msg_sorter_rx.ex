defmodule Workshop.MsgSorterRx do
  use GenServer
  require Logger

  def start_link(name) do
    Logger.debug("Start Workshop.MsgSorterRx")
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
    Logger.debug("#{inspect(self())} received sorter: #{inspect(name)} with value: #{inspect(value)}/#{status}")
    state = put_in(state, [:values, name], value)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:join_message_sorter, name, interval_ms}, state) do
    Logger.debug("MsgSorterRx join sorter: #{inspect(name)}")
    Registry.register(MessageSorterRegistry, {name, :value}, interval_ms)
    # MessageSorter.Sorter.join(name, self(), interval_ms)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:request_value, sorter_name}, state) do
    MessageSorter.Sorter.get_value_async(sorter_name, self())
    Logger.debug("sorterrx request from: #{inspect(self())}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_value, name}, _from, state) do
    {:reply, get_in(state, [:values, name]), state}
  end

  @spec join_message_sorter(any(), any(), integer()) :: atom()
  def join_message_sorter(process_name, sorter_name, interval_ms) do
    GenServer.cast(via_tuple(process_name), {:join_message_sorter, sorter_name, interval_ms})
  end

  @spec get_value(any(), any()) :: any()
  def get_value(process_name, sorter_name) do
    GenServer.call(via_tuple(process_name), {:get_value, sorter_name})
  end

  @spec request_value(any(), any()) :: atom()
  def request_value(process_name, sorter_name) do
    GenServer.cast(via_tuple(process_name), {:request_value, sorter_name})
  end

  def via_tuple(name) do
    Comms.ProcessRegistry.via_tuple(__MODULE__, name)
  end

end
