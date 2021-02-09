defmodule Configuration.Vehicle.Plane.Actuation.T28 do
  @spec get_reversed_actuators() :: list()
  def get_reversed_actuators() do
    [:elevator, :flaps]
  end

  @spec get_all_actuator_channels_and_names() :: map()
  def get_all_actuator_channels_and_names() do
    %{
      indirect: %{
        0 => :aileron,
        1 => :elevator,
        2 => :throttle,
        3 => :rudder},
      direct: %{
        4 => :flaps,
      }

    }
  end

  @spec get_min_max_pw() :: tuple()
  def get_min_max_pw() do
    {1100, 1900}
  end

end
