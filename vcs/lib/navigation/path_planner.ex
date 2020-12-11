defmodule Navigation.PathPlanner do
  # use GenServer
  require Logger

  @spec load_orbit(float(), integer()) :: atom()
  def load_orbit(radius, direction) do
    model_type = Common.Utils.Configuration.get_model_type()
    radius = if is_nil(radius) do
      {_turn_rate, _cruise_speed, radius} = Navigation.Path.Mission.calculate_orbit_parameters(model_type, 0.001)
      direction*radius
    else
      direction*radius
    end
    Logger.debug("load orbit: #{radius}")
    send_orbit(model_type, radius)
  end

  @spec load_orbit_centered(float(), integer()) :: atom()
  def load_orbit_centered(radius, direction) do
    model_type = Common.Utils.Configuration.get_model_type()
    radius = if is_nil(radius) do
      {_turn_rate, _cruise_speed, radius} = Navigation.Path.Mission.calculate_orbit_parameters(model_type, 0.001)
      direction*radius
    else
      direction*radius
    end
    Logger.debug("load orbit centered: #{radius}")
    send_orbit_centered(model_type, radius)
  end

  @spec send_complete_mission(binary(), binary(), binary(), binary(), integer(), boolean()) :: atom()
  def send_complete_mission(airport, runway, model_type, track_type, num_wps, confirmation) do
    mission = Navigation.Path.Mission.get_complete_mission(airport, runway, model_type, track_type, num_wps)
    pb_encoded = Navigation.Path.Mission.encode(mission, confirmation)
    Peripherals.Uart.Telemetry.Operator.construct_and_send_proto_message(:mission_proto, pb_encoded)
  end

  @spec send_flight_mission(binary(), binary(), binary(), binary(), boolean()) :: atom()
  def send_flight_mission(airport, runway, model_type, track_type, confirmation) do
    mission = Navigation.Path.Mission.get_flight_mission(airport, runway, model_type, track_type)
    Logger.debug("flight wps: #{inspect(mission.waypoints)}")
    pb_encoded = Navigation.Path.Mission.encode(mission, confirmation)
    Peripherals.Uart.Telemetry.Operator.construct_and_send_proto_message(:mission_proto, pb_encoded)
  end

  @spec send_landing_mission(binary(), binary(), binary(), boolean()) :: atom()
  def send_landing_mission(airport, runway, model_type, confirmation) do
    mission = Navigation.Path.Mission.get_landing_mission(airport, runway, model_type)
    pb_encoded = Navigation.Path.Mission.encode(mission, confirmation)
    Peripherals.Uart.Telemetry.Operator.construct_and_send_proto_message(:mission_proto, pb_encoded)
  end

  @spec send_orbit(binary(), float()) :: atom()
  def send_orbit(model_type, radius) do
    model_code = get_model(model_type)
    Logger.debug("send orbit: #{model_code}/#{radius}/#{true}")
    Peripherals.Uart.Telemetry.Operator.construct_and_send_message(:orbit, [model_code, radius, 1])
  end

  @spec send_orbit_centered(binary(), float()) :: atom()
  def send_orbit_centered(model_type, radius) do
    model_code = get_model(model_type)
    Logger.debug("send orbit centered: #{model_code}/#{radius}/#{true}")
    Peripherals.Uart.Telemetry.Operator.construct_and_send_message(:orbit_centered, [model_code, radius, 1])
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

  @spec clear_mission() :: atom()
  def clear_mission() do
    {now, today} = Time.Server.get_time_day()
    iTOW = Telemetry.Ublox.get_itow(now, today)
    Peripherals.Uart.Telemetry.Operator.construct_and_send_message(:clear_mission, [iTOW])
  end

  @spec get_model(any()) :: binary()
  def get_model(arg) do
    aircraft_list  = ["Cessna", "CessnaZ2m", "T28", "T28Z2m"]
    aircraft = Enum.reduce(Enum.with_index(aircraft_list), %{}, fn ({value, index}, acc) ->
      Map.put(acc, index, value)
    end)
    Common.Utils.get_key_or_value(aircraft, arg)
  end

end
