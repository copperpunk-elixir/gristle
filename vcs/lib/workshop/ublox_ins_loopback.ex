defmodule Workshop.UbloxInsLooper do
  require Logger

  alias Common.Utils.Math, as: Math
  def start_ublox() do
    Comms.System.start_link(nil)
    Process.sleep(100)
    config = Configuration.Module.Peripherals.Uart.get_generic_config("usb","a")
    Peripherals.Uart.Generic.Operator.start_link(config)

  end

  def send_ublox_message() do
    time = DateTime.utc_now();
    day = Date.from_erl!({time.year, time.month, time.day})
    iTOW = Telemetry.Ublox.get_itow(time, day)
    lat = 45*10_000_000
    lon = -122*10_000_000
    h_ellipsoid = 123_000
    h_msl = 456_000
    h_acc = 1020
    v_acc = 2040
    values = [iTOW, lon, lat, h_ellipsoid, h_msl, h_acc, v_acc]
    message = Telemetry.Ublox.construct_message(:ublox_posllh, values)
    Peripherals.Uart.Generic.Operator.send_message("USB Serial", message)
    Logger.debug("len: #{length(:binary.bin_to_list(message))}")
  end

  def print_values(values) do
    [iTOW, lat, lon, h_ellipsoid, h_msl, h_acc, v_acc] = values
    Logger.debug("iTOW: #{iTOW}")
    Logger.debug("Lat/Lon: #{lat*1.0e-7}/#{lon*1.0e-7}")
    Logger.debug("hEll/hMsl: #{h_ellipsoid*1.0e-3}/#{h_msl*1.0e-3}")
    Logger.debug("hAcc/vAcc: #{h_acc*1.0e-3}/#{v_acc*1.0e-3}")
  end
end
