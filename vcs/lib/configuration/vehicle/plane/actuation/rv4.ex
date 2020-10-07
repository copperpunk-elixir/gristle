defmodule Configuration.Vehicle.Plane.Actuation.RV4 do
  @spec get_reversed_actuators() :: list()
  def get_reversed_actuators() do
    [:aileron, :elevator, :flaps]
  end
end
