defmodule Gimbal.ControllerTest do
  require Logger
  use ExUnit.Case
  doctest Gimbal.Controller

  config = NodeConfig.Gimbal.get_config

  Common.Utils.Comms.start_registry(:topic_registry)
  Common.ProcessRegistry.start_link
  CommandSorter.System.start_link(nil)

  {:ok, pid} = Gimbal.Controller.start_link(config.gimbal_controller)
  assert Gimbal.Controller.get_parameter(:imu_ready) == false
  assert Gimbal.Controller.get_parameter(:actuators_ready) == false
  Logger.warn("Arm actuators")
  Gimbal.Controller.arm_actuators()
  assert Gimbal.Controller.get_parameter(:actuators_ready) == true
  assert Gimbal.Controller.get_parameter(:actuator_timer) != nil
  assert Gimbal.Controller.get_parameter(:none) == nil
  # Send attitude commads
  attitude_cmd_sorting = %{priority: 0, authority: 0, time_validity_ms: 200}
  GenServer.cast(Gimbal.Controller, {:attitude_cmd, attitude_cmd_sorting, %{roll: 1.0, pitch: -1.0}})
  Process.sleep(100)
  assert CommandSorter.Sorter.get_command({Gimbal.Controller, :roll}) == 1.0
  assert CommandSorter.Sorter.get_command({Gimbal.Controller, :pitch}) == -1.0
  # Send attitude update
  # will trigger PID update
  Pid.Controller.start_link(config.pid_controller)
  attitude = %{roll: -1, pitch: -2, yaw: -3}
  attitude_rate = %{roll: 10, pitch: 20, yaw: 30}
  imu_dt = 0.01
  GenServer.cast(Gimbal.Controller, {:euler_eulerrate_dt, attitude, attitude_rate, imu_dt})
  Process.sleep(10)
  assert Gimbal.Controller.get_parameter(:attitude) == attitude
  assert Gimbal.Controller.get_parameter(:attitude_rate) == attitude_rate
  assert Gimbal.Controller.get_parameter(:imu_dt) == imu_dt
end
