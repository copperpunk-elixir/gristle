defmodule Pids.TecsBalanceTest do
  use ExUnit.Case
  require Logger
  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Logging.System.start_link(Configuration.Module.get_config(Logging, nil, nil))
    Process.sleep(100)
    {:ok, []}
  end

  test "Update PIDs realtime" do
    vehicle_type = :Plane
    pid_config = Configuration.Vehicle.Plane.Pids.Cessna.get_pids()
    tecs_balance_config = pid_config.tecs.pitch
    |> Map.put(:name, {:tecs, :pitch})
    Pids.Pid.start_link(tecs_balance_config)
    speed = 30
    airspeed = speed
    values = %{speed: speed, altitude: 0, vertical: 0}
    cmds = %{speed: speed, altitude: 1, vertical: 0}
    dt = 0.050
    Enum.reduce(1..40,values, fn (_x, values) ->
      Logger.info("values: #{inspect(values)}")
      output = Pids.Tecs.calculate_outputs(cmds, values, airspeed, dt)
      pitch = output.pitch
      Logger.debug("pitch: #{Common.Utils.eftb_deg(pitch,2)}")
      altitude = values.altitude + values.speed*:math.sin(pitch)*dt
      Logger.debug("altitude: #{Common.Utils.eftb(altitude,2)}")
      vertical = (values.altitude - altitude)/dt
      dv = (:random.uniform()-0.5)
      speed = values.speed + dv
      values = %{values | altitude: altitude, vertical: vertical, speed: speed}
    end)

  end
end
