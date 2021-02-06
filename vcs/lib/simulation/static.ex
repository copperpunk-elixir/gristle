defmodule Simulation.Static do
  require Logger
  use Bitwise
  use GenServer

  # @rad2deg 57.295779513
  @default_latitude 41.769201
  @default_longitude -122.506394
  @default_altitude 1186.0
  @default_agl 1.23
  @default_velocity %{north: 0.0, east: 0.0, down: 0.0}
  @default_attitude %{roll: 0.0, pitch: 0.0524, yaw: -0.1048}
  @default_bodyrate %{rollrate: 0.174, pitchrate: -0.348, yawrate: 0.0524}

  def start_link(config) do
    Logger.info("Start Simulation.Realflight GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    state = %{
      attitude: @default_attitude,
      bodyrate: @default_bodyrate,
      position: Common.Utils.LatLonAlt.new_deg(@default_latitude, @default_longitude, @default_altitude),
      velocity: @default_velocity,
      agl: @default_agl,
      airspeed: 0.0,
    }

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :pwm_input, self())
    Common.Utils.start_loop(self(), config[:sim_loop_interval_ms], :publish_simulation_data)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:pwm_input, scaled_values}, state) do
    # Logger.info("scaled: #{Common.Utils.eftb_list(scaled_values, 3)}")
    {:noreply, state}
  end


  @impl GenServer
  def handle_info(:publish_simulation_data, state) do
    # state = exchange_data(state, state.rcin)
    Peripherals.Uart.Estimation.VnIns.Operator.publish_vn_message(state.bodyrate, state.attitude, state.velocity, state.position)
    if !Enum.empty?(state.attitude) and (:rand.uniform(5) == 1) do
      range_meas =state.agl/(:math.cos(state.attitude.roll)*:math.cos(state.attitude.pitch))
      range_meas = if (range_meas < 0), do: 0, else: range_meas
      Peripherals.Uart.Estimation.TerarangerEvo.Operator.publish_range(range_meas)
    end
    {:noreply, state}
  end
end
