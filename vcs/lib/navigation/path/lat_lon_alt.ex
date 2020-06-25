defmodule Navigation.Path.LatLonAlt do
  require Logger
  @enforce_keys [:latitude, :longitude, :altitude]
  defstruct [:latitude, :longitude, :altitude]

  @spec new(float(), float(), float()) :: struct()
  def new(lat, lon, alt) do
    %Navigation.Path.LatLonAlt{
      latitude: lat,
      longitude: lon,
      altitude: alt
    }
  end

  @spec new(float(), float()) :: struct()
  def new(lat, lon) do
    new(lat, lon, 0)
  end

  @spec print_deg(struct()) :: atom()
  def print_deg(lla, level \\ :info) do
    lat_str = Common.Utils.eftb(Common.Utils.Math.rad2deg(lla.latitude), 5)
    lon_str = Common.Utils.eftb(Common.Utils.Math.rad2deg(lla.longitude), 5)
    alt_str = Common.Utils.eftb(lla.altitude, 1)
    print_str = "lat/lon/alt: #{lat_str}/#{lon_str}/#{alt_str}"
    case level do
      :info -> Logger.info(print_str)
      :debug -> Logger.debug(print_str)
      :warn -> Logger.warn(print_str)
    end
  end
end
