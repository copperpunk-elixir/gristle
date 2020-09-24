defmodule Navigation.PathPlanner do
  # use GenServer
  require Logger

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

  @spec clear_mission() :: atom()
  def clear_mission() do
    {now, today} = Time.Server.get_time_day()
    iTOW = Telemetry.Ublox.get_itow(now, today)
    Peripherals.Uart.Telemetry.Operator.construct_and_send_message(:clear_mission, [iTOW])
  end
end
