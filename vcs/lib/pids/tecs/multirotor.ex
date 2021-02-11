defmodule Pids.Tecs.Multirotor do
  require Logger
  require Common.Constants

  @spec calculate_outputs(map(), map(), float()) :: map()
  def calculate_outputs(cmds, values, dt) do
    # Values
    speed = values.speed
    vv = values.vertical
    # Logger.debug("vv: #{Common.Utils.eftb(vv,2)}")
    altitude = values.altitude
    # CMDs
    speed_cmd = cmds.speed
    alt_cmd = cmds.altitude

    # Logger.debug("alt cmd/value/err: #{Common.Utils.eftb(alt_cmd,1)}/#{Common.Utils.eftb(altitude,1)}/#{Common.Utils.eftb(alt_cmd - altitude,1)}")
    # Energy Cals
    dV = Common.Utils.Math.constrain(speed_cmd-speed,-5.0, 5.0)
    # Logger.debug("dv: #{dV}")
    speed_dot_sp = dV*dt

    kinetic_energy_rate_sp = speed*speed_dot_sp
    potential_energy_rate = vv*Common.Constants.gravity

    alt_rate = (alt_cmd-altitude)*0.5

    potential_energy_rate_sp = alt_rate*Common.Constants.gravity
    energy_rate_sp = kinetic_energy_rate_sp + potential_energy_rate_sp
    # THIS IS WRONG
    # This PID should probably be it's own kind
    kinetic_energy_rate = 0*speed
    # Logger.debug("KEr/PEr: #{Common.Utils.eftb(kinetic_energy_rate_sp, 2)}/#{Common.Utils.eftb(potential_energy_rate_sp, 2)}")
    energy_rate = kinetic_energy_rate + potential_energy_rate

    # Logger.info("e/e_sp: #{Common.Utils.eftb(energy_rate_sp,1)}/#{Common.Utils.eftb(energy_rate,1)}")
    Pids.Pid.update_pid(:tecs, :thrust, energy_rate_sp, energy_rate, values.airspeed, dt)
  end
end
