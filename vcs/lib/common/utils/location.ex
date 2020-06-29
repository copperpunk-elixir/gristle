defmodule Common.Utils.Location do
  require Logger

  @pi_4 0.785398163
  @earth_radius_m 6371008.8

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
    {dlat*@earth_radius_m, q*dlon*@earth_radius_m}
  end

  @spec dx_dy_between_points(float(), float(), float(), float()) :: tuple()
  def dx_dy_between_points(lat1, lon1, lat2, lon2) do
    dx_dy_between_points(Navigation.Utils.LatLonAlt.new(lat1, lon1), Navigation.Utils.LatLonAlt.new(lat2, lon2))
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

  @spec point_from_point_with_dx_dy(struct(), float(), float()) :: struct()
  def point_from_point_with_dx_dy(lla, dx, dy) do
    {lat, lon} = lat_lon_from_point(lla.latitude, lla.longitude, dx, dy)
    Navigation.Utils.LatLonAlt.new(lat, lon, lla.altitude)
  end

  # @spec point_from_poith_with_distance(struct(), float(), float()) :: struct()

end
