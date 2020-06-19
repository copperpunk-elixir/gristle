defmodule Navigation.Waypoint do
  require Logger
  @enforce_keys [:latitude, :longitude, :speed, :course, :altitude]
  defstruct [:name, :latitude, :longitude, :speed, :course, :altitude, :goto, :dubins]

  @earth_radius_m 6371008.8

  @spec new_waypoint(float(), float(), number(), number(), number(), binary(), integer()) :: struct()
  def new_waypoint(latitude, longitude, speed, course, altitude, name \\ "", goto \\ nil) do
    %Navigation.Waypoint{
      name: name,
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      course: course,
      altitude: altitude,
      goto: goto,
      dubins: nil
    }
  end

  @spec calculate_haversine_between_waypoints(struct(), struct()) :: tuple()
  def calculate_haversine_between_waypoints(wp1, wp2) do
    lat1 = wp1.latitude
    lon1 = wp1.longitude
    lat2 = wp2.latitude
    lon2 = wp2.longitude
    dLat = lat2 - lat1
    dLon = lon2 - lon1
    sin_dLat_2 = :math.sin(dLat / 2.0)
    sin_dLon_2 = :math.sin(dLon / 2.0)
    cos_lat1 = :math.cos(lat1)
    cos_lat2 = :math.cos(lat2)
    a = sin_dLat_2 * sin_dLat_2 + cos_lat1 * cos_lat2 * sin_dLon_2 * sin_dLon_2
    c = 2.0 * :math.atan2(:math.sqrt(a), :math.sqrt(1.0 - a))
    distance = @earth_radius_m * c
    bearing = :math.atan2(:math.sin(dLon)*cos_lat2, cos_lat1*:math.sin(lat2) - :math.sin(lat1)*cos_lat2*:math.cos(dLon))
    Logger.debug("bearing: #{Common.Utils.Math.rad2deg(bearing)}")
    {distance * :math.cos(bearing), distance * :math.sin(bearing), distance}
  end

  @pi_4 0.785398163
  @spec calculate_rhumb_line_between_waypoints(struct(), struct()) :: tuple()
  def calculate_rhumb_line_between_waypoints(wp1, wp2) do
    lat1 = wp1.latitude
    lat2 = wp2.latitude
    dpsi = :math.log(:math.tan(@pi_4 + lat2/2)/ :math.tan(@pi_4 + lat1/2))
    dlat = lat2 - lat1
    dlon = wp2.longitude - wp1.longitude
    q =
    if (abs(dpsi) > 0.0000001) do
      dlat/dpsi
    else
      :math.cos(lat1)
    end
    distance = :math.sqrt(dlat*dlat + q*q*dlon*dlon)*@earth_radius_m
    bearing = :math.atan2(dlon, dpsi)
    Logger.debug("bearing: #{Common.Utils.Math.rad2deg(bearing)}")
    {distance * :math.cos(bearing), distance * :math.sin(bearing), distance}
  end
end
