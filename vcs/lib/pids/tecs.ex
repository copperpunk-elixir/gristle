defmodule Pids.Tecs do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    # Logger.debug("tecs cmds: #{inspect(cmds)}")
    # Values
    speed = values.speed
    vv = values.vertical
    Logger.debug("vv: #{Common.Utils.eftb(vv,2)}")
    altitude = values.altitude
    # CMds
    speed_cmd = cmds.speed
    alt_cmd = cmds.altitude

    # Energy Cals
    potential_energy = Common.Constants.gravity()*altitude
    kinetic_energy = 0.5*speed*speed

    dV = Common.Utils.Math.constrain(speed_cmd-speed,-5.0, 5.0)
    speed_sp = speed_cmd# + dV
    potential_energy_sp = Common.Constants.gravity()*alt_cmd
    kinetic_energy_sp = 0.5*speed_sp*speed_sp


    energy = potential_energy + kinetic_energy
    energy_sp = potential_energy_sp + kinetic_energy_sp
    # Logger.info("e_sp/ke/pe: #{Common.Utils.eftb(energy_sp,1)}/#{Common.Utils.eftb(kinetic_energy_sp,1)}/#{Common.Utils.eftb(potential_energy_sp,1)}")
    # flight_path_angle =
    # if (speed > 5.0) do
    #   vv/speed
    # else
    #   0.0
    # end
    speed_dot_sp = dV*dt

    kinetic_energy_rate_sp = speed*speed_dot_sp
    potential_energy_rate = vv*Common.Constants.gravity()


    # flight_path_angle_sp =
    # if (speed_cmd > 1.0) do
    #   (alt_cmd - altitude)/(speed_cmd*dt)
    # else
    #   0.0
    # end

    # TECS calcs
    # Energy (thrust)
    energy_cmds =%{
      energy: energy_sp,
      # potential_energy_rate: flight_path_angle_sp,
      kinetic_energy_rate: kinetic_energy_rate_sp,
      altitude_corr: alt_cmd-altitude,
      speed: speed_cmd
    }
    energy_values = %{
      energy: energy,
      potential_energy_rate: potential_energy_rate,
      speed: speed
    }

    thrust_output = Pids.Pid.update_pid(:tecs, :thrust, energy_cmds, energy_values, airspeed, dt)

    # Balance (pitch)
    balance_cmds = %{
      kinetic_energy: kinetic_energy_sp,
      kinetic_energy_rate: kinetic_energy_rate_sp,
      # flight_path_angle: flight_path_angle_sp,
      altitude_corr: alt_cmd - altitude,
      speed: speed_cmd
    }
    balance_values = %{
      kinetic_energy: kinetic_energy,
      potential_energy: potential_energy,
      potential_energy_rate: potential_energy_rate,
      speed: speed
    }

    pitch_output = Pids.Pid.update_pid(:tecs, :pitch, balance_cmds, balance_values, airspeed, dt)
    # pitch_output = 0.03
    %{pitch: pitch_output, thrust: thrust_output}
  end
end
