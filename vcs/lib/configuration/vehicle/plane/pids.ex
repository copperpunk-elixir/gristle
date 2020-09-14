defmodule Configuration.Vehicle.Plane.Pids do
  require Logger

  @spec get_pids(atom()) :: map()
  def get_pids(model_type) do
    model_module = Module.concat(__MODULE__, model_type)
    apply(model_module, :get_pids, [])
  end

  @spec get_attitude(atom()) :: map()
  def get_attitude(model_type) do
    model_module = Module.concat(__MODULE__, model_type)
    apply(model_module, :get_attitude, [])
  end
end
