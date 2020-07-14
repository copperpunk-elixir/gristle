defmodule Common.Utils.DcmTest do
  use ExUnit.Case
  require Logger


  test "Intertial to Body aces" do
    max_delta_rad = 0.0001
    attitude = %{roll: 0, pitch: 0, yaw: 0} |> Common.Utils.map_deg2rad()
    inertial_accel = {0,0,1}
    {ax,ay,az} = Common.Utils.inertial_to_body_euler(attitude, inertial_accel)
    assert_in_delta(ax,0,max_delta_rad)
    assert_in_delta(ay,0,max_delta_rad)
    assert_in_delta(az,1.0,max_delta_rad)
    attitude = %{roll: 45, pitch: 0, yaw: 0} |> Common.Utils.map_deg2rad()
    inertial_accel = {0,0,1}
    {ax,ay,az} = Common.Utils.inertial_to_body_euler(attitude, inertial_accel)
    assert_in_delta(ax,0,max_delta_rad)
    assert_in_delta(ay,:math.sqrt(2)/2,max_delta_rad)
    assert_in_delta(az,:math.sqrt(2)/2,max_delta_rad)

    attitude = %{roll: 0, pitch: 30, yaw: 0} |> Common.Utils.map_deg2rad()
    inertial_accel = {1,0,0}
    {ax,ay,az} = Common.Utils.inertial_to_body_euler(attitude, inertial_accel)
    assert_in_delta(ax,:math.cos(:math.pi/6),max_delta_rad)
    assert_in_delta(ay,0,max_delta_rad)
    assert_in_delta(az,:math.sin(:math.pi/6),max_delta_rad)

    attitude = %{roll: 30, pitch: 0, yaw: 0} |> Common.Utils.map_deg2rad()
    inertial_accel = {0,-1,0}
    {ax,ay,az} = Common.Utils.inertial_to_body_euler(attitude, inertial_accel)
    assert_in_delta(ax,0,max_delta_rad)
    assert_in_delta(ay,-:math.cos(:math.pi/6),max_delta_rad)
    assert_in_delta(az,:math.sin(:math.pi/6),max_delta_rad)

    attitude = %{roll: -30, pitch: 0, yaw: 0} |> Common.Utils.map_deg2rad()
    inertial_accel = {0,-1,0}
    {ax,ay,az} = Common.Utils.inertial_to_body_euler(attitude, inertial_accel)
    assert_in_delta(ax,0,max_delta_rad)
    assert_in_delta(ay,-:math.cos(:math.pi/6),max_delta_rad)
    assert_in_delta(az,-:math.sin(:math.pi/6),max_delta_rad)

  end
end
