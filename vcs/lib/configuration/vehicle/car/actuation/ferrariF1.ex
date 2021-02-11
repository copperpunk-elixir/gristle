defmodule Configuration.Vehicle.Car.Actuation.FerrariF1 do
  @spec get_reversed_actuators() :: list()
  def get_reversed_actuators() do
    []
  end

  @spec get_all_actuator_channels_and_names() :: map()
  def get_all_actuator_channels_and_names() do
    %{
      indirect: %{
        0 => :rudder,
        1 => :brake,
        2 => :throttle,
      },
      direct: %{
      }
    }
  end

  @spec get_min_max_pw() :: tuple()
  def get_min_max_pw() do
    {1000, 2000}
  end
end
