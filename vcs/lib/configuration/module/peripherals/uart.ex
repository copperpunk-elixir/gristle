defmodule Configuration.Module.Peripherals.Uart do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, node_type) do
    peripherals = Common.Utils.get_uart_peripherals()
    Logger.info("peripherals: #{inspect(peripherals)}")
    Enum.reduce(peripherals, %{}, fn (module, acc) ->
      {module_key, module_config} =
        case module do
          :FrskyRx -> {FrskyRx, get_frsky_rx_config(node_type)}
          :FrskyServo -> {Actuation, get_frsky_servo_config()}
          :PololuServo -> {Actuation, get_pololu_servo_config()}
          :TerarangerEvo -> {TerarangerEvo, get_teraranger_evo_config(node_type)}
          :VnIns -> {VnIns, get_vn_ins_config(node_type)}
        end
      Map.put(acc, module_key, module_config)
    end)
  end

  @spec get_frsky_rx_config(atom()) :: map()
  def get_frsky_rx_config(node_type) do
    stop_bits =
      case node_type do
        :sim -> 1
        _other -> 2
      end
    %{
      device_description: "CP2104",
      stop_bits: stop_bits
    }
  end

  @spec get_frsky_servo_config() :: map()
  def get_frsky_servo_config() do
    %{
      interface_module: Peripherals.Uart.FrskyServo,
      driver_config: %{
        device_description: "Feather M0",
        baud: 115_200,
        write_timeout: 1,
        read_timeout: 1
      }
    }
  end

  @spec get_pololu_servo_config() :: map()
  def get_pololu_servo_config() do
    %{
      interface_module: Peripherals.Uart.PololuServo,
      driver_config: %{
        device_description: "Pololu",
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

end
