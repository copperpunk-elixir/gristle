defmodule Navigation.PathPlanner do
  # use GenServer
  require Logger
  @telemetry_module Peripherals.Uart.Telemetry.Operator

  @spec load_orbit(float) :: atom()
  def load_orbit(radius) do
    Logger.debug("load orbit: #{radius}")
    send_orbit(radius)
  end

  @spec load_orbit_centered(float()) :: atom()
  def load_orbit_centered(radius \\ 0) do
    # model_type = Common.Utils.Configuration.get_model_type()
    Logger.debug("load orbit centered: #{radius}")
    send_orbit_centered(radius)
  end

  @spec send_complete_mission(binary(), binary(), binary(), binary(), integer(), boolean()) :: atom()
  def send_complete_mission(airport, runway, model_type, track_type, num_wps, confirmation) do
    mission = Navigation.Path.Mission.get_complete_mission(airport, runway, model_type, track_type, num_wps)
    pb_encoded = Navigation.Path.Mission.encode(mission, confirmation)
    Peripherals.Uart.Generic.construct_and_send_proto_message(:mission_proto, pb_encoded, @telemetry_module)
  end

  @spec send_lawnmower_mission(binary(), binary(), binary(), integer(), float(), float(), boolean()) :: atom()
  def send_lawnmower_mission(airport, runway, model_type, num_rows, row_width, row_length, confirmation) do
    mission = Navigation.Path.Mission.get_lawnmower_mission(airport, runway, model_type, num_rows, row_width, row_length)
    pb_encoded = Navigation.Path.Mission.encode(mission, confirmation)
    Peripherals.Uart.Generic.construct_and_send_proto_message(:mission_proto, pb_encoded, @telemetry_module)
  end

  @spec send_flight_mission(binary(), binary(), binary(), binary(), boolean()) :: atom()
  def send_flight_mission(airport, runway, model_type, track_type, confirmation) do
    mission = Navigation.Path.Mission.get_flight_mission(airport, runway, model_type, track_type)
    Logger.debug("flight wps: #{inspect(mission.waypoints)}")
    pb_encoded = Navigation.Path.Mission.encode(mission, confirmation)
    Peripherals.Uart.Generic.construct_and_send_proto_message(:mission_proto, pb_encoded, @telemetry_module)
  end

  @spec send_landing_mission(binary(), binary(), binary(), boolean()) :: atom()
  def send_landing_mission(airport, runway, model_type, confirmation) do
    mission = Navigation.Path.Mission.get_landing_mission(airport, runway, model_type)
    pb_encoded = Navigation.Path.Mission.encode(mission, confirmation)
    Peripherals.Uart.Generic.construct_and_send_proto_message(:mission_proto, pb_encoded, @telemetry_module)
  end

  @spec send_orbit(float()) :: atom()
  def send_orbit(radius) do
    # model_code = get_model(model_type)
    Logger.debug("send orbit: #{radius}/#{true}")
    Peripherals.Uart.Generic.construct_and_send_message(:orbit_inline, [radius, 1], @telemetry_module)
  end

  @spec send_orbit_centered(float()) :: atom()
  def send_orbit_centered(radius) do
    # model_code = get_model(model_type)
    Logger.debug("send orbit centered: #{radius}/#{true}")
    Peripherals.Uart.Generic.construct_and_send_message(:orbit_centered, [radius, 1], @telemetry_module)
  end

  @spec send_orbit_confirmation(float(), float(), float(), float()) :: atom()
  def send_orbit_confirmation(radius, latitude, longitude, altitude) do
    Logger.debug("send orbit_confirmation: #{radius}")
    Peripherals.Uart.Generic.construct_and_send_message(:orbit_confirmation, [radius, latitude, longitude, altitude], @telemetry_module)
  end

  @spec clear_orbit() :: atom()
  def clear_orbit() do
    Logger.debug("clear orbit")
    Peripherals.Uart.Generic.construct_and_send_message(:clear_orbit, [1], @telemetry_module)
  end

  @spec clear_mission() :: atom()
  def clear_mission() do
    {now, today} = Time.Server.get_time_day()
    iTOW = Telemetry.Ublox.get_itow(now, today)
    Peripherals.Uart.Generic.construct_and_send_message(:clear_mission, [iTOW], @telemetry_module)
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
