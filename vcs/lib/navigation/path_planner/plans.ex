defmodule Navigation.PathPlanner.Plans do
  require Logger

  @spec load_orbit_right(float()) :: atom()
  def load_orbit_right(radius \\ 0.001) do
    Navigation.PathPlanner.load_orbit(abs(radius))
  end

  @spec load_orbit_left(float()) :: atom()
  def load_orbit_left(radius \\ -0.001) do
    Navigation.PathPlanner.load_orbit(-abs(radius))
  end

  @spec load_orbit_centered_right(float()) :: atom()
  def load_orbit_centered_right(radius \\ 0.001) do
    Navigation.PathPlanner.load_orbit_centered(abs(radius))
  end

  @spec load_orbit_centered_left(float()) :: atom()
  def load_orbit_centered_left(radius \\ -0.001) do
    Navigation.PathPlanner.load_orbit_centered(-abs(radius))
  end

  @spec load_flight_school(any(), boolean()) :: atom()
  def load_flight_school(track_type_or_num_wps \\ nil, relative \\ false) do
    {track_type, num_wps} = get_track_wps_default(track_type_or_num_wps)
    runway =
      case track_type do
        "heli" -> "9L"
        "none" -> "18L"
        "racetrack_left" -> "18L"
        "hourglass_left" -> "18L"
        "racetrack_right" -> "36R"
        "hourglass_right" -> "36R"
      end
    model_type = Common.Utils.Configuration.get_model_type()
    track_type = if track_type == "heli", do: "none", else: track_type
    if relative do
      Gcs.Operator.load_mission_relative("flight_school", runway, model_type, track_type, num_wps, true)
    else
      Navigation.PathPlanner.send_complete_mission("flight_school", runway, model_type, track_type, num_wps, true)
    end
  end

  @spec load_flight_school_relative(any()) :: atom()
  def load_flight_school_relative(track_type_or_num_wps \\ nil) do
    load_flight_school(track_type_or_num_wps, true)
  end

  @spec load_lawnmower(binary(), boolean()) :: atom()
  def load_lawnmower(airport \\ "cone_field", relative \\ false) do
    {runway, num_rows, row_width, row_length} =
      case airport do
        "cone_field" -> {"36L", 4, 8, 60}
      end
    model_type = Common.Utils.Configuration.get_model_type()
    if relative do
      raise "Relative not supported yet"
      # Gcs.Operator.load_mission_relative("flight_school", runway, model_type, track_type, num_wps, true)
    else
      Navigation.PathPlanner.send_lawnmower_mission("cone_field", runway, model_type, num_rows, row_width, row_length, true)
    end
  end

  @spec load_seatac_34L(integer()) ::atom()
  def load_seatac_34L(num_wps \\ 1) do
    model_type = Common.Utils.Configuration.get_model_type()
    Navigation.PathPlanner.send_complete_mission("seatac", "34L", model_type, "none", num_wps, true)
  end

  @spec load_montague_36L(any()) :: atom()
  def load_montague_36L(track_type_or_num_wps) do
    {track_type, num_wps} = get_track_wps_default(track_type_or_num_wps)
    model_type = Common.Utils.Configuration.get_model_type()
    Navigation.PathPlanner.send_complete_mission("montague", "36L", model_type, track_type, num_wps, true)
  end

  @spec load_montague_18R(any()) :: atom()
  def load_montague_18R(track_type_or_num_wps) do
    {track_type, num_wps} = get_track_wps_default(track_type_or_num_wps)
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
    load_flight_school(track_type)
  end

  @spec load_hourglass_flight_school(atom()) :: atom()
  def load_hourglass_flight_school(direction \\ :left) do
    track_type = if (direction == :left), do: "hourglass_left", else: "hourglass_right"
    load_flight_school(track_type)
  end

  @spec land_flight_school(atom()) :: atom()
  def land_flight_school(direction \\ :left) do
    runway = if (direction == :left), do: "18L", else: "36R"
    model_type = Common.Utils.Configuration.get_model_type()
    Logger.info("model_type: #{inspect(model_type)}")
    Navigation.PathPlanner.send_landing_mission("flight_school", runway, model_type, true)
  end
end
