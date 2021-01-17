defmodule Pids.Multirotor.BodyrateTest do
  use ExUnit.Case
  require Logger
  setup do
    RingLogger.attach()
    Boss.System.common_prepare()
    Logging.System.start_link(Boss.System.get_config(Logging, nil, nil))
    Process.sleep(100)
    {:ok, []}
  end

  test "Update PIDs realtime" do
    vehicle_type = :Multirotor
    pid_config = Configuration.Module.Pids.get_config("QuadX", nil)
    motor_moments = pid_config[:motor_moments]
    pids = pid_config[:pids]
    Pids.System.start_link(pid_config)

    values = %{rollrate: 0, pitchrate: 0, yawrate: 0}
    cmds= %{rollrate: 0.1, pitchrate: 0, yawrate: 0, thrust: 0.5}
    output = Pids.Bodyrate.Multirotor.calculate_outputs(cmds, values, 0, 0.02, motor_moments)
    Logger.debug(inspect(output))
    assert output.motor1 < cmds.thrust
    assert output.motor2 > cmds.thrust
    assert output.motor3 > cmds.thrust
    assert output.motor4 < cmds.thrust

    values = %{rollrate: 0, pitchrate: 0, yawrate: 0}
    cmds= %{rollrate: 0.1, pitchrate: 0.2, yawrate: 0, thrust: 0.5}
    output = Pids.Bodyrate.Multirotor.calculate_outputs(cmds, values, 0, 0.02, motor_moments)
    Logger.debug(inspect(output))
    Process.sleep(100)
    assert output.motor1 > cmds.thrust
    assert output.motor2 < cmds.thrust
    assert output.motor3 > cmds.thrust
    assert output.motor4 < cmds.thrust

    values = %{rollrate: 0, pitchrate: 0, yawrate: 0}
    cmds= %{rollrate: 0.0, pitchrate: 0.0, yawrate: 0.2, thrust: 0.5}
    output = Pids.Bodyrate.Multirotor.calculate_outputs(cmds, values, 0, 0.02, motor_moments)
    Logger.debug(inspect(output))
    Process.sleep(100)
    assert output.motor1 > cmds.thrust
    assert output.motor2 > cmds.thrust
    assert output.motor3 < cmds.thrust
    assert output.motor4 < cmds.thrust

  end
end
