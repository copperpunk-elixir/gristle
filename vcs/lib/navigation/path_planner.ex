defmodule Navigation.PathPlanner do
  # use GenServer
  require Logger


  # def start_link(config) do
  #   Logger.debug("Start Navigation.PathPlanner")
  #   {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  #   GenServer.cast(pid, :begin)
  #   {:ok, pid}
  # end

  # @impl GenServer
  # def init(_config) do
  #   {:ok, %{}}
  # end

  # @impl GenServer
  # def terminate(reason, state) do
  #   Logging.Logger.log_terminate(reason, state, __MODULE__)
  #   state
  # end

  # @impl GenServer
  # def handle_cast(:begin, state) do
  #   Comms.System.start_operator(__MODULE__)
  #   {:noreply, state}
  # end

  # @impl GenServer
  # def handle_cast({:load_mission, mission}, state) do
  #   Logger.info("load mission: #{inspect(mission.name)}")
  #   Comms.Operator.send_local_msg_to_group(
  #     __MODULE__,
  #     {:load_mission, mission},
  #     :load_mission,
  #     self())
  #   {:noreply, state}
  # end

  # @spec load_mission(struct()) :: atom()
  # def load_mission(mission) do
  #   GenServer.cast(Navigation.PathManager, {:load_mission, mission})
  # end

  # @spec load_mission(struct(), atom()) :: atom()
  # def load_mission(mission, module) do
  #   GenServer.cast(Navigation.PathManager, {:load_mission, mission})
  #   # Comms.Operator.send_local_msg_to_group(
  #   #   module,
  #   #   {:load_mission, mission},
  #   #   :load_mission,
  #   #   self())
  # end

  @spec load_seatac_34L(integer()) ::atom()
  def load_seatac_34L(num_wps \\ 1) do
    send_path_mission("seatac", "34L",:Cessna, nil, num_wps, true)
  end

  @spec load_montague_36L(any()) :: atom()
  def load_montague_36L(track_type_or_num_wps) do
    {track_type, num_wps} =
    if (is_atom(track_type_or_num_wps)) do
      {track_type_or_num_wps, 0}
    else
      {nil, track_type_or_num_wps}
    end
    send_path_mission("montague", "36L",:EC1500, track_type, num_wps, true)
  end

  @spec load_montague_18R(any()) :: atom()
  def load_montague_18R(track_type_or_num_wps) do
    {track_type, num_wps} =
    if (is_atom(track_type_or_num_wps)) do
      {track_type_or_num_wps, 0}
    else
      {nil, track_type_or_num_wps}
    end
    send_path_mission("montague", "18R",:EC1500, track_type, num_wps, true)
  end

  @spec send_path_mission(binary(), binary(), atom(), atom(), integer(), boolean()) :: atom()
  def send_path_mission(airport, runway, model_type, track_type, num_wps, confirmation) do
    # airport_code = get_airport(airport)
    # runway_code = get_runway(runway)
    # aircraft_code = get_model(aircraft)
    # track_code = get_track(track)
    # confirm = if confirmation, do: 1, else: 0
    # payload = [airport_code, runway_code, aircraft_code, track_code, num_wps, confirm]
    mission = Navigation.Path.Mission.get_complete_mission(airport, runway, model_type, track_type, num_wps)
    pb_encoded = Navigation.Path.Mission.encode(mission, confirmation)
    Peripherals.Uart.Telemetry.Operator.construct_and_send_proto_message(:mission_proto, pb_encoded)
  end

  @spec get_airport(any()) :: binary()
  def get_airport(arg) do
    airports = %{
      0 => "seatac",
      1 => "montague"
    }
    Common.Utils.get_key_or_value(airports, arg)
  end

  @spec get_runway(any()) :: binary()
  def get_runway(arg) do
    runways =
      Enum.reduce(1..36, %{}, fn (deg, acc) ->
        acc = Map.put(acc, deg, Integer.to_string(deg) |> String.pad_leading(2,"0") |> Kernel.<>("R"))
        Map.put(acc, deg*10, Integer.to_string(deg) |> String.pad_leading(2,"0") |> Kernel.<>("L"))
      end)
    Common.Utils.get_key_or_value(runways, arg)
  end

  @spec get_model(any()) :: binary()
  def get_model(arg) do
    aircraft = %{
      0 => :Cessna,
      1 => :EC1500
    }
    Common.Utils.get_key_or_value(aircraft, arg)
  end

  @spec get_track(integer()) :: atom()
  def get_track(arg) do
    tracks = %{
      0 => :racetrack_left,
      1 => :racetrack_right,
      2 => :hourglass,
      3 => nil
    }
    Common.Utils.get_key_or_value(tracks, arg)
  end

  @spec get_confirmation(integer()) :: atom()
  def get_confirmation(arg) do
    if (arg == 1), do: true, else: false
  end
end
