defmodule Configuration.Vehicle.Plane.Actuation.T28 do
  @spec get_reversed_actuators() :: list()
  def get_reversed_actuators() do
    [:elevator, :flaps]
  end
end
