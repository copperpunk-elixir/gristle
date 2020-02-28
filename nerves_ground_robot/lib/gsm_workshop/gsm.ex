defmodule GsmWorkshop.Gsm do
  use GenStateMachine
  require Logger

  def start_link(name) do
    Logger.debug("Start GsmWorkshop")
    gsm_name = name
    process_key = Comms.ProcessRegistry.get_key_for_module_and_name(__MODULE__, gsm_name)
    name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, gsm_name)
    data = %{process_key: process_key, count: 0}
    GenStateMachine.start_link(__MODULE__, {:not_ready, data}, name: name_in_registry)
  end

  def get_initial_data(process_key) do
    %{
      process_key: process_key,
      count: 0
    }
  end

  def reset_data(data) do
    get_initial_data(data.process_key)
  end

  def add(gsm_name) do
    GenStateMachine.cast(Comms.ProcessRegistry.via_tuple(__MODULE__, gsm_name), :add)
  end

  def ready(gsm_name) do
    GenStateMachine.cast(Comms.ProcessRegistry.via_tuple(__MODULE__, gsm_name), :set_state_ready)
  end

  def get_count(gsm_name) do
    GenStateMachine.call(Comms.ProcessRegistry.via_tuple(__MODULE__, gsm_name), :get_count)
  end

  def handle_event(:cast, :add, :not_ready, data) do
    Logger.debug("#{inspect(data)}")
    :keep_state_and_data
  end

  def handle_event(:cast, :add, :ready, data) do
    {:keep_state, %{data | count: data.count+1}}
  end

  def handle_event(:cast, :set_state_ready, :not_ready, data) do
    data = reset_data(data)
    {:next_state, :ready, data}
  end

  def handle_event(:cast, :set_state_ready, :ready, _data) do
    Logger.debug("Already ready. Ignore")
    :keep_state_and_data
  end

  def handle_event({:call, from}, :get_count, _state, data) do
    {:keep_state, data, [{:reply, from, data.count}]}
  end

  def handle_event({:call, from}, :get_state, state, data) do
    {:keep_state, data, [{:reply, from, state}]}
  end
end
