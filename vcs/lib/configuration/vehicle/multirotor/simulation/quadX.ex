defmodule Configuration.Vehicle.Multirotor.Simulation.QuadX do
  @spec get_pwm_channels() :: map()
  def get_pwm_channels() do
    %{
      0 => :motor1,
      1 => :motor2,
      2 => :motor3,
      3 => :motor4
    }
  end
end
