defmodule Configuration.Vehicle.Multirotor.Actuation.QuadX do
  @spec get_reversed_actuators() :: list()
  def get_reversed_actuators() do
    [:elevator]
  end

  @spec get_all_actuator_channels_and_names() :: map()
  def get_all_actuator_channels_and_names() do
    %{
      indirect: %{
        0 => :motor1,
        1 => :motor2,
        2 => :motor3,
        3 => :motor4
      },
      direct: %{
        4 => :gear
      }
    }
  end

  @spec get_min_max_pw() :: tuple()
  def get_min_max_pw() do
    {1000, 2000}
  end
end
