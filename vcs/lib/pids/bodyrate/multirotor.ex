defmodule Pids.Bodyrate.Multirotor do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float(), map()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt, motor_moments) do
    throttle_output = cmds.thrust
    airspeed = if (throttle_output < 0.05), do: -100000, else: airspeed
    aileron_output = Pids.Pid.update_pid(:rollrate, :aileron, cmds.rollrate, values.rollrate, airspeed, dt)
    elevator_output = Pids.Pid.update_pid(:pitchrate, :elevator, cmds.pitchrate, values.pitchrate, airspeed, dt)
    rudder_output = Pids.Pid.update_pid(:yawrate, :rudder, cmds.yawrate, values.yawrate, airspeed, dt)
    Enum.reduce(motor_moments, %{}, fn ({motor_name, {roll_mult, pitch_mult, yaw_mult}}, acc) ->
      motor_output =
      if throttle_output < 0.05 do
        0.0
      else
        rp_output =
          Common.Utils.Math.constrain(throttle_output, 0, 0.6) +
        cmd_multiplier(aileron_output, roll_mult, 0.5) +
        cmd_multiplier(elevator_output, pitch_mult, 0.5)
        thrust_remaining = 1.0 - rp_output
        yaw_output = cmd_multiplier(rudder_output, 0.5*yaw_mult, 0.5)
        |> Common.Utils.Math.constrain(-thrust_remaining, thrust_remaining)
        rp_output + yaw_output
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
