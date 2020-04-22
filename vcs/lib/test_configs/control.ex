defmodule TestConfigs.Control do
  def get_config_car() do
    %{
      vehicle_type: :Car,
      process_variable_cmd_loop_interval_ms: 20,
    }
  end

  def get_config_plane() do
    %{
      vehicle_type: :Plane,
      process_variable_cmd_loop_interval_ms: 20,
    }
  end

end
