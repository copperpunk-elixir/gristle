defmodule Common.Utils.Location do
  require Logger

  @pi_4 0.785398163
  @earth_radius_m 6371008.8

  # @spec calculate_haversine_between_waypoints(struct(), struct()) :: tuple()
  # def calculate_haversine_between_waypoints(wp1, wp2) do
  #   lat1 = wp1.latitude
  #   lon1 = wp1.longitude
  #   lat2 = wp2.latitude
  #   lon2 = wp2.longitude
  #   dLat = lat2 - lat1
  #   dLon = lon2 - lon1
  #   sin_dLat_2 = :math.sin(dLat / 2.0)
  #   sin_dLon_2 = :math.sin(dLon / 2.0)
  #   cos_lat1 = :math.cos(lat1)
  #   cos_lat2 = :math.cos(lat2)
  #   a = sin_dLat_2 * sin_dLat_2 + cos_lat1 * cos_lat2 * sin_dLon_2 * sin_dLon_2
  #   c = 2.0 * :math.atan2(:math.sqrt(a), :math.sqrt(1.0 - a))
  #   distance = @earth_radius_m * c
  #   bearing = :math.atan2(:math.sin(dLon)*cos_lat2, cos_lat1*:math.sin(lat2) - :math.sin(lat1)*cos_lat2*:math.cos(dLon))
  #   Logger.debug("bearing: #{Common.Utils.Math.rad2deg(bearing)}")
  #   {distance * :math.cos(bearing), distance * :math.sin(bearing), distance}
  # end

  @spec dx_dy_between_points(struct(), struct()) :: tuple()
  def dx_dy_between_points(wp1, wp2) do
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
    # distance = :math.sqrt(dlat*dlat + q*q*dlon*dlon)*@earth_radius_m
    # bearing = :math.atan2(dlon, dpsi)
    # Logger.debug("bearing: #{Common.Utils.Math.rad2deg(bearing)}")
    {dlat*@earth_radius_m, q*dlon*@earth_radius_m}
    # {distance * :math.cos(bearing), distance * :math.sin(bearing), distance}
  end

  @spec lat_lon_from_point(float(), float(), float(), float()) :: tuple()
  def lat_lon_from_point(lat1, lon1, dx, dy) do
    dlat = dx/@earth_radius_m
    lat2 = lat1 + dlat
    dpsi = :math.log(:math.tan(@pi_4 + lat2/2)/ :math.tan(@pi_4 + lat1/2))
    q =
    if (abs(dpsi) > 0.0000001) do
      dlat/dpsi
    else
      :math.cos(lat1)
    end
    dlon = (dy/@earth_radius_m) / q
    lon2 = lon1 + dlon
    {lat2, lon2}
  end

  @spec lat_lon_from_point(map(), float(), float()) :: tuple()
  def lat_lon_from_point(lat_lon_alt, dx, dy) do
    lat_lon_from_point(lat_lon_alt.latitude, lat_lon_alt.longitude, dx, dy)
  end

  @spec lat_lon_from_point(tuple(), tuple()) :: tuple()
  def lat_lon_from_point(origin, point) do
    {lat1, lon1} = origin
    {dx, dy} = point
    lat_lon_from_point(lat1, lon1, dx, dy)
  end

  @spec lat_lon_from_point_with_distance(struct(), float(), float()) :: tuple()
  def lat_lon_from_point_with_distance(lat_lon_alt, distance, bearing) do
    dx = distance*:math.cos(bearing)
    dy = distance*:math.sin(bearing)
    # Logger.info("dx/dy: #{dx}/#{dy}")
    lat_lon_from_point(lat_lon_alt.latitude, lat_lon_alt.longitude, dx, dy)
  end

  @spec lat_lon_from_point_with_distance(float(), float(), float(), float()) :: tuple()
  def lat_lon_from_point_with_distance(lat1, lon1, distance, bearing) do
    dx = distance*:math.cos(bearing)
    dy = distance*:math.sin(bearing)
    lat_lon_from_point(lat1, lon1, dx, dy)
  end
end
