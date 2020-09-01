defmodule Pids.Tecs do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    # Logger.debug("tecs cmds: #{inspect(cmds)}")
    # Values
    speed = values.speed
    vv = values.vertical
    altitude = values.altitude
    # CMds
    speed_cmd = cmds.speed
    alt_cmd = cmds.altitude

    # Energy Cals
    potential_energy = Common.Constants.gravity()*altitude
    kinetic_energy = 0.5*speed*speed

    potential_energy_sp = Common.Constants.gravity()*alt_cmd
    kinetic_energy_sp = 0.5*speed_cmd*speed_cmd


    energy = potential_energy + kinetic_energy
    energy_sp = potential_energy_sp + kinetic_energy_sp

    flight_path_angle =
    if (speed > 5.0) do
      vv/speed
    else
      0.0
    end

    speed_dot_sp = (speed_cmd - speed)/dt
    flight_path_angle_sp =
    if (speed_cmd > 1.0) do
      (alt_cmd - altitude)/speed_cmd
    else
      0.0
    end

    # TECS calcs
    # Energy (thrust)
    energy_cmds =%{
      energy: energy_sp,
      potential_energy_rate: flight_path_angle_sp,
      speed: speed_cmd,
      speed_dot: speed_dot_sp,
    }
    energy_values = %{
      energy: energy,
      potential_energy_rate: flight_path_angle,
      speed: speed
    }

    thrust_output = Pids.Pid.update_pid(:tecs, :thrust, energy_cmds, energy_values, airspeed, dt)

    # Balance (pitch)
    balance_cmds = %{
      kinetic_energy: kinetic_energy_sp,
      potential_energy: potential_energy_sp,
      potential_energy_rate: flight_path_angle_sp,
      speed: speed_cmd,
      speed_dot: speed_dot_sp,
    }
    balance_values = %{
      kinetic_energy: kinetic_energy,
      potential_energy: potential_energy,
      potential_energy_rate: flight_path_angle,
      speed: speed
    }

    pitch_output = Pids.Pid.update_pid(:tecs, :pitch, balance_cmds, balance_values, airspeed, dt)
    # pitch_output = 0.03
    %{pitch: pitch_output, thrust: thrust_output}
  end
end
