defmodule Navigation.PathPlanner.Plans do
  require Logger

  @spec load_orbit_right(float()) :: atom()
  def load_orbit_right(radius \\ nil) do
    Navigation.PathPlanner.load_orbit(radius, 1)
  end

  @spec load_orbit_left(float()) :: atom()
  def load_orbit_left(radius \\ nil) do
    Navigation.PathPlanner.load_orbit(radius, -1)
  end

  @spec load_orbit_centered_right(float()) :: atom()
  def load_orbit_centered_right(radius \\ nil) do
    Navigation.PathPlanner.load_orbit_centered(radius, 1)
  end

  @spec load_orbit_centered_left(float()) :: atom()
  def load_orbit_centered_left(radius \\ nil) do
    Navigation.PathPlanner.load_orbit_centered(radius, -1)
  end

  @spec load_flight_school(any()) :: atom()
  def load_flight_school(track_type_or_num_wps \\ nil) do
    {track_type, num_wps} = get_track_wps_default(track_type_or_num_wps)
    runway =
      case track_type do
        "none" -> "18L"
        "racetrack_left" -> "18L"
        "hourglass_left" -> "18L"
        "racetrack_right" -> "36R"
        "hourglass_right" -> "36R"
      end
    Logger.debug("track type: #{track_type}")
    Logger.debug("num_wps: #{num_wps}")
    model_type = Common.Utils.Configuration.get_model_type()
    Logger.info("model_type: #{inspect(model_type)}")
    Navigation.PathPlanner.send_complete_mission("flight_school", runway, model_type, track_type, num_wps, true)
  end

  @spec load_seatac_34L(integer()) ::atom()
  def load_seatac_34L(num_wps \\ 1) do
    model_type = Common.Utils.Configuration.get_model_type()
    Navigation.PathPlanner.send_complete_mission("seatac", "34L", model_type, "none", num_wps, true)
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
    Navigation.PathPlanner.send_complete_mission("montague", "36L", model_type, track_type, num_wps, true)
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
    Navigation.PathPlanner.send_complete_mission("montague", "18R",model_type, track_type, num_wps, true)
  end

  @spec get_track_wps_default(any()) :: tuple()
  def get_track_wps_default(track_type_or_num_wps) do
    if (is_binary(track_type_or_num_wps)) do
      {track_type_or_num_wps, 0}
    else
      num_wps = if is_nil(track_type_or_num_wps), do: 0, else: track_type_or_num_wps
      {"none", num_wps}
    end
  end

  @spec load_racetrack_flight_school(atom()) :: atom()
  def load_racetrack_flight_school(direction \\ :left) do
    track_type = if (direction == :left), do: "racetrack_left", else: "racetrack_right"
    model_type = Common.Utils.Configuration.get_model_type()
    Logger.info("model_type: #{inspect(model_type)}")
    Navigation.PathPlanner.send_flight_mission("flight_school", "18L", model_type, track_type, true)
  end

  @spec load_hourglass_flight_school(atom()) :: atom()
  def load_hourglass_flight_school(direction \\ :left) do
    track_type = if (direction == :left), do: "hourglass_left", else: "hourglass_right"
    model_type = Common.Utils.Configuration.get_model_type()
    Logger.info("model_type: #{inspect(model_type)}")
    Navigation.PathPlanner.send_flight_mission("flight_school", "18L", model_type, track_type, true)
  end


  @spec land_flight_school() :: atom()
  def land_flight_school() do
    model_type = Common.Utils.Configuration.get_model_type()
    Logger.info("model_type: #{inspect(model_type)}")
    Navigation.PathPlanner.send_landing_mission("flight_school", "18L", model_type, true)
  end

  # @spec get_airport(any()) :: binary()
  # def get_airport(arg) do
  #   airports = %{
  #     0 => "seatac",
  #     1 => "montague"
  #   }
  #   Common.Utils.get_key_or_value(airports, arg)
  # end

  # @spec get_runway(any()) :: binary()
  # def get_runway(arg) do
  #   runways =
  #     Enum.reduce(1..36, %{}, fn (deg, acc) ->
  #       acc = Map.put(acc, deg, Integer.to_string(deg) |> String.pad_leading(2,"0") |> Kernel.<>("R"))
  #       Map.put(acc, deg*10, Integer.to_string(deg) |> String.pad_leading(2,"0") |> Kernel.<>("L"))
  #     end)
  #   Common.Utils.get_key_or_value(runways, arg)
  # end

  # @spec get_model(any()) :: binary()
  # def get_model(arg) do
  #   aircraft_list  = ["Cessna", "CessnaZ2m", "T28", "T28Z2m"]
  #   aircraft = Enum.reduce(Enum.with_index(aircraft_list), %{}, fn ({value, index}, acc) ->
  #     Map.put(acc, index, value)
  #   end)
  #   # aircraft = %{
  #   #   0 => "Cessna",
  #   #   1 => :T28,
  #   #   2 => :T28Z2m,
  #   #   3 => :CessnaZ2m
  #   # }
  #   Common.Utils.get_key_or_value(aircraft, arg)
  # end

  # @spec get_track(integer()) :: atom()
  # def get_track(arg) do
  #   # tracks = %{
  #   #   0 => :racetrack_left,
  #   #   1 => :racetrack_right,
  #   #   2 => :hourglass,
  #   #   3 => nil
  #   # }
  #   track_list = ["racetrack_left", "racetrack_right", "hourglass", "none"]
  #   tracks = Enum.reduce(Enum.with_index(track_list), %{}, fn ({value, index}, acc) ->
  #     Map.put(acc, index, value)
  #   end)

  #   Common.Utils.get_key_or_value(tracks, arg)
  # end

  # @spec get_confirmation(integer()) :: atom()
  # def get_confirmation(arg) do
  #   if (arg == 1), do: true, else: false
  # end
end
