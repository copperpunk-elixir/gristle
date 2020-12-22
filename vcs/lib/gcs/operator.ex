defmodule Gcs.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Gcs.Operator GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(pid, {:begin, config})
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
  def handle_cast({:begin, _config}, _state) do
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:telemetry, :pvat}, self())
    state = %{}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:telemetry, :pvat}, position, velocity, attitude}, state) do
    state = Map.put(state, :position, position)
    |> Map.put(:velocity, velocity)
    |> Map.put(:attitude, attitude)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:load_mission_relative, airport, runway, model_type, track_type, num_wps, confirmation}, state) do
    position = Map.get(state, :position)
    course = get_in(state,[:velocity, :course])
    unless is_nil(position) or is_nil(course) do
      mission = Navigation.Path.Mission.get_complete_mission(airport, runway, model_type, track_type, num_wps, position, course)
      pb_encoded = Navigation.Path.Mission.encode(mission, confirmation)
      Peripherals.Uart.Generic.construct_and_send_proto_message(:mission_proto, pb_encoded, Telemetry)
    else
      Logger.warn("No position/course. Cannot send relative mission")
    end
    {:noreply, state}
  end

  @spec load_mission_relative(binary(), binary(), binary(), binary(), integer(), boolean()) :: atom()
  def load_mission_relative(airport, runway, model_type, track_type, num_wps, confirmation) do
    Logger.debug("GCS load mission relative")
    GenServer.cast(__MODULE__, {:load_mission_relative, airport, runway, model_type, track_type, num_wps, confirmation})
  end

end
