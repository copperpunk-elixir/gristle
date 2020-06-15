defmodule Simulation.XplaneSend do
  require Logger
  use Bitwise
  use GenServer

  @deg2rad 0.017453293
  @rad2deg 57.295779513


  def start_link(config) do
    Logger.debug("Start Simulation.XplaneSend")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        socket: nil,
        port: config.port,
        attitude: %{},
        bodyrate: %{},
        position: %{},
        velocity: %{},
        new_simulation_data_to_publish: false
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    {:ok, socket} = :gen_udp.open(state.port, [broadcast: false, active: true])
    {:noreply, %{state | socket: socket}}
  end

