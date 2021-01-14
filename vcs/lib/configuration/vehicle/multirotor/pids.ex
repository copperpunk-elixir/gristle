defmodule Configuration.Vehicle.Multirotor.Pids do
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

  @spec get_motor_moments(binary()) :: map()
  def get_motor_moments(model_type) do
    model_module = Module.concat(__MODULE__, String.to_existing_atom(model_type))
    apply(model_module, :get_motor_moments, [])
  end
end