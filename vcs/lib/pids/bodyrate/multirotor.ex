defmodule Pids.Bodyrate.Multirotor do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float(), map()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt, motor_moments) do
    aileron_output = Pids.Pid.update_pid(:rollrate, :aileron, cmds.rollrate, values.rollrate, airspeed, dt)
    elevator_output = Pids.Pid.update_pid(:pitchrate, :elevator, cmds.pitchrate, values.pitchrate, airspeed, dt)
    rudder_output = Pids.Pid.update_pid(:yawrate, :rudder, cmds.yawrate, values.yawrate, airspeed, dt)
    throttle_output = cmds.thrust
    # Logger.debug("pitch cmd/val: #{Common.Utils.eftb_deg(cmds.pitchrate,0)}/#{Common.Utils.eftb_deg(values.pitchrate,0)}")
    output_str =
      Common.Utils.eftb(aileron_output,2) <> "/" <>
      Common.Utils.eftb(elevator_output,2) <> "/" <>
      Common.Utils.eftb(throttle_output,2) <> "/" <>
      Common.Utils.eftb(rudder_output, 2)
    Logger.debug("yr cmd/value: #{Common.Utils.eftb_deg(cmds.yawrate,1)}/#{Common.Utils.eftb_deg(values.yawrate,1)}")
    Logger.debug("bodyrate output: ail/elev/thr/rud: #{output_str}")
    Enum.reduce(motor_moments, %{}, fn ({motor_name, {roll_mult, pitch_mult, yaw_mult}}, acc) ->
      motor_output = throttle_output +
      cmd_multiplier(aileron_output, roll_mult) +
      cmd_multiplier(elevator_output, pitch_mult) +
      cmd_multiplier(rudder_output, yaw_mult)
      |> Common.Utils.Math.constrain(0, 1.0)
      Map.put(acc, motor_name, motor_output)
    end)
  end

  @spec cmd_multiplier(float(), float()) :: float()
  def cmd_multiplier(cmd, mult) do
    if cmd*mult > 0 do
      cmd*mult
    else
      0#.5*cmd*mult
    end
  end

end
