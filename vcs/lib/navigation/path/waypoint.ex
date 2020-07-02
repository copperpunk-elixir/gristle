defmodule Navigation.Path.Waypoint do
  require Logger
  @enforce_keys [:latitude, :longitude, :speed, :course, :altitude]
  defstruct [:name, :latitude, :longitude, :speed, :course, :altitude, :type, :goto, :dubins]

  @flight_type :flight
  @ground_type :ground
  @climbout_type :climbout
  @approach_type :approach
  @landing_type :landing

  @spec new(float(), float(), number(), number(), number(), atom(), binary(), integer()) :: struct()
  def new(latitude, longitude, altitude, speed, course, type, name \\ "", goto \\ nil) do
    %Navigation.Path.Waypoint{
      name: name,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      speed: speed,
      course: course,
      type: type,
      goto: goto,
      dubins: nil
    }
  end

  @spec new_from_lla(struct(), number, number, atom(), binary(), integer()) ::struct()
  def new_from_lla(lla, speed, course, type, name \\ "", goto \\ nil) do
    new(lla.latitude, lla.longitude, lla.altitude, speed, course, type, name, goto)
  end

  @spec new_flight(struct(), number, number, binary(), integer()) ::struct()
  def new_flight(lla, speed, course, name \\ "", goto \\ nil) do
    new_from_lla(lla, speed, course, @flight_type, name, goto)
  end

  @spec new_ground(struct(), number, number, binary(), integer()) ::struct()
  def new_ground(lla, speed, course, name \\ "", goto \\ nil) do
    new_from_lla(lla, speed, course, @ground_type, name, goto)
  end

  @spec new_climbout(struct(), number, number, binary(), integer()) ::struct()
  def new_climbout(lla, speed, course, name \\ "", goto \\ nil) do
    new_from_lla(lla, speed, course, @climbout_type, name, goto)
  end

  @spec new_landing(struct(), number, number, binary(), integer()) ::struct()
  def new_landing(lla, speed, course, name \\ "", goto \\ nil) do
    new_from_lla(lla, speed, course, @landing_type, name, goto)
  end

  @spec new_approach(struct(), number, number, binary(), integer()) ::struct()
  def new_approach(lla, speed, course, name \\ "", goto \\ nil) do
    new_from_lla(lla, speed, course, @approach_type, name, goto)
  end

  @spec flight_type() :: atom()
  def flight_type() do
    @flight_type
  end

  @spec ground_type() :: atom()
  def ground_type() do
    @ground_type
  end

  @spec climbout_type() :: atom()
  def climbout_type() do
    @climbout_type
  end

  @spec landing_type() :: atom()
  def landing_type() do
    @landing_type
  end

  @spec approach_type() :: atom()
  def approach_type() do
    @approach_type
  end


end
