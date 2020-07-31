defmodule Estimation.LaserAltimeterEkfTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    Comms.System.start_link()
    Process.sleep(100)
    # config = Configuration.Module.get_config(Estimation, vehicle_type, :all)
    # Estimation.System.start_link(config)
    {:ok, []}
  end

  test "Send spoofed AGL values to estimator" do
    z = 100
    dt_imu = 0.02
    zdot = -1
    dt_range = 0.1
    angle_var = 100*:math.pi/180
    range_altimeter = Estimation.LaserAltimeterEkf.new(%{})
    Logger.debug("laseralt: #{inspect(range_altimeter)}")
    start_time = :os.system_time(:millisecond)
    state = %{phi: 0, theta: 0, z: 100, ra: range_altimeter, imu_time: start_time, measure_time: start_time}
    state =
      Enum.reduce(0..500, state, fn (_i, state) ->
        current_time = :os.system_time(:millisecond)
        dt_since_imu = (current_time - state.imu_time)*0.001
        dt_since_measure = (current_time - state.measure_time)*0.001
        z = state.z + zdot*dt_imu
        phi = state.phi + :rand.normal(0,angle_var)*dt_imu
        theta = state.theta + :rand.normal(0,angle_var)*dt_imu
        v = :rand.normal(zdot,0.5)
        ra = Estimation.LaserAltimeterEkf.predict(state.ra, phi, theta, v, dt_since_imu)
        # Logger.info("pred agl/agl_est: #{z}/#{Estimation.LaserAltimeterEkf.agl(ra)}")
        {ra, measure_time} = if(dt_since_measure > dt_range) do
          # Logger.info("meas")
          sign_z_error = :rand.normal()
          z_meas = z/(:math.cos(phi)*:math.cos(theta))
          z_meas = if (sign_z_error>0), do: z_meas*1.015, else: z_meas*0.985
          # Logger.warn("z_meas: #{z_meas}")
          {Estimation.LaserAltimeterEkf.update(ra, z_meas), current_time}
        else
          {ra, state.measure_time}
        end
        Process.sleep(round(dt_imu*1000))
        # Logger.info("agl/agl_est: #{z}/#{Estimation.LaserAltimeterEkf.agl(ra)}")
        %{phi: phi, theta: theta, z: z, ra: ra, imu_time: current_time, measure_time: measure_time}
      end)
    z_est = Estimation.LaserAltimeterEkf.agl(state.ra)
    Logger.info("est/act: #{z_est}/#{state.z}")
    assert_in_delta(z_est,state.z, 1.0)
  end
end
