defmodule Configuration.Vehicle.Plane.Actuation.CessnaZ2m do
  @spec get_reversed_actuators() :: list()
  def get_reversed_actuators() do
    [:elevator]
  end
end
