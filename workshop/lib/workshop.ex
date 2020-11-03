defmodule Workshop do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Command.Commander GenServer")
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl GenServer
  def init(config) do
    return_map = %{
      x: config.x
    }
    # {:ok, return_map}
    {:ok, %{x: config.x}}
  end


end
