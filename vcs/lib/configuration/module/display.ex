defmodule Configuration.Module.Display do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    display_vehicle_type =
      case vehicle_type do
        :Car -> :Car
        :FourWheelRobot -> :Car
        :Plane -> :Plane
      end
    %{vehicle_type: display_vehicle_type}
  end
end
