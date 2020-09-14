defmodule Configuration.Vehicle.Plane.Simulation do
  @spec get_pwm_channels(atom()) :: map()
  def get_pwm_channels(model_type) do
    model_module = Module.concat(__MODULE__, model_type)
    apply(model_module, :get_pwm_channels, [])
  end
end
