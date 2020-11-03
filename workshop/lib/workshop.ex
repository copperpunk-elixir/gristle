defmodule Workshop do
  use GenServer
  require Logger

  def start_link() do
    Logger.info("Start Command.Commander GenServer")
    {:ok, pid} = GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    GenServer.cast(__MODULE__, :start_loop)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    y = apply(Params, :get_params, [])
    return_map = %{
      y: y
    }
    # {:ok, return_map}
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast(:start_loop, state) do
    Logger.debug("start loop")
    case :timer.send_interval(1000, self(), :loop) do
      {:ok, timer} ->
        timer
      {_, reason} -> nil
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:loop, state) do
    Logger.debug("loop")
    {:noreply, state}
  end


end
