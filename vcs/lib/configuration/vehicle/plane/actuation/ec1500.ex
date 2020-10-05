defmodule Configuration.Vehicle.Plane.Actuation.EC1500 do
  @spec get_reversed_actuators() :: list()
  def get_reversed_actuators() do
    [:aileron, :elevator, :flaps]
  end
end
