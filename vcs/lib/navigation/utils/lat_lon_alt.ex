defmodule Navigation.Utils.LatLonAlt do
  require Logger
  @enforce_keys [:latitude, :longitude, :altitude]
  defstruct [:latitude, :longitude, :altitude]

  @spec new(float(), float(), float()) :: struct()
  def new(lat, lon, alt) do
    %Navigation.Utils.LatLonAlt{
      latitude: lat,
      longitude: lon,
      altitude: alt
    }
  end

  @spec new(float(), float()) :: struct()
  def new(lat, lon) do
    new(lat, lon, 0)
  end

  @spec to_string(struct()) :: binary()
  def to_string(lla) do
    lat_str = Common.Utils.eftb(Common.Utils.Math.rad2deg(lla.latitude), 5)
    lon_str = Common.Utils.eftb(Common.Utils.Math.rad2deg(lla.longitude), 5)
    alt_str = Common.Utils.eftb(lla.altitude, 1)
    "lat/lon/alt: #{lat_str}/#{lon_str}/#{alt_str}"
  end
end
