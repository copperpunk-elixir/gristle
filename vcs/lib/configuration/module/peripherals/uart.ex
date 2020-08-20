defmodule Configuration.Module.Peripherals.Uart do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, node_type) do
    peripherals = Common.Utils.Configuration.get_uart_peripherals()
    Logger.info("peripherals: #{inspect(peripherals)}")
    Enum.reduce(peripherals, %{}, fn (module, acc) ->
      {module_key, module_config} =
        case module do
          :FrskyRx -> {Command.Frsky, get_frsky_rx_config()}
          :FrskyServo -> {Actuation, get_actuation_config(module)}
          :PololuServo -> {Actuation, get_actuation_config(module)}
          :TerarangerEvo -> {Estimation.TerarangerEvo, get_teraranger_evo_config(node_type)}
          :VnIns -> {Estimation.VnIns, get_vn_ins_config(node_type)}
          :Xbee -> {Telemetry, get_telemetry_config(module)}
          :Sik -> {Telemetry, get_telemetry_config(module)}
        end
      Map.put(acc, module_key, module_config)
    end)
  end

  @spec get_frsky_rx_config() :: map()
  def get_frsky_rx_config() do
    %{
      device_description: "Feather M0",
    }
  end

  @spec get_actuation_config(atom()) :: map()
  def get_actuation_config(module) do
    {interface_module, device_desc} =
      case module do
        :FrskyServo -> {Peripherals.Uart.Actuation.Frsky.Device, "Feather M0"}
        :PololuServo -> {Peripherals.Uart.Actuation.Pololu.Device, "Pololu"}
      end
    %{
      interface_module: interface_module,
      driver_config: %{
        device_description: device_desc,
        baud: 115_200,
        write_timeout: 1,
        read_timeout: 1
      }
    }
  end

  @spec get_teraranger_evo_config(atom()) :: map()
  def get_teraranger_evo_config(node_type) do
    device_description =
      case node_type do
        :sim -> "FT232R"
        _other -> "STM32"
      end
    %{
      device_description: device_description
    }
  end

  @spec get_vn_ins_config(atom()) :: map()
  def get_vn_ins_config(node_type) do
    {device_desc, baud} =
      case node_type do
        :sim -> {"USB Serial", 115_200}
        _other -> {"RedBoard", 115_200}
      end
    %{
      vn_device_description: device_desc,
      baud: baud
    }
  end

  @spec get_cp_ins_config() :: map()
  def get_cp_ins_config() do
    %{
      ublox_device_description: "USB Serial",
      antenna_offset: Common.Constants.pi_2(),
      imu_loop_interval_ms: 20,
      ins_loop_interval_ms: 200,
      heading_loop_interval_ms: 200
    }
  end

  @spec get_telemetry_config(atom()) :: map()
  def get_telemetry_config(module) do
    {device_desc, baud} =
      case module do
        :Xbee -> {"FT231X", 57_600}
        :Sik -> {"FT231X", 57_600}
      end
    %{
      device_description: device_desc,
      baud: baud,
      fast_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
      medium_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      slow_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
    }
  end

  @spec get_sik_config() :: map()
  def get_sik_config() do
    %{
      device_description: "FT231X",
      baud: 57_600
    }
  end

  @spec get_xbee_config() :: map()
  def get_xbee_config() do
    %{
      device_description: "FT231X",
      baud: 57_600
    }
  end

end
