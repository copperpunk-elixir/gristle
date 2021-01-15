defmodule Configuration.Vehicle.Plane.Actuation do
  @spec get_reversed_actuators(binary()) :: list()
  def get_reversed_actuators(model_type) do
    model_module = Module.concat(__MODULE__, String.to_existing_atom(model_type))
    apply(model_module, :get_reversed_actuators, [])
  end

  @spec get_actuator_sorter_intervals() :: list()
  def get_actuator_sorter_intervals() do
    [
      actuator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      indirect_actuator_sorter_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      direct_actuator_sorter_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      indirect_override_sorter_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
    ]
  end

end
