defmodule Pids.Bodyrate.Multirotor do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float(), map()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt, motor_moments) do
    throttle_output = cmds.thrust
    airspeed = if (throttle_output < 0.05), do: -100000, else: airspeed
    aileron_output = Pids.Pid.update_pid(:rollrate, :aileron, cmds.rollrate, values.rollrate, airspeed, dt)
    elevator_output = Pids.Pid.update_pid(:pitchrate, :elevator, cmds.pitchrate, values.pitchrate, airspeed, dt)
    rudder_output = Pids.Pid.update_pid(:yawrate, :rudder, cmds.yawrate, values.yawrate, airspeed, dt)
    # Logger.debug("pitch cmd/val: #{Common.Utils.eftb_deg(cmds.pitchrate,0)}/#{Common.Utils.eftb_deg(values.pitchrate,0)}")
    output_str =
      Common.Utils.eftb(aileron_output,2) <> "/" <>
      Common.Utils.eftb(elevator_output,2) <> "/" <>
      Common.Utils.eftb(throttle_output,2) <> "/" <>
      Common.Utils.eftb(rudder_output, 2)
    # Logger.debug("rr cmd/value: #{Common.Utils.eftb_deg(cmds.rollrate,1)}/#{Common.Utils.eftb_deg(values.rollrate,1)}")
    # Logger.debug("bodyrate output: ail/elev/thr/rud: #{output_str}")
    Enum.reduce(motor_moments, %{}, fn ({motor_name, {roll_mult, pitch_mult, yaw_mult}}, acc) ->
      motor_output =
      if throttle_output < 0.05 do
        0.0
      else
        throttle_output +
        cmd_multiplier(aileron_output, roll_mult, 1.0) +
        cmd_multiplier(elevator_output, pitch_mult, 0.75) +
        cmd_multiplier(rudder_output, yaw_mult, 0)
        |> Common.Utils.Math.constrain(0, 1.0)
      end
      Map.put(acc, motor_name, motor_output)
    end)
  end

  @spec cmd_multiplier(float(), float(), float()) :: float()
  def cmd_multiplier(cmd, mult, neg_mult) do
    if cmd*mult > 0 do
      cmd*mult
    else
      neg_mult*cmd*mult
    end
  end

end
