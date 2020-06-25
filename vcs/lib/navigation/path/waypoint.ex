defmodule Navigation.Path.Waypoint do
  require Logger
  @enforce_keys [:latitude, :longitude, :speed, :course, :altitude]
  defstruct [:name, :latitude, :longitude, :speed, :course, :altitude, :goto, :dubins]

  @spec new(float(), float(), number(), number(), number(), binary(), integer()) :: struct()
  def new(latitude, longitude, speed, course, altitude, name \\ "", goto \\ nil) do
    %Navigation.Path.Waypoint{
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
end
