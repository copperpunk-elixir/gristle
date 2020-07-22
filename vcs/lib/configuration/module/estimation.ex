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

  @spec get_cp_ins_config() :: map()
  def get_cp_ins_config() do
    %{
      ublox_device_description: "FT232",
      antenna_offset: Common.Constants.pi_2(),
      imu_loop_interval_ms: 10,
      ins_loop_interval_ms: 200,
      heading_loop_interval_ms: 200
    }
  end

  @spec get_vn_ins_config(atom()) :: map()
  def get_vn_ins_config(node_type) do
    {device_desc, baud} =
      case node_type do
        # :sim -> {"SFE SAMD21", 115_200}
        :sim -> {"RedBoard", 115_200}
        _other -> {"RedBoard", 115_200}
      end
    %{
      vn_device_description: device_desc,
      baud: baud
    }
  end

  @spec get_estimation_children(atom()) :: list()
  def get_estimation_children(node_type) do
    case node_type do
      :all -> [{Peripherals.Uart.VnIns, get_vn_ins_config(node_type)}]
      # :sim -> [{Peripherals.Uart.CpIns, get_cp_ins_config()}]
      :sim -> [{Peripherals.Uart.VnIns, get_vn_ins_config(node_type)}, {Peripherals.Uart.CpIns, get_cp_ins_config()}]
      _other -> []
    end
  end
end
