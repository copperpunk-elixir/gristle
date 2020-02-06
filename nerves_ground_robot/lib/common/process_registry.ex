defmodule Common.ProcessRegistry do
  require Logger

  def start_link do
    Logger.debug("Start ProcessRegistry")
    case Registry.start_link(keys: :unique, name: __MODULE__) do
      {:ok, pid} ->
        Logger.debug("Registry successfully started")
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.debug("Registry already started at #{inspect(pid)}. This is fine.")
        {:ok, pid}
    end
 end

  def via_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
  end

  def child_spec(_) do
    Supervisor.child_spec(
      Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
