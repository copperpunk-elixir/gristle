defmodule Workshop.RelativeLocationLoop do
  use GenServer
  require Logger

  def start_link(airport \\ "flight_school", runway \\ "18L") do
    Logger.debug("Start RelativeLocationLoop")
    config = [airport: airport, runway: runway]
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, state) do
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:estimation_values, :position_velocity}, self())
    Common.Utils.start_loop(self(), 1000, :print_location_loop)
    {origin, _} = Navigation.Path.Mission.get_runway_position_heading(config[:airport], config[:runway])
    state = Map.put(state, :origin, origin)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:estimation_values, :position_velocity}, position, _velocity, _dt}, state) do
    state = Map.put(state, :position, position)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:print_location_loop, state) do
    unless is_nil(Map.get(state, :position)) do
      {dx, dy} = Common.Utils.Location.dx_dy_between_points(state.origin, state.position)
      dz = state.position.altitude - state.origin.altitude
      Logger.debug("#{Common.Utils.eftb(dx,2)}/#{Common.Utils.eftb(dy,2)}/#{Common.Utils.eftb(dz,2)}")
    end
    {:noreply, state}
  end
end
