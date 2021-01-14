defmodule Configuration.Vehicle.Multirotor.Simulation do
  @spec get_pwm_channels(binary()) :: map()
  def get_pwm_channels(model_type) do
    model_module = Module.concat(__MODULE__, String.to_existing_atom(model_type))
    apply(model_module, :get_pwm_channels, [])
  end
end
