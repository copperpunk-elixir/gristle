defmodule Configuration.Vehicle.Car.Pids do
  require Logger

  @spec get_pids(binary()) :: map()
  def get_pids(model_type) do
    model_module = Module.concat(__MODULE__, String.to_existing_atom(model_type))
    apply(model_module, :get_pids, [])
  end

  @spec get_attitude(binary()) :: map()
  def get_attitude(model_type) do
    model_module = Module.concat(__MODULE__, String.to_existing_atom(model_type))
    apply(model_module, :get_attitude, [])
  end
end
