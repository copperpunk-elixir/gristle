defmodule Vl53tof do
  @moduledoc """
  """

  @doc """
  """
  use Bitwise
  require Logger
  defstruct [bus_ref: nil, address: nil]

  @default_bus "i2c-1"
  @default_address 0x29

  @system_mode_start 0x0087
  @vhv_config 0x0008
  @range_config_A_HI 0x005E
  @range_config_B_HI 0x0062
  @osc_calibrate 0x00DE
  @intermeasurement_period 0x006C


  # ----- BEGIN MANDATORY INTERFACE -----
  def new_sensor(config) do
    Logger.debug("Start VL53ToF")
    bus_ref = Vl53tof.Utils.get_bus_ref(Map.get(config, :i2c_bus, @default_bus))
    address = @default_address
    %Vl53tof{bus_ref: bus_ref, address: address}
  end

  def begin(device) do
    default_config =
      [0x00,0x01,0x01,0x01,0x02,0x00,0x02,0x08,0x00,0x08,0x10,0x01,0x01,0x00,0x00,0x00,0x00,
       0xff,0x00,0x0F,0x00,0x00,0x00,0x00,0x00,0x20,0x0b,0x00,0x00,0x02,0x0a,0x21,0x00,0x00,
       0x05,0x00,0x00,0x00,0x00,0xc8,0x00,0x00,0x38,0xff,0x01,0x00,0x08,0x00,0x00,0x01,0xdb,
       0x0f,0x01,0xf1,0x0d,0x01,0x68,0x00,0x80,0x08,0xb8,0x00,0x00,0x00,0x00,0x0f,0x89,0x00,
       0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x0f,0x0d,0x0e,0x0e,0x00,0x00,0x02,0xc7,0xff,0x9B,
       0x00,0x00,0x00,0x01,0x00,0x00]
    start_register = 0x2D
    Enum.reduce(default_config, start_register, fn (byte, register) ->
      # Logger.debug("byte/register: #{byte}/#{register}")
      write_byte_to_register(device, register, byte)
      Process.sleep(1)
      register+1
    end)
   confirm_sensor_active(device, 0)
   write_byte_to_register(device, @vhv_config, 0x09)
   write_byte_to_register(device, 0x0B, 0)
  end

  def set_distance_mode_short(device) do
    set_distance_mode(device, 1)
  end

  def set_distance_mode_long(device) do
    set_distance_mode(device, 2)
  end

  def set_update_interval_ms(device, interval_ms) do
    # Always set the timing budget equal to the measurement interval
    actual_timing_interval_ms = set_timing_budget_ms(device, interval_ms)
    Process.sleep(10)
    clock_pll = read_packet_at_register(device, @osc_calibrate, 2)
    |> word_to_value()
    |> Bitwise.&&&(0x03FF)
    clock_pll_value = floor(clock_pll*actual_timing_interval_ms*1.075)
    clock_packet = [
    (clock_pll_value >>> 24) &&& 0xFF,
    (clock_pll_value >>> 16) &&& 0xFF,
    (clock_pll_value >>> 8) &&& 0xFF,
    clock_pll_value &&& 0xFF]
    write_packet_to_register(device, @intermeasurement_period, clock_packet)
  end

  def start_measurements(device) do
    write_byte_to_register(device, @system_mode_start, 0x40)
  end

  def stop_measurements(device) do
    write_byte_to_register(device, @system_mode_start, 0x00)
  end

  def get_distance(device) do
    get_distance_mm(device) / 1000
  end

  # ----- END MANDATORY INTERFACE -----

  # ----- BEGIN OPTIONAL INTERFACE -----
  def get_distance_mode(device) do
    temp_distance_mode = read_byte_at_register(device, 0x004B)
    # Logger.debug("temp dm: #{temp_distance_mode}")
    case temp_distance_mode do
      0x14 ->
        Logger.debug("Short range mode")
        1
      0x0A ->
        Logger.debug("Long range mode")
        2
      _ ->
        Logger.error("Unknown distance mode")
        nil
    end
  end

  def get_single_distance(device) do
    start_measurements(device)
    wait_for_data(device, 100)
    distance = get_distance(device)
    clear_interrupt(device)
    stop_measurements(device)
    distance
  end

  def get_update_interval_ms(device) do
    timing_budget_temp = read_packet_at_register(device, @range_config_A_HI, 2)
    |> word_to_value()
    case timing_budget_temp do
      0x001D -> 15
      0x001E -> 20
      0x0060 -> 33
      0x00AD -> 50
      0x01CC -> 100
      0x02D9 -> 200
      0x048F -> 500
      _ -> 0
    end
  end

  # ----- END OPTIONAL INTERFACE -----

  defp confirm_sensor_active(device, count) do
    if count == 0 do
      start_measurements(device)
    end
    if is_data_ready?(device) do
      clear_interrupt(device)
      stop_measurements(device)
    else
      if (count > 50) do
        raise "VL53ToF is not responding"
      else
        Process.sleep(10)
        confirm_sensor_active(device, count+1)
      end
    end
  end

  defp clear_interrupt(device) do
    write_byte_to_register(device, 0x86, 0x01)
  end


  defp get_interrupt_polarity(device) do
    result = read_byte_at_register(device, 0x0030)
    # Logger.debug("GIP result0: #{result}")
    result = result &&& 0x10
    # Logger.debug("GIP result0.5: #{result}")
    result = result >>> 4
    # Logger.debug("GIP result1: #{result}")
    result = Bitwise.bxor(result, 1)
    # Logger.debug("GIP result2: #{result}")
    result
  end

  defp is_data_ready?(device) do
    interrupt_polarity = get_interrupt_polarity(device)
    hv_status = read_byte_at_register(device, 0x31)
    # Logger.debug("HV_status: #{hv_status}")
    if (hv_status &&& 1) == interrupt_polarity do
      true
    else
      false
    end
  end

  defp wait_for_data(device, timeout) do
    wait_for_data(device, 0, timeout)
  end

  defp wait_for_data(device, current_time, timeout) do
    unless is_data_ready?(device) do
      if current_time < timeout do
        Process.sleep(1)
        wait_for_data(device, current_time+1, timeout)
      else
        raise "Data not available"
      end
    end
  end

  defp set_timing_budget_ms(device, interval_ms) do
    distance_mode = get_distance_mode(device)
    {timing_word_1, timing_word_2, actual_interval_ms} =
      case distance_mode do
        1 ->
          Logger.debug("Set timing budget for short range")
          cond do
            interval_ms < 20 -> {0x001D, 0x0027, 15} # 15ms
            interval_ms < 33 -> {0x0051, 0x006E, 20} # 20ms
            interval_ms < 50 -> {0x00D6, 0x006E, 33} # 33ms
            interval_ms < 100 -> {0x01AE, 0x1E8, 50} # 50ms
            interval_ms < 200 -> {0x02E1, 0x0388, 100} # 100ms
            interval_ms < 500 -> {0x03E1, 0x0496, 200} # 200ms
            true -> {0x0591, 0x05C1, 500} # 500ms
          end
        2 ->
          Logger.debug("Set timing budget for long range")
          cond do
            interval_ms < 33 -> {0x001E, 0x0022, 20} # 20ms
            interval_ms < 50 -> {0x0060, 0x006E, 33} # 33ms
            interval_ms < 100 -> {0x00AD, 0x00C6, 50} # 50ms
            interval_ms < 200 -> {0x01CC, 0x01EA, 100} # 100ms
            interval_ms < 500 -> {0x02D9, 0x02F8, 200} # 200ms
            true -> {0x048F, 0x04A4, 500} # 500ms
          end
        _ -> {nil, nil, nil}
      end
    unless actual_interval_ms == nil do
      write_timing_budget_packets(device, timing_word_1, timing_word_2)
    end
    actual_interval_ms
  end

  defp write_timing_budget_packets(device, word1, word2) do
    packet1 = get_packet_for_word(word1)
    packet2 = get_packet_for_word(word2)
    write_packet_to_register(device, @range_config_A_HI, packet1)
    write_packet_to_register(device, @range_config_B_HI, packet2)
  end

  defp set_distance_mode(device, distance_mode) do
    register_list_bytes = [0x004B, 0x0060, 0x0063, 0x0069]
    register_list_words = [0x0078, 0x007A]
    {byte_list, word_list} =
      case distance_mode do
        1 -> {[0x14, 0x07, 0x05, 0x38], [0x0705, 0x0606]}
        2 -> {[0x0A, 0x0F, 0x0D, 0xB8], [0x0F0D, 0x0E0E]}
        _ -> {nil, nil}
      end
     unless (byte_list == nil) do
       Enum.each(0..length(register_list_bytes)-1, fn index ->
         write_byte_to_register(device, Enum.at(register_list_bytes,index), Enum.at(byte_list, index))
       end)
       Enum.each(0..length(register_list_words)-1, fn index ->
         send_packet = get_packet_for_word(Enum.at(word_list, index))
         write_packet_to_register(device, Enum.at(register_list_words,index), send_packet)
       end)
     end
  end

  defp get_distance_mm(device) do
    read_packet_at_register(device, 0x0096, 2)
    |> word_to_value()
  end

  defp write_byte_to_register(device, register, data_byte) do
    write_packet_to_register(device, register, [data_byte])
  end

  defp write_packet_to_register(device, register, packet) do
    send_packet = [register >>> 8, register &&& 0xFF] ++ packet
    Vl53tof.Utils.write_packet(device.bus_ref, device.address, send_packet)
  end

  defp read_byte_at_register(device, register) do
    result = read_packet_at_register(device, register, 1)
    Enum.at(result, 0)
  end

  defp read_packet_at_register(device, register, num_bytes) do
    send_packet = [register >>> 8, register &&& 0xFF]
    Vl53tof.Utils.write_packet(device.bus_ref, device.address, send_packet)
    Vl53tof.Utils.read_packet(device.bus_ref, device.address, num_bytes)
  end

  defp word_to_value(word) do
    (Enum.at(word, 0) <<< 8) + Enum.at(word, 1)
  end

  defp get_packet_for_word(word) do
    [word >>> 8, word &&& 0xFF]
  end
end
