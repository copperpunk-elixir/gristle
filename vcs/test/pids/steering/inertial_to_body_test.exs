defmodule Pids.Steering.InertialToBodyTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    {:ok, []}
  end

  test "roll and pitch from tilt test" do
    tilt_cmd = Common.Utils.Math.deg2rad(10)
    course_cmd = Common.Utils.Math.deg2rad(0)
    yaw = Common.Utils.Math.deg2rad(30)
    rotation_yaw_to_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - yaw)
    pitch = -tilt_cmd * :math.cos(rotation_yaw_to_course)
    roll = tilt_cmd * :math.sin(rotation_yaw_to_course)
    Logger.debug("pitch/roll: #{Common.Utils.eftb_deg(pitch, 1)}/#{Common.Utils.eftb_deg(roll, 1)}")
    Process.sleep(100)
    assert pitch < 0
    assert roll < 0

    tilt_cmd = Common.Utils.Math.deg2rad(10)
    course_cmd = Common.Utils.Math.deg2rad(0)
    yaw = Common.Utils.Math.deg2rad(-30)
    rotation_yaw_to_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - yaw)
    pitch = -tilt_cmd * :math.cos(rotation_yaw_to_course)
    roll = tilt_cmd * :math.sin(rotation_yaw_to_course)
    Logger.debug("pitch/roll: #{Common.Utils.eftb_deg(pitch, 1)}/#{Common.Utils.eftb_deg(roll, 1)}")
    Process.sleep(100)
    assert pitch < 0
    assert roll > 0

    tilt_cmd = Common.Utils.Math.deg2rad(10)
    course_cmd = Common.Utils.Math.deg2rad(150)
    yaw = Common.Utils.Math.deg2rad(30)
    rotation_yaw_to_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - yaw)
    pitch = -tilt_cmd * :math.cos(rotation_yaw_to_course)
    roll = tilt_cmd * :math.sin(rotation_yaw_to_course)
    Logger.debug("pitch/roll: #{Common.Utils.eftb_deg(pitch, 1)}/#{Common.Utils.eftb_deg(roll, 1)}")
    Process.sleep(100)
    assert pitch > 0
    assert roll > 0

 end
end
