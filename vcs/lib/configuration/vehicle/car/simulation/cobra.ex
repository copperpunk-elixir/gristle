defmodule Configuration.Vehicle.Car.Simulation.Cobra do
  @spec get_pwm_channels() :: map()
  def get_pwm_channels() do
    %{
      0 => :rudder,
      1 => :brakes,
      2 => :throttle
    }
  end
end
