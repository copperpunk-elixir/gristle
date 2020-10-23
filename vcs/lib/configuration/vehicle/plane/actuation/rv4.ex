defmodule Configuration.Vehicle.Plane.Actuation.RV4 do
  @spec get_reversed_actuators() :: list()
  def get_reversed_actuators() do
    [:rudder, :flaps]
  end
end
