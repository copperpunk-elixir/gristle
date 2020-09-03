defmodule Configuration.Vehicle.Plane.Simulation.Cessna do
  @spec get_pwm_channels() :: map()
  def get_pwm_channels() do
    %{
        0 => :aileron,
        1 => :elevator,
        2 => :throttle,
        3 => :rudder
    }
  end
end
