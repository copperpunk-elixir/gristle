defmodule Configuration.Module.Peripherals.Uart do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_model_type, node_type) do
    subdirectory = Atom.to_string(node_type)
    peripherals = Common.Utils.Configuration.get_uart_peripherals(subdirectory)
    Logger.debug("peripherals: #{inspect(peripherals)}")
    node_type = if Common.Utils.Configuration.is_hil?(), do: :hil, else: node_type
    Enum.reduce(peripherals, %{}, fn (name, acc) ->
      peripheral_string = Atom.to_string(name)
      [device, port] = String.split(peripheral_string, "_")
      {module_key, module_config} = get_module_key_and_config(device, node_type, port)
      Map.put(acc, module_key, module_config)
    end)
  end

  @spec get_module_key_and_config(atom(), atom(), binary()) :: tuple()
  def get_module_key_and_config(device, node_type, port) do
    Logger.debug("port: #{port}")
    uart_port =
      case port do
        "usb" -> "usb"
        port_num -> "ttyAMA#{String.to_integer(port_num)-2}"
      end
    case device do
      :Dsm -> {Command.Rx, get_dsm_rx_config()}
      "FrskyRx" -> {Command.Rx, get_frsky_rx_config(uart_port)}
      :FrskyServo -> {Actuation, get_actuation_config(device)}
      :PololuServo -> {Actuation, get_actuation_config(device)}
      :DsmRxFrskyServo -> {ActuationCommand, get_actuation_command_config(device)}
      :FrskyRxFrskyServo -> {ActuationCommand, get_actuation_command_config(device)}
      :TerarangerEvo -> {Estimation.TerarangerEvo, get_teraranger_evo_config(node_type)}
      :VnIns -> {Estimation.VnIns, get_vn_ins_config(node_type)}
      :VnImu -> {Estimation.VnIns, get_vn_imu_config(node_type)}
      "Xbee" -> {Telemetry, get_telemetry_config(device)}
      :Sik -> {Telemetry, get_telemetry_config(device)}
      :PwmReader -> {PwmReader, get_pwm_reader_config()}
    end
  end

  @spec get_dsm_rx_config() :: map()
  def get_dsm_rx_config() do
    %{
      device_description: "CP2104",
      rx_module: :Dsm,
      port_options: [
        speed: 115_200,
        rx_framing_timeout: 11
      ]
    }
  end

  @spec get_frsky_rx_config(binary()) :: map()
  def get_frsky_rx_config(uart_port) do
    %{
      device_description: uart_port,
      rx_module: :Frsky,
      port_options: [
        speed: 100000,
        stop_bits: 2,
        parity: :even,
        rx_framing_timeout: 7
      ]
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
      device_description: device_desc,
      baud: 115_200
      # write_timeout: 1,
      # read_timeout: 1
    }
  end

  @spec get_actuation_command_config(atom()) :: map()
  def get_actuation_command_config(module) do
    {interface_module, device_desc, rx_module} =
      case module do
        :DsmRxFrskyServo -> {Peripherals.Uart.Actuation.Frsky.Device, "Feather M0", :Dsm}
        :FrskyRxFrskyServo -> {Peripherals.Uart.Actuation.Frsky.Device, "Feather M0", :Frsky}
      end
    %{
      interface_module: interface_module,
      device_description: device_desc,
      baud: 115_200,
      rx_module: rx_module
    }
  end


  @spec get_teraranger_evo_config(atom()) :: map()
  def get_teraranger_evo_config(node_type) do
    device_description =
      case node_type do
        :sim -> "FT232R"
        :hil -> "FT232R"
        _other -> "STM32"
      end
    %{
      device_description: device_description,
      baud: 115_200
    }
  end

  @spec get_vn_ins_config(atom()) :: map()
  def get_vn_ins_config(node_type) do
    {device_desc, baud} =
      case node_type do
        :sim -> {"USB Serial", 115_200}
        :hil -> {"USB Serial", 115_200}
        _other -> {"RedBoard", 115_200}
      end
    %{
      device_description: device_desc,
      baud: baud,
      expecting_pos_vel: true
    }
  end

  @spec get_vn_imu_config(atom()) :: map()
  def get_vn_imu_config(node_type) do
    {device_desc, baud} =
      case node_type do
        :sim -> {"USB Serial", 115_200}
        :hil -> {"USB Serial", 115_200}
        _other -> {"Qwiic Micro", 115_200}
      end
    %{
      device_description: device_desc,
      baud: baud,
      expecting_pos_vel: false
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

  @spec get_telemetry_config(binary()) :: map()
  def get_telemetry_config(uart_port) do
    device_desc =
      case uart_port do
        "usb" -> "FT231X"
        port -> port
      end
    %{
      device_description: device_desc,
      baud: 57_600,
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

  @spec get_pwm_reader_config() :: map()
  def get_pwm_reader_config() do
    %{
      device_description: "Feather M0",
      baud: 115_200
    }
  end

end
