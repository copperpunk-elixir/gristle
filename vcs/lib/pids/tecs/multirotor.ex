defmodule Pids.Tecs.Multirotor do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
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
    potential_energy = Common.Constants.gravity()*altitude
    kinetic_energy = 0.5*speed*speed

    dV = Common.Utils.Math.constrain(speed_cmd-speed,-5.0, 5.0)
    speed_sp = speed_cmd
    potential_energy_sp = Common.Constants.gravity()*alt_cmd
    kinetic_energy_sp = 0.5*speed_sp*speed_sp
    # Logger.info("pe/pe_sp: #{Common.Utils.eftb(potential_energy,1)}/#{Common.Utils.eftb(potential_energy_sp,1)}")

    energy = potential_energy + kinetic_energy
    energy_sp = potential_energy_sp + kinetic_energy_sp
    speed_dot_sp = dV*dt

    kinetic_energy_rate_sp = speed*speed_dot_sp
    potential_energy_rate = vv*Common.Constants.gravity()

    altitude_corr = alt_cmd-altitude
    alt_rate = altitude_corr*0.5

    potential_energy_rate_sp = alt_rate*Common.Constants.gravity()
    energy_rate_sp = kinetic_energy_rate_sp + potential_energy_rate_sp
    kinetic_energy_rate = speed*dV
    energy_rate = kinetic_energy_rate + potential_energy_rate
    # TECS calcs
    # Energy (thrust)
    # Logger.info("e/e_sp: #{Common.Utils.eftb(energy_rate_sp,1)}/#{Common.Utils.eftb(energy_rate,1)}")
    thrust_output = Pids.Pid.update_pid(:tecs, :thrust, energy_rate_sp, energy_rate, airspeed, dt)

    tilt_output = -Pids.Pid.update_pid(:tecs, :tilt, speed_cmd, speed, airspeed, dt)
    %{tilt: tilt_output, thrust: thrust_output}
  end
end
