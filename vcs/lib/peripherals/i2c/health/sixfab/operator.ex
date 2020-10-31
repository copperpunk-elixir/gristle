defmodule Peripherals.I2c.Health.Sixfab.Operator do
  use Bitwise
  use GenServer
  require Logger

  @i2c_bus "i2c-1"
  @device_address 0x41

  @start_byte_received 0xDC
  @start_byte_sent 0xCD
  @protocol_header_size 5
  @protocol_frame_size 7
  @command_size_for_uint8 8
  @command_size_for_uint16 9
  @command_size_for_int32 11


  @command_type_request 0x01
  # @command_type_response 0x02

  @default_response_delay 10
  # COMMAND_SIZE_FOR_FLOAT = 11
  # COMMAND_SIZE_FOR_DOUBLE = 13
  # COMMAND_SIZE_FOR_INT16 = 9
  # COMMAND_SIZE_FOR_INT32 = 11
  # COMMAND_SIZE_FOR_UINT8 = 8
  # COMMAND_SIZE_FOR_INT64 = 15

  @crc_table {
    0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
    0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
    0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
    0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
    0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
    0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
    0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
    0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
    0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
    0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
    0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
    0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
    0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
    0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
    0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
    0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
    0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
    0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
    0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
    0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
    0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
    0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
    0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
    0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
    0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
    0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
    0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
    0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
    0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
    0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
    0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
    0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0,
  }

  def start_link(config) do
    Logger.info("Start I2c.Health.Sixfab.Operator GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, i2c_ref} = Circuits.I2C.open(@i2c_bus)
    {:ok, %{
        i2c_ref: i2c_ref,
        read_voltage_interval_ms: config.read_voltage_interval_ms,
        read_current_interval_ms: config.read_current_interval_ms,
        battery: Health.Hardware.Battery.new(config.battery_type, config.battery_channel)
     }
    }
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Logger.debug("Sixfab begin with process: #{inspect(self())}")
    Process.sleep(100)
    Common.Utils.start_loop(self(), state.read_voltage_interval_ms, :read_voltage)
    Process.sleep(50)
    Common.Utils.start_loop(self(), state.read_current_interval_ms, :read_current)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:set_parameter, parameter, value}, state) do
    num_bytes =
      case parameter do
        :fan_mode -> 1
        :fan_speed -> 4
        :fan_automation -> 2
      end
    set_fan_parameter(state.i2c_ref, parameter, value, num_bytes)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:get_parameter, parameter}, state) do
    num_bytes =
      case parameter do
        :fan_mode -> 1
        :fan_speed -> 4
        :fan_health -> 4
        :fan_automation -> 2
      end
    result = get_fan_parameter(state.i2c_ref, parameter, num_bytes)
    Logger.debug("#{parameter} value: #{inspect(result)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:read_voltage, state) do
    voltage = read_voltage(state.i2c_ref)
    # Logger.debug("voltage: #{voltage}")
    battery = if is_nil(voltage), do: state.battery, else: Health.Hardware.Battery.update_voltage(state.battery, voltage)
    send_battery_status(battery)
    {:noreply, %{state | battery: battery}}
  end

  @impl GenServer
  def handle_info(:read_current, state) do
    current = read_current(state.i2c_ref)
    # Logger.info("current: #{current}")
    battery =
      cond do
      is_nil(current) -> state.battery
      current < 0 ->
        # Battery is discharging
        Health.Hardware.Battery.update_current(state.battery, -current, state.read_current_interval_ms*0.001)
      true ->
        # Battery is charging
        Health.Hardware.Battery.update_current(state.battery, -current, state.read_current_interval_ms*0.001)
    end
    {:noreply, %{state | battery: battery}}
  end

  @impl GenServer
  def handle_call({:get_battery_value, key}, _from, state) do
    value = Health.Hardware.Battery.get_value(state.battery, key)
    {:reply, value, state}
  end

  @spec send_battery_status(struct()) :: atom()
  def send_battery_status(battery) do
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:battery_status, battery}, self())
  end

  @spec get_voltage() :: float()
  def get_voltage() do
    Common.Utils.safe_call(__MODULE__, {:get_battery_value, :voltage}, 200, -1)
  end

  @spec get_current() :: float()
  def get_current() do
    Common.Utils.safe_call(__MODULE__, {:get_battery_value, :current}, 200, -1)
  end

  @spec get_energy_discharged() :: float()
  def get_energy_discharged() do
    Common.Utils.safe_call(__MODULE__, {:get_battery_value, :energy_discharged}, 200, -1)
  end

  @spec read_voltage(any()) :: float()
  def read_voltage(i2c_ref) do
    command_msg = create_get_command(:get_battery_voltage)
    send_command(i2c_ref, command_msg)
    Process.sleep(@default_response_delay)
    response = receive_command_response(i2c_ref, @command_size_for_int32)
    unless is_nil(response) do
      # Logger.debug("Sixfab voltage msg: #{inspect(response)}")
      process_response(response, 4, 0.001)
    else
      nil
    end
  end

  @spec read_current(any()) :: float()
  def read_current(i2c_ref) do
    command_msg = create_get_command(:get_battery_current)
    send_command(i2c_ref, command_msg)
    Process.sleep(@default_response_delay)
    response = receive_command_response(i2c_ref, @command_size_for_int32)
    unless is_nil(response) do
      # Logger.debug("Sixfab current msg: #{inspect(response)}")
      current_unsigned = process_response(response, 4, 1)
      # Convert to signed integer
      <<current_signed::signed-integer-32>> = <<current_unsigned::32>>
      current_signed*0.001
    else
       nil
    end
  end

  @spec get_fan_parameter(any(), atom(), integer()) :: integer()
  def get_fan_parameter(i2c_ref, command, num_bytes) do
    command_msg = create_get_command(command)
    send_command(i2c_ref, command_msg)
    Process.sleep(@default_response_delay)
    response = receive_command_response(i2c_ref, get_command_size_for_bytes(num_bytes))
    unless is_nil(response) do
      # Logger.debug("Sixfab get_fan_mode msg: #{inspect(response)}")
      Logger.info("fan response: #{inspect(response)}")
      process_response(response, num_bytes, 1)
    else
      nil
    end
  end

  @spec set_fan_parameter(any(), atom(), any(), integer()) :: atom()
  def set_fan_parameter(i2c_ref, command, value, num_bytes) do
    command_msg = create_set_command(command, value, num_bytes)
    send_command(i2c_ref, command_msg)
    Process.sleep(@default_response_delay)
    response = receive_command_response(i2c_ref, get_command_size_for_bytes(num_bytes))
    Logger.debug("set_fan response: #{inspect(response)}")
    unless is_nil(response) do
      status = process_response(response,num_bytes,1)
      Logger.debug("set_fan status: #{inspect(status)}")
    end
  end

  # @spec get_fan_speed(any()) :: integer()
  # def get_fan_speed(i2c_ref) do
  #   command_msg = create_get_command(:get_fan_speed)
  #   send_command(i2c_ref, command_msg)
  #   Process.sleep(@default_response_delay)
  #   response = receive_command_response(i2c_ref, @command_size_for_int32)
  #   unless is_nil(response) do
  #     # Logger.debug("Sixfab get_fan_mode msg: #{inspect(response)}")
  #     process_response(response, 4, 1)
  #   else
  #     nil
  #   end
  # end

  # @spec set_fan_speed(any(), integer()) :: atom()
  # def set_fan_speed(i2c_ref, rpm) do
  #   command_msg = create_set_command(:set_fan_speed, rpm, 4)
  #   send_command(i2c_ref, command_msg)
  #   Process.sleep(@default_response_delay)
  #   response = receive_command_response(i2c_ref, @command_size_for_int32)
  #   Logger.debug("set_fan_speed response: #{inspect(response)}")
  #   unless is_nil(response) do
  #     status = process_response(response,1,1)
  #     Logger.debug("set_fan_speed status: #{inspect(status)}")
  #   end
  # end

  # @spec get_fan_mode(any()) :: integer()
  # def get_fan_mode(i2c_ref) do
  #   command_msg = create_get_command(:get_fan_mode)
  #   send_command(i2c_ref, command_msg)
  #   Process.sleep(@default_response_delay)
  #   response = receive_command_response(i2c_ref, @command_size_for_uint8)
  #   unless is_nil(response) do
  #     # Logger.debug("Sixfab get_fan_mode msg: #{inspect(response)}")
  #     process_response(response, 1, 1)
  #   else
  #     nil
  #   end
  # end

  # @spec set_fan_mode(any(), integer()) :: atom()
  # def set_fan_mode(i2c_ref, mode) do
  #   command_msg = create_set_command(:set_fan_mode, mode, 1)
  #   send_command(i2c_ref, command_msg)
  #   Process.sleep(@default_response_delay)
  #   response = receive_command_response(i2c_ref, @command_size_for_uint8)
  #   Logger.debug("set_fan_mode response: #{inspect(response)}")
  #   unless is_nil(response) do
  #     status = process_response(response, 1,1)
  #     Logger.debug("set_fan_mode status: #{inspect(status)}")
  #   end
  # end

  @spec request_read(integer()) :: atom()
  def request_read(channel)  do
    GenServer.cast(__MODULE__, {:read_channel, channel})
  end

  @spec turn_fan_on() :: atom()
  def turn_fan_on do
    GenServer.cast(__MODULE__, {:set_parameter, :fan_mode, 1})
  end

  @spec turn_fan_off() :: atom()
  def turn_fan_off do
    GenServer.cast(__MODULE__, {:set_parameter, :fan_mode, 2})
  end

  @spec set_fan_automation(list()) :: atom()
  def set_fan_automation([slow_threshold, fast_threshold]) do
    GenServer.cast(__MODULE__, {:set_parameter, :fan_automation, [slow_threshold, fast_threshold]})
  end

  @spec set_fan_speed(integer()) :: atom()
  def set_fan_speed(rpm) do
    GenServer.cast(__MODULE__, {:set_parameter, :fan_speed, rpm})
  end

  @spec get_fan_mode() :: atom()
  def get_fan_mode() do
    GenServer.cast(__MODULE__, {:get_parameter, :fan_mode})
  end

  @spec get_fan_speed() :: atom()
  def get_fan_speed() do
    GenServer.cast(__MODULE__, {:get_parameter, :fan_speed})
  end

  @spec get_fan_health() :: atom()
  def get_fan_health() do
    GenServer.cast(__MODULE__, {:get_parameter, :fan_health})
  end

  @spec get_fan_automation() :: atom()
  def get_fan_automation() do
    GenServer.cast(__MODULE__, {:get_parameter, :fan_automation})
  end


  @spec create_get_command(atom()) :: list()
  def create_get_command(command) do
    command_id =
      case command do
        :get_battery_voltage -> 10
        :get_battery_current -> 11
        :fan_speed -> 15
        :fan_automation -> 22
        :fan_health -> 23
        :fan_mode -> 50
      end
    msg = [@start_byte_sent, command_id, @command_type_request, 0x00, 0x00]
    checksum = calculate_checksum(msg)
    # Logger.debug("checksum: 0x#{Integer.to_string(checksum, 16)}")
    <<msb, lsb>> = <<checksum::16>>
    msg ++ [msb, lsb]
  end

  @spec create_set_command(atom(), any(), integer(), integer()) :: list()
  def create_set_command(command, value, command_length, command_type\\@command_type_request) do
    command_id =
      case command do
        :fan_speed -> 20
        :fan_automation -> 21
        :fan_mode -> 49
      end
    len_high = (command_length >>> 8) &&& 0xFF
    len_low = command_length &&& 0xFF

    value =
    if is_list(value) do
      value
    else
      Common.Utils.Math.int_little_bin(value, command_length*8) |> :binary.bin_to_list()
    end
    msg = [@start_byte_sent, command_id, command_type, len_high, len_low] ++ value
    Logger.debug("set command: #{inspect(msg)}")
    checksum = calculate_checksum(msg)
    # Logger.debug("checksum: 0x#{Integer.to_string(checksum, 16)}")
    <<msb, lsb>> = <<checksum::16>>
    msg ++ [msb, lsb]
  end


  @spec send_command(any(), list()) :: atom()
  def send_command(i2c_ref, msg) do
    Circuits.I2C.write(i2c_ref, @device_address, <<0x01>> <> :binary.list_to_bin(msg))
  end

  @spec receive_command_response(any(), integer()) :: list()
  def receive_command_response(i2c_ref, num_bytes) do
    response = read_byte(i2c_ref, [], 0, num_bytes)
    if is_valid_response?(response), do: response, else: nil
  end

  @spec read_byte(any(), list(), integer(), integer()) :: list()
  def read_byte(i2c_ref, buffer, byte_count, num_bytes_to_read) do
    case Circuits.I2C.read(i2c_ref, @device_address, 1) do
      {:ok, <<result>>} ->
        # Logger.info("read byte: #{result}")
        buffer = buffer ++ [result]
        if (byte_count + 1 < num_bytes_to_read) do
          read_byte(i2c_ref, buffer, byte_count+1, num_bytes_to_read)
        else
          buffer
        end
      other ->
        Logger.error("Sixfab read error: #{inspect(other)}")
        nil
    end
  end

  @spec calculate_checksum(list()) :: integer()
  def calculate_checksum(message) do
    crc =
      Enum.reduce(message, 0, fn (byte, crc) ->
        # Logger.debug("byte/crc: #{byte}/#{crc}")
        term1 = (crc <<< 8)
        |> Bitwise.&&&(0xFF00)

        term2 = crc >>> 8
        |> Bitwise.&&&(0xFF)
        |> Bitwise.^^^(byte)

        elem(@crc_table, term2)
        |> Bitwise.^^^(term1)
      end)
     crc &&& 0xFFFF
  end

  @spec process_response(list(), integer()) :: integer()
  def process_response(msg, num_bytes, multiplier\\1) do
    Logger.debug("process response: #{inspect(msg)}")
    result = Enum.slice(msg, @protocol_header_size, num_bytes)
    # Logger.debug("slice: #{inspect(result)}")
    case convert_result_to_integer(result, num_bytes) do
      nil ->
        Logger.error("Result conversion error: #{inspect(result)}")
        nil
      result -> result*multiplier
    end
  end

  @spec convert_result_to_integer(list(), integer()) :: integer()
  def convert_result_to_integer(result, num_bytes) do
    if (length(result) == num_bytes) do
      num_bits = 8*num_bytes
      <<x::size(num_bits)>> = :binary.list_to_bin(result)
      x
    else
      nil
    end
  end

  @spec is_valid_response?(list()) :: boolean()
  def is_valid_response?(msg) do
    Logger.debug("validate response: #{inspect(msg)}")
    {header, buffer_rem} = Enum.split(msg, 5)
    unless Enum.empty?(buffer_rem) do
      [start_byte, _, _, data_len_msb, data_len_lsb] = header
      data_len =
      if start_byte == @start_byte_received do
        (data_len_msb<<<8) + data_len_lsb
      else
        0
      end
      {data,checksum} = Enum.split(buffer_rem, data_len)
      unless Enum.empty?(checksum) do
        case Enum.take(checksum, 2) do
          [checksum_msb, checksum_lsb] ->
            checksum_received = (checksum_msb <<< 8) + checksum_lsb
            checksum_calc = calculate_checksum(header ++ data)
            (checksum_received == checksum_calc)
          _other ->
            Logger.warn("checksum bytes not available")
            false
        end
      else
        false
      end
    else
      false
    end
  end

  @spec get_command_size_for_bytes(integer()) :: integer()
  def get_command_size_for_bytes(num_bytes) do
    @protocol_frame_size + num_bytes
    # case num_bytes do
    #   1 -> @command_size_for_uint8
    #   2 -> @command_
    #   4 -> @command_size_for_int32
    # end
  end

end
