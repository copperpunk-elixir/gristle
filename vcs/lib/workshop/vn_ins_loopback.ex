defmodule Workshop.VnInsLoopback do
  alias Common.Utils.Math, as: Math
  def start_vn_ins(port) do
    Comms.System.start_link(nil)
    Process.sleep(100)
    config =
      [
      uart_port: "USB Serial",
      port_options: [speed: 115_200],
      expecting_pos_vel: true
    ]

    Peripherals.Uart.Estimation.VnIns.Operator.start_link(config)
  end

  def send_vn_ins_message() do
    position = Common.Utils.LatLonAlt.new_deg(45.0, -120.0, 123.4)
    velocity = %{north: 1.0, east: -2.0, down: 3.4}
    attitude = %{roll: Math.deg2rad(5.0), pitch: Math.deg2rad(-10.0), yaw: Math.deg2rad(15.0)}
    bodyrate = %{rollrate: Math.deg2rad(-20.0), pitchrate: Math.deg2rad(-45), yawrate: Math.deg2rad(90)}
    Peripherals.Uart.Estimation.VnIns.Operator.publish_vn_message(bodyrate, attitude, velocity, position)
  end
end
