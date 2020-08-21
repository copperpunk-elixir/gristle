defmodule Pids.UpdatePaxTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    vehicle_type = :Plane
    node_type = :loopback
    Comms.System.start_link()
    Process.sleep(100)
    Configuration.Module.start_modules([Pids, Peripherals.Uart], vehicle_type, node_type)
    {:ok, []}
  end

  test "Set Pid Test" do
    Process.sleep(200)
    Logger.info("Set Pid Test")
    rr_ail_kp = 0.1234
    pv = :speed
    ov = :thrust
    param = :kp
    Pids.Pid.get_pid_gain(pv, ov, param)
    Pids.Pid.get_pid_gain(pv, ov, :ki)
    Pids.Pid.get_pid_gain(pv, ov, :kd)
    Pids.Pid.get_pid_gain(pv, ov, :output_min)
    Pids.Pid.set_pid_gain(pv, ov, param, rr_ail_kp)
    Process.sleep(100)
    Pids.Pid.get_pid_gain(pv, ov, param)
    Process.sleep(1000)
  end
end
