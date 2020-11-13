defmodule Cluster.System do
  use Supervisor
  require Logger

  def start_link(config \\ %{}) do
    Logger.info("Cluster Supervisor start_link()")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children =
      [
        {Cluster.Heartbeat, config[:heartbeat]},
        {Cluster.Network, config[:network]}
      ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end

