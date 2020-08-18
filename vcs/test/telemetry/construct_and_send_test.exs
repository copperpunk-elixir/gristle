defmodule Telemetry.ConstructAndSendTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Construct and Send Test" do
    Logger.info("Construct and Send Test")
    delta_float_max = 0.0001
    # config = Configuration.Module.get_config(Telemetry, nil, nil)
    # {:ok, pid} = Peripherals.Uart.Telemetry.Operator.start_link(config.operator)
    tx_goals_1 = %{rollrate: 1.0, pitchrate: 2.0, yawrate: -3.0, thrust: 0.123}
    tx_goals_2 = %{roll: 10.0, pitch: 20.0, yaw: -30.0, thrust: 10.123}
    tx_goals_3a = %{speed: 10.1, course_ground: 22.3, altitude: 1234.5}
    tx_goals_3b = %{speed: 20.1, course_flight: -22.3, altitude: 1234.56}
    Pids.Moderator.publish_cmds(tx_goals_1, 1)
    Pids.Moderator.publish_cmds(tx_goals_2, 2)
    Pids.Moderator.publish_cmds(tx_goals_3a, 3)
    Pids.Moderator.publish_cmds(tx_goals_3b, 3)
    Process.sleep(1000)
  end
end
