defmodule Configuration.Module.Peripherals.Uart do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_model_type, node_type) do
    subdirectory = Atom.to_string(node_type)
    peripherals = Common.Utils.Configuration.get_uart_peripherals(subdirectory)
    Logger.debug("peripherals: #{inspect(peripherals)}")
    node_type = if Common.Utils.Configuration.is_hil?(), do: :hil, else: node_type
    Enum.reduce(peripherals, %{}, fn (module, acc) ->
      {module_key, module_config} = get_module_key_and_config_for_module(module, node_type)
      Map.put(acc, module_key, module_config)
    end)
  end

  @spec get_module_key_and_config_for_module(atom(), atom()) :: tuple()
  def get_module_key_and_config_for_module(module, node_type \\ nil) do
    case module do
      :Dsm -> {Command.Rx, get_dsm_rx_config()}
      :FrskyRx -> {Command.Rx, get_frsky_rx_config()}
      :FrskyServo -> {Actuation, get_actuation_config(module)}
      :PololuServo -> {Actuation, get_actuation_config(module)}
      :DsmRxFrskyServo -> {ActuationCommand, get_actuation_command_config(module)}
      :FrskyRxFrskyServo -> {ActuationCommand, get_actuation_command_config(module)}
      :TerarangerEvo -> {Estimation.TerarangerEvo, get_teraranger_evo_config(node_type)}
      :VnIns -> {Estimation.VnIns, get_vn_ins_config(node_type)}
      :VnImu -> {Estimation.VnIns, get_vn_imu_config(node_type)}
      :Xbee -> {Telemetry, get_telemetry_config(module)}
      :Sik -> {Telemetry, get_telemetry_config(module)}
      :PwmReader -> {PwmReader, get_pwm_reader_config()}
    end
  end

  @spec get_dsm_rx_config() :: map()
  def get_dsm_rx_config() do
    %{
      device_description: "CP2104",
      baud: 115_200,
      rx_module: :Dsm
    }
  end

  @spec get_frsky_rx_config() :: map()
  def get_frsky_rx_config() do
    %{
      device_description: "CP2104",
      baud: 100_000,
      stop_bits: 2,
      rx_framing_timeout: 7,
      rx_module: :Frsky
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

  @spec get_pwm_reader_config() :: map()
  def get_pwm_reader_config() do
    %{
      device_description: "Feather M0",
      baud: 115_200
    }
  end

end
