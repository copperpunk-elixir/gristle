defmodule Peripherals.I2c.Vl53tof do
  use Bitwise
  require Logger
  defstruct [bus_ref: nil, address: nil]

  @default_bus "i2c-1"
  @default_address 0x29
  @system_mode_start 0x0087
  @vhv_config 0x0008

  def new_vl53tof(config) do
    Logger.debug("Start VL53ToF")
    bus_ref = Peripherals.I2c.Utils.get_bus_ref(Map.get(config, :i2c_bus, @default_bus))
    address = @default_address
    %Peripherals.I2c.Vl53tof{bus_ref: bus_ref, address: address}
  end

  def begin(device) do
    default_config = [
      0x00, # 0x2d : set bit 2 and 5 to 1 for fast plus mode (1MHz I2C), else don't touch */
      0x01, # 0x2e : bit 0 if I2C pulled up at 1.8V, else set bit 0 to 1 (pull up at AVDD) */
      0x01, # 0x2f : bit 0 if GPIO pulled up at 1.8V, else set bit 0 to 1 (pull up at AVDD) */
      0x01, # 0x30 : set bit 4 to 0 for active high interrupt and 1 for active low (bits 3:0 must be 0x1), use SetInterruptPolarity() */
      0x02, # 0x31 : bit 1 = interrupt depending on the polarity, use CheckForDataReady() */
      0x00, # 0x32 : not user-modifiable */
      0x02, # 0x33 : not user-modifiable */
      0x08, # 0x34 : not user-modifiable */
      0x00, # 0x35 : not user-modifiable */
      0x08, # 0x36 : not user-modifiable */
      0x10, # 0x37 : not user-modifiable */
      0x01, # 0x38 : not user-modifiable */
      0x01, # 0x39 : not user-modifiable */
      0x00, # 0x3a : not user-modifiable */
      0x00, # 0x3b : not user-modifiable */
      0x00, # 0x3c : not user-modifiable */
      0x00, # 0x3d : not user-modifiable */
      0xff, # 0x3e : not user-modifiable */
      0x00, # 0x3f : not user-modifiable */
      0x0F, # 0x40 : not user-modifiable */
      0x00, # 0x41 : not user-modifiable */
      0x00, # 0x42 : not user-modifiable */
      0x00, # 0x43 : not user-modifiable */
      0x00, # 0x44 : not user-modifiable */
      0x00, # 0x45 : not user-modifiable */
      0x20, # 0x46 : interrupt configuration 0->level low detection, 1-> level high, 2-> Out of window, 3->In window, 0x20-> New sample ready , TBC */
    0x0b, # 0x47 : not user-modifiable */
    0x00, # 0x48 : not user-modifiable */
    0x00, # 0x49 : not user-modifiable */
    0x02, # 0x4a : not user-modifiable */
    0x0a, # 0x4b : not user-modifiable */
    0x21, # 0x4c : not user-modifiable */
    0x00, # 0x4d : not user-modifiable */
    0x00, # 0x4e : not user-modifiable */
    0x05, # 0x4f : not user-modifiable */
    0x00, # 0x50 : not user-modifiable */
    0x00, # 0x51 : not user-modifiable */
    0x00, # 0x52 : not user-modifiable */
    0x00, # 0x53 : not user-modifiable */
    0xc8, # 0x54 : not user-modifiable */
    0x00, # 0x55 : not user-modifiable */
    0x00, # 0x56 : not user-modifiable */
    0x38, # 0x57 : not user-modifiable */
    0xff, # 0x58 : not user-modifiable */
    0x01, # 0x59 : not user-modifiable */
    0x00, # 0x5a : not user-modifiable */
    0x08, # 0x5b : not user-modifiable */
    0x00, # 0x5c : not user-modifiable */
    0x00, # 0x5d : not user-modifiable */
    0x01, # 0x5e : not user-modifiable */
    0xdb, # 0x5f : not user-modifiable */
    0x0f, # 0x60 : not user-modifiable */
    0x01, # 0x61 : not user-modifiable */
    0xf1, # 0x62 : not user-modifiable */
    0x0d, # 0x63 : not user-modifiable */
    0x01, # 0x64 : Sigma threshold MSB (mm in 14.2 format for MSB+LSB), use SetSigmaThreshold(), default value 90 mm  */
    0x68, # 0x65 : Sigma threshold LSB */
    0x00, # 0x66 : Min count Rate MSB (MCPS in 9.7 format for MSB+LSB), use SetSignalThreshold() */
    0x80, # 0x67 : Min count Rate LSB */
    0x08, # 0x68 : not user-modifiable */
    0xb8, # 0x69 : not user-modifiable */
    0x00, # 0x6a : not user-modifiable */
    0x00, # 0x6b : not user-modifiable */
    0x00, # 0x6c : Intermeasurement period MSB, 32 bits register, use SetIntermeasurementInMs() */
    0x00, # 0x6d : Intermeasurement period */
    0x0f, # 0x6e : Intermeasurement period */
    0x89, # 0x6f : Intermeasurement period LSB */
    0x00, # 0x70 : not user-modifiable */
    0x00, # 0x71 : not user-modifiable */
    0x00, # 0x72 : distance threshold high MSB (in mm, MSB+LSB), use SetD:tanceThreshold() */
    0x00, # 0x73 : distance threshold high LSB */
    0x00, # 0x74 : distance threshold low MSB ( in mm, MSB+LSB), use SetD:tanceThreshold() */
    0x00, # 0x75 : distance threshold low LSB */
    0x00, # 0x76 : not user-modifiable */
    0x01, # 0x77 : not user-modifiable */
    0x0f, # 0x78 : not user-modifiable */
    0x0d, # 0x79 : not user-modifiable */
    0x0e, # 0x7a : not user-modifiable */
    0x0e, # 0x7b : not user-modifiable */
    0x00, # 0x7c : not user-modifiable */
    0x00, # 0x7d : not user-modifiable */
    0x02, # 0x7e : not user-modifiable */
    0xc7, # 0x7f : ROI center, use SetROI() */
    0xff, # 0x80 : XY ROI (X=Width, Y=Height), use SetROI() */
    0x9B, # 0x81 : not user-modifiable */
    0x00, # 0x82 : not user-modifiable */
    0x00, # 0x83 : not user-modifiable */
    0x00, # 0x84 : not user-modifiable */
    0x01, # 0x85 : not user-modifiable */
    0x00, # 0x86 : clear interrupt, use ClearInterrupt() */
    0x00  # 0x87 : start ranging, use StartRanging() or StopRanging(), If you want an automatic start after VL53L1X_init() call, put 0x40 in location 0x87 */
    ]
    start_register = 0x2D
    Enum.reduce(default_config, start_register, fn (byte, register) ->
      Logger.debug("byte/register: #{byte}/#{register}")
      write_byte_to_register(device, register, byte)
      Process.sleep(1)
      register+1
    end)
   confirm_sensor_active(device, 0)
   write_byte_to_register(device, @vhv_config, 0x09)
   write_byte_to_register(device, 0x0B, 0)
  end

  def start_ranging(device) do
    write_byte_to_register(device, @system_mode_start, 0x40)
  end

  def stop_ranging(device) do
    write_byte_to_register(device, @system_mode_start, 0x00)
  end

  defp confirm_sensor_active(device, count) do
    if count == 0 do
      start_ranging(device)
    end
    if is_data_ready?(device) do
      clear_interrupt(device)
      stop_ranging(device)
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
    Logger.debug("GIP result0: #{result}")
    result = result &&& 0x10
    Logger.debug("GIP result0.5: #{result}")
    result = result >>> 4
    Logger.debug("GIP result1: #{result}")
    result = Bitwise.bxor(result, 1)
    Logger.debug("GIP result2: #{result}")
    result
  end

  def is_data_ready?(device) do
    interrupt_polarity = get_interrupt_polarity(device)
    hv_status = read_byte_at_register(device, 0x31)
    Logger.debug("HV_status: #{hv_status}")
    if (hv_status &&& 1) == interrupt_polarity do
      true
    else
      false
    end
  end

  def wait_for_data(device, timeout) do
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

  def get_distance_mode(device) do
    temp_distance_mode = read_byte_at_register(device, 0x004B)
    Logger.debug("temp dm: #{temp_distance_mode}")
    case temp_distance_mode do
      0x14 -> 1
      0x0A -> 2
      _ ->
        Logger.error("Unknown distance mode")
        nil
    end
  end

  def get_single_distance(device) do
    start_ranging(device)
    wait_for_data(device, 100)
    distance = get_distance(device)
    clear_interrupt(device)
    stop_ranging(device)
    distance
  end

  def get_distance(device) do
    result = read_packet_at_register(device, 0x0096, 2)
    Logger.debug("result: #{inspect(result)}")
    msb = Enum.at(result, 0)
    lsb = Enum.at(result, 1)
    Logger.debug("msb/lsb: #{msb}/#{lsb}")
    (msb <<< 8) + lsb
  end

  defp write_byte_to_register(device, register, data_byte) do
    packet = [register >>> 8, register &&& 0xFF, data_byte]
    Peripherals.I2c.Utils.write_packet(device.bus_ref, device.address, packet)
  end

  defp read_byte_at_register(device, register) do
    result = read_packet_at_register(device, register, 1)
    Enum.at(result, 0)
  end

  defp read_packet_at_register(device, register, num_bytes) do
    send_packet = [register >>> 8, register &&& 0xFF]
    Peripherals.I2c.Utils.write_packet(device.bus_ref, device.address, send_packet)
    Peripherals.I2c.Utils.read_packet(device.bus_ref, device.address, num_bytes)
  end
end
