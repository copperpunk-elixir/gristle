defmodule Configuration.Vehicle.Multirotor.Actuation.QuadX do
  @spec get_reversed_actuators() :: list()
  def get_reversed_actuators() do
    [:elevator]
  end
end
