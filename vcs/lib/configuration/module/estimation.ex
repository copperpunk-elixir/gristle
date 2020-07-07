defmodule Configuration.Module.Estimation do
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, node_type) do
    %{
      estimator: %{
        imu_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        imu_loop_timeout_ms: 1000,
        ins_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        ins_loop_timeout_ms: 2000,
        telemetry_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      },
      children: get_estimation_children(node_type)
    }
  end

  @spec get_razor_input_config() :: map()
  def get_razor_input_config() do
    %{
      device_description: "FT232",
      imu_loop_interval_ms: 500,
      ins_loop_interval_ms: 1000,
      heading_loop_interval_ms: 2000
    }
  end

  @spec get_estimation_children(atom()) :: list()
  def get_estimation_children(node_type) do
    case node_type do
      :all -> [{Peripherals.Uart.VnIns, %{}}]
      :sim -> [{Peripherals.Uart.RazorInput, get_razor_input_config()}]
      _other -> []
    end
  end
end
