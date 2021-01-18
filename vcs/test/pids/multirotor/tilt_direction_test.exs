defmodule Pids.Multirotor.TiltDirectionTest do
  use ExUnit.Case
  require Logger
  setup do
    RingLogger.attach()
    Boss.System.common_prepare()
    Logging.System.start_link(Boss.System.get_config(Logging, nil, nil))
    Process.sleep(100)
    {:ok, []}
  end

  test "Vx-Vy test" do
    pids = Configuration.Vehicle.Multirotor.Pids.QuadX.get_pids()
    |> Keyword.get(:tecs)
    |> Keyword.take([:pitch, :roll])

    Enum.each(pids, fn {name, pid} ->
      Pids.Pid.start_link(Keyword.put(pid, :name, {:tecs,name}))
    end)
    Process.sleep(1000)
    # cmds = %{speed: 10.0, course_flight: 0, yaw: 0, yaw_offset: 0}
    # values = %{speed: 0, course: 0, yaw: 0}
    # output = Pids.Steering.Multirotor.calculate_outputs(cmds, values, 0, 0.05)
    # Logger.debug(inspect(output))
    # assert output.pitch < 0

    # cmds = %{speed: 10.0, course_flight: :math.pi, yaw: 0, yaw_offset: 0}
    # values = %{speed: 0, course: 0, yaw: 0}
    # output = Pids.Steering.Multirotor.calculate_outputs(cmds, values, 0, 0.05)
    # Logger.debug(inspect(output))
    # assert output.pitch > 0

    # cmds = %{speed: 10.0, course_flight: :math.pi/2, yaw: 0, yaw_offset: 0}
    # values = %{speed: 0, course: 0, yaw: 0}
    # output = Pids.Steering.Multirotor.calculate_outputs(cmds, values, 0, 0.05)
    # Logger.debug(inspect(output))
    # assert abs(output.pitch) < 0.01
    # assert output.roll > 0

    # cmds = %{speed: 10.0, course_flight: :math.pi/2, yaw: 0, yaw_offset: 0}
    # values = %{speed: 1.0, course: :math.pi, yaw: 0}
    # output = Pids.Steering.Multirotor.calculate_outputs(cmds, values, 0, 0.05)
    # Logger.debug(inspect(output))
    # assert output.pitch < 0.0
    # assert output.roll > 0

    # cmds = %{speed: 10.0, course_flight: 0.9*:math.pi/2, yaw: 0, yaw_offset: 0}
    # values = %{speed: 1.0, course: 0.1, yaw: :math.pi/2}
    # output = Pids.Steering.Multirotor.calculate_outputs(cmds, values, 0, 0.05)
    # Logger.debug(inspect(output))
    # assert output.pitch < 0.0
    # assert output.roll < 0

    cmds = %{speed: 0.0, course_flight: 0.9*:math.pi/2, yaw: 0, yaw_offset: 0}
    values = %{speed: 10.0, course: :math.pi/4, yaw: :math.pi/2}
    output = Pids.Steering.Multirotor.calculate_outputs(cmds, values, 0, 0.05)
    Logger.debug(inspect(output))
    assert output.pitch > 0.0
    assert output.roll < 0

    Process.sleep(100)
  end


  # test "Tilt Direction Test" do
  #   course_cmd = 0
  #   yaw = :math.pi
  #   course = :math.pi
  #   tilt_cmd = -0.2
  #   rotation_yaw_to_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - yaw)
  #   tilt_cmd = tilt_cmd*Pids.Steering.Multirotor.get_tilt_direction(rotation_yaw_to_course)
  #   Logger.debug("rytc: #{Common.Utils.eftb_deg(rotation_yaw_to_course, 2)}")
  #   course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - course)
  #   pitch_cmd = -tilt_cmd * :math.cos(rotation_yaw_to_course)
  #   roll_cmd = tilt_cmd * :math.sin(rotation_yaw_to_course)
  #   Logger.debug("pitch/roll: #{Common.Utils.eftb(pitch_cmd,2)}/#{Common.Utils.eftb(roll_cmd,2)}")
  #   assert pitch_cmd > 0

  #   course_cmd = 0
  #   yaw = 0.05
  #   course = 0.07
  #   tilt_cmd = -0.2
  #   rotation_yaw_to_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - yaw)
  #   tilt_cmd = tilt_cmd*Pids.Steering.Multirotor.get_tilt_direction(rotation_yaw_to_course)
  #   Logger.debug("rytc: #{Common.Utils.eftb_deg(rotation_yaw_to_course, 2)}")
  #   course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - course)
  #   pitch_cmd = -tilt_cmd * :math.cos(rotation_yaw_to_course)
  #   roll_cmd = tilt_cmd * :math.sin(rotation_yaw_to_course)
  #   Logger.debug("pitch/roll: #{Common.Utils.eftb(pitch_cmd,2)}/#{Common.Utils.eftb(roll_cmd,2)}")
  #   assert pitch_cmd > 0

  #   course_cmd = 0
  #   yaw = 0.05
  #   course = 0.07
  #   tilt_cmd = 0.2
  #   rotation_yaw_to_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - yaw)
  #   tilt_cmd = tilt_cmd*Pids.Steering.Multirotor.get_tilt_direction(rotation_yaw_to_course)
  #   Logger.debug("rytc: #{Common.Utils.eftb_deg(rotation_yaw_to_course, 2)}")
  #   course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - course)
  #   pitch_cmd = -tilt_cmd * :math.cos(rotation_yaw_to_course)
  #   roll_cmd = tilt_cmd * :math.sin(rotation_yaw_to_course)
  #   Logger.debug("pitch/roll: #{Common.Utils.eftb(pitch_cmd,2)}/#{Common.Utils.eftb(roll_cmd,2)}")
  #   assert pitch_cmd < 0

  #   course_cmd = :math.pi/2
  #   yaw = 0.05
  #   course = 0.07
  #   tilt_cmd = 0.2
  #   rotation_yaw_to_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - yaw)
  #   tilt_cmd = tilt_cmd*Pids.Steering.Multirotor.get_tilt_direction(rotation_yaw_to_course)
  #   Logger.debug("rytc: #{Common.Utils.eftb_deg(rotation_yaw_to_course, 2)}")
  #   course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - course)
  #   pitch_cmd = -tilt_cmd * :math.cos(rotation_yaw_to_course)
  #   roll_cmd = tilt_cmd * :math.sin(rotation_yaw_to_course)
  #   Logger.debug("pitch/roll: #{Common.Utils.eftb(pitch_cmd,2)}/#{Common.Utils.eftb(roll_cmd,2)}")
  #   assert pitch_cmd < 0
  #   assert roll_cmd > 0

  #   course_cmd = :math.pi/2
  #   yaw = 0.05
  #   course = 0.07
  #   tilt_cmd = -0.2
  #   rotation_yaw_to_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - yaw)
  #   tilt_cmd = tilt_cmd*Pids.Steering.Multirotor.get_tilt_direction(rotation_yaw_to_course)
  #   Logger.debug("rytc: #{Common.Utils.eftb_deg(rotation_yaw_to_course, 2)}")
  #   course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd - course)
  #   pitch_cmd = -tilt_cmd * :math.cos(rotation_yaw_to_course)
  #   roll_cmd = tilt_cmd * :math.sin(rotation_yaw_to_course)
  #   Logger.debug("pitch/roll: #{Common.Utils.eftb(pitch_cmd,2)}/#{Common.Utils.eftb(roll_cmd,2)}")
  #   assert pitch_cmd > 0
  #   assert roll_cmd > 0

  #   Process.sleep(100)
  # end
end
