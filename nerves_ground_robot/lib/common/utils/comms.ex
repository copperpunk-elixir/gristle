defmodule Common.Utils.Comms do
  require Logger

  def start_registry_list(registry_list) do
    registry_list = Common.Utils.Enum.assert_list(registry_list)
    Enum.each(registry_list, fn registry ->
      start_registry(registry)
    end)
  end

  def start_registry(registry) do
    Logger.debug("Start Registry for #{registry}")
    case Registry.start_link(keys: :duplicate, name: registry, partitions: System.schedulers_online()) do
      {:ok, _} -> Logger.debug("Registry successfully started")
      {:error, {:already_started, pid}} -> Logger.debug("Registry already started at #{inspect(pid)}. This is fine.")
    end
  end

  def register_subscriber_list(registry, subscriber_list) do
    subscriber_list = Common.Utils.Enum.assert_list(subscriber_list)
    Enum.each(subscriber_list, fn registry_params ->
      register_subscriber(registry, registry_params)
    end)
  end

  def register_subscriber(registry, topic) do
    # case registry_params do
    # {topic, callback_topic} ->
    #   Logger.debug("#{registry}/#{topic}/#{callback_topic}")
    #   Registry.register(registry, topic, callback_topic)
    # topic ->
    Logger.debug("register to #{registry}/#{topic}")
    Registry.register(registry, topic, [])
    # end
  end

  def unregister_subscriber(registry, topic) do
    Logger.debug("unregister from #{registry}/#{topic}")
    Registry.unregister(registry, topic)
  end

  def get_subscribers_for_registry_and_topic(registry, topic) do
    subscribers_and_values = Registry.lookup(registry, topic)
    subscribers =
      Enum.reduce(subscribers_and_values, [], fn ({sub, value}, acc) ->
        [sub | acc]
      end)
    subscribers
  end

  def dispatch_cast(registry, topic, message) do
    Registry.dispatch(registry, topic, fn entries ->
      for {pid, _} <- entries do
        GenServer.cast(pid, message)
      end
    end)
  end

  def global_dispatch_cast(group, message, sender \\ nil) do
    Enum.each(:pg2.get_members(group), fn pid ->
      if pid != sender do
        # Logger.debug("Send #{inspect(message)} to #{inspect(pid)}")
        GenServer.cast(pid, {:global, message})
      end
    end)
  end
end
