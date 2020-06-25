defmodule Display.Scenic.PlannerOrigin do
  require Logger
  @enforce_keys [:lat, :lon, :dx_lat, :dy_lon]

  defstruct [:lat, :lon, :dx_lat, :dy_lon]

  @spec new_origin(float(), float(), float(), float()) :: struct()
  def new_origin(lat, lon, dx_lat, dy_lon) do
    %Display.Scenic.PlannerOrigin{
      lat: lat,
      lon: lon,
      dx_lat: dx_lat,
      dy_lon: dy_lon
    }
  end

  @spec get_xy(struct(), float(), float()) :: tuple()
  def get_xy(origin, lat, lon) do
    x = (lat - origin.lat)*origin.dx_lat
    y = (lon - origin.lon)*origin.dy_lon
    {x, y}
  end

  @spec get_dx_dy(struct(), struct(), struct()) :: tuple()
  def get_dx_dy(origin, point1, point2) do
    x = (point2.latitude - point1.latitude)*origin.dx_lat
    y = (point2.longitude - point1.longitude)*origin.dy_lon
    Logger.info("plannerorigin dx/dy: #{x}/#{y}")
    {x, y}
  end
end
