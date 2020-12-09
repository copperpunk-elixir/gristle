defmodule Navigation.PathPlanner do
  # use GenServer
  require Logger

  @spec load_flight_school(integer()) :: atom()
  def load_flight_school(num_wps \\ 0) do
    model_type = Common.Utils.Configuration.get_model_type()
    Logger.info("model_type: #{inspect(model_type)}")
    send_path_mission("flight_school", "18L", model_type, "none", num_wps, true)
  end

  @spec load_seatac_34L(integer()) ::atom()
  def load_seatac_34L(num_wps \\ 1) do
    model_type = Common.Utils.Configuration.get_model_type()
    send_path_mission("seatac", "34L", model_type, "none", num_wps, true)
  end

  @spec load_montague_36L(any()) :: atom()
  def load_montague_36L(track_type_or_num_wps) do
    {track_type, num_wps} =
    if (is_atom(track_type_or_num_wps)) do
      {track_type_or_num_wps, 0}
    else
      {"none", track_type_or_num_wps}
    end
    model_type = Common.Utils.Configuration.get_model_type()
    send_path_mission("montague", "36L", model_type, track_type, num_wps, true)
  end

  @spec load_montague_18R(any()) :: atom()
  def load_montague_18R(track_type_or_num_wps) do
    {track_type, num_wps} =
    if (is_atom(track_type_or_num_wps)) do
      {track_type_or_num_wps, 0}
    else
      {"none", track_type_or_num_wps}
    end
    model_type = Common.Utils.Configuration.get_model_type()
    send_path_mission("montague", "18R",model_type, track_type, num_wps, true)
  end

  @spec load_orbit_right(float()) :: atom()
  def load_orbit_right(radius \\ nil) do
    load_orbit(radius, 1)
  end

  @spec load_orbit_left(float()) :: atom()
  def load_orbit_left(radius \\ nil) do
    load_orbit(-radius, -1)
  end

  @spec load_orbit(float(), integer()) :: atom()
  def load_orbit(radius, direction) do
    model_type = Common.Utils.Configuration.get_model_type()
    radius = if is_nil(radius) do
      {_turn_rate, _cruise_speed, radius} = Navigation.Path.Mission.calculate_orbit_parameters(model_type, 0.001)
      direction*radius
    else
      radius
    end
    Logger.debug("load orbit: #{radius}")
    send_orbit(model_type, radius)
  end


  @spec send_path_mission(binary(), binary(), binary(), atom(), integer(), boolean()) :: atom()
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

  @spec send_orbit(binary(), float()) :: atom()
  def send_orbit(model_type, radius) do
    model_code = get_model(model_type)
    Logger.debug("send orbit: #{model_code}/#{radius}/#{true}")
    Peripherals.Uart.Telemetry.Operator.construct_and_send_message(:orbit, [model_code, radius, 1])
  end

  @spec send_orbit_confirmation(float(), float(), float(), float()) :: atom()
  def send_orbit_confirmation(radius, latitude, longitude, altitude) do
    Logger.debug("send orbit_confirmation: #{radius}")
    Peripherals.Uart.Telemetry.Operator.construct_and_send_message(:orbit_confirmation, [radius, latitude, longitude, altitude])
  end

  @spec clear_orbit() :: atom()
  def clear_orbit() do
    Logger.debug("clear orbit")
    Peripherals.Uart.Telemetry.Operator.construct_and_send_message(:clear_orbit, [1])
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
    aircraft_list  = ["Cessna", "CessnaZ2m", "T28", "T28Z2m"]
    aircraft = Enum.reduce(Enum.with_index(aircraft_list), %{}, fn ({value, index}, acc) ->
      Map.put(acc, index, value)
    end)
    # aircraft = %{
    #   0 => "Cessna",
    #   1 => :T28,
    #   2 => :T28Z2m,
    #   3 => :CessnaZ2m
    # }
    Common.Utils.get_key_or_value(aircraft, arg)
  end

  @spec get_track(integer()) :: atom()
  def get_track(arg) do
    # tracks = %{
    #   0 => :racetrack_left,
    #   1 => :racetrack_right,
    #   2 => :hourglass,
    #   3 => nil
    # }
    track_list = ["racetrack_left", "racetrack_right", "hourglass", "none"]
    tracks = Enum.reduce(Enum.with_index(track_list), %{}, fn ({value, index}, acc) ->
      Map.put(acc, index, value)
    end)

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
