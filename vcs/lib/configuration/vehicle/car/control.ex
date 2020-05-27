defmodule Configuration.Vehicle.Car.Control do
  require Logger

  def get_config() do
    %{
      vehicle_type: :Car,
      process_variable_cmd_loop_interval_ms: 20,
    }
  end
end
