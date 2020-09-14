defmodule Configuration.Vehicle.Plane.Actuation do
  @spec get_reversed_actuators(atom()) :: list()
  def get_reversed_actuators(model_type) do
    model_module = Module.concat(__MODULE__, model_type)
    apply(model_module, :get_reversed_actuators, [])
  end
end
