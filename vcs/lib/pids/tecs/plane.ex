defmodule Pids.Tecs.Plane do
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
    potential_energy = Common.Constants.gravity*altitude
    kinetic_energy = 0.5*speed*speed

    dV = Common.Utils.Math.constrain(speed_cmd-speed,-5.0, 5.0)
    speed_sp = speed_cmd
    potential_energy_sp = Common.Constants.gravity*alt_cmd
    kinetic_energy_sp = 0.5*speed_sp*speed_sp
    # Logger.info("pe/pe_sp: #{Common.Utils.eftb(potential_energy,1)}/#{Common.Utils.eftb(potential_energy_sp,1)}")

    energy = potential_energy + kinetic_energy
    energy_sp = potential_energy_sp + kinetic_energy_sp
    speed_dot_sp = dV*dt

    kinetic_energy_rate_sp = speed*speed_dot_sp
    potential_energy_rate = vv*Common.Constants.gravity

    # TECS calcs
    # Energy (thrust)
    energy_cmds =%{
      energy: energy_sp,
      kinetic_energy_rate: kinetic_energy_rate_sp,
      altitude_corr: alt_cmd-altitude,
      speed: speed_cmd
    }
    energy_values = %{
      energy: energy,
      potential_energy_rate: potential_energy_rate,
      speed: speed
    }

    thrust_output = 0.8#Pids.Pid.update_pid(:tecs, :thrust, energy_cmds, energy_values, values.airspeed, dt)

    # Balance (pitch)
    balance_cmds = %{
      kinetic_energy: kinetic_energy_sp,
      kinetic_energy_rate: kinetic_energy_rate_sp,
      altitude_corr: alt_cmd - altitude,
      speed: speed_cmd
    }
    balance_values = %{
      kinetic_energy: kinetic_energy,
      potential_energy: potential_energy,
      potential_energy_rate: potential_energy_rate,
      speed: speed
    }

    pitch_output = Pids.Pid.update_pid(:tecs, :pitch, speed_cmd, speed, values.airspeed, dt)
    %{pitch: pitch_output, thrust: thrust_output}
  end
end
