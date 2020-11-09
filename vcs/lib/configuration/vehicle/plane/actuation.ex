defmodule Configuration.Vehicle.Plane.Actuation do
  @spec get_reversed_actuators(binary()) :: list()
  def get_reversed_actuators(model_type) do
    model_module = Module.concat(__MODULE__, String.to_existing_atom(model_type))
    apply(model_module, :get_reversed_actuators, [])
  end
end
