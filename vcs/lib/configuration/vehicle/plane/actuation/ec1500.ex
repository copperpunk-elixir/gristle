defmodule Configuration.Vehicle.Plane.Actuation.EC1500 do
  @spec apply_reversed_actuators(map()) :: map()
  def apply_reversed_actuators(actuators) do
    reversed_actuators = [:aileron, :elevator]
    Enum.reduce(reversed_actuators, actuators, fn (actuator_name, acc) ->
      if Map.has_key?(acc, actuator_name) do
        put_in(acc, [actuator_name, :reversed], true)
      else
        acc
      end
    end)

  end
end
