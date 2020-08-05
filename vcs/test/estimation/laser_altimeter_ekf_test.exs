defmodule Estimation.LaserAltimeterEkfTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    Comms.System.start_link()
    Process.sleep(100)
    config = Configuration.Module.get_config(Estimation, vehicle_type, :all)
    Estimation.Estimator.start_link(config.estimator)
    # Estimation.System.start_link(config)
    {:ok, []}
  end

  # test "Run LaserAlt Test" do
  #   dt_imu = 0.02
  #   zdot = -1
  #   dt_range = 0.1
  #   angle_var = 100*:math.pi/180
  #   range_altimeter = Estimation.LaserAltimeterEkf.new(%{})
  #   Logger.debug("laseralt: #{inspect(range_altimeter)}")
  #   start_time = :os.system_time(:millisecond)
  #   state = %{phi: 0, theta: 0, z: 100, ra: range_altimeter, measure_time: start_time}
  #   state =
  #     Enum.reduce(0..500, state, fn (_i, state) ->
  #       current_time = :os.system_time(:millisecond)
  #       dt_since_measure = (current_time - state.measure_time)*0.001
  #       z = state.z + zdot*dt_imu
  #       phi = state.phi + :rand.normal(0,angle_var)*dt_imu
  #       theta = state.theta + :rand.normal(0,angle_var)*dt_imu
  #       v = :rand.normal(zdot,0.5)
  #       ra = Estimation.LaserAltimeterEkf.predict(state.ra, phi, theta, v)
  #       # Logger.info("pred agl/agl_est: #{z}/#{Estimation.LaserAltimeterEkf.agl(ra)}")
  #       {ra, measure_time} = if(dt_since_measure > dt_range) do
  #         # Logger.info("meas")
  #         sign_z_error = :rand.normal()
  #         z_meas = z/(:math.cos(phi)*:math.cos(theta))
  #         z_meas = if (sign_z_error>0), do: z_meas*1.015, else: z_meas*0.985
  #         # Logger.warn("z_meas: #{z_meas}")
  #         {Estimation.LaserAltimeterEkf.update(ra, z_meas), current_time}
  #       else
  #         {ra, state.measure_time}
  #       end
  #       Process.sleep(round(dt_imu*1000))
  #       # Logger.info("agl/agl_est: #{z}/#{Estimation.LaserAltimeterEkf.agl(ra)}")
  #       %{phi: phi, theta: theta, z: z, ra: ra, measure_time: measure_time}
  #     end)
  #   z_est = Estimation.LaserAltimeterEkf.agl(state.ra)
  #   Logger.info("est/act: #{z_est}/#{state.z}")
  #   assert_in_delta(z_est,state.z, 1.0)
  # end

  # test "Calculate AGL inside Estimator" do
  #   Comms.System.start_operator(__MODULE__)
  #   dt_imu = 0.02
  #   zdot = -1
  #   dt_range = 0.1
  #   angle_var = 100*:math.pi/180
  #   range_altimeter = Estimation.LaserAltimeterEkf.new(%{})
  #   start_time = :os.system_time(:millisecond)
  #   state = %{phi: 0, theta: 0, z: 50, measure_time: start_time}
  #   bodyrate = %{rollrate: 0, pitchrate: 0, yawrate: 0}
  #   position = %{latitude: 0, longitude: 0, altitude: 0}
  #   state =
  #     Enum.reduce(0..500, state, fn (_i, state) ->
  #       current_time = :os.system_time(:millisecond)
  #       dt_since_measure = (current_time - state.measure_time)*0.001
  #       z = state.z + zdot*dt_imu
  #       phi = state.phi + :rand.normal(0,angle_var)*dt_imu
  #       |> Common.Utils.Math.constrain(-0.6, 0.6)
  #       theta = state.theta + :rand.normal(0,angle_var)*dt_imu
  #       |> Common.Utils.Math.constrain(-0.6, 0.6)
  #       v = :rand.normal(zdot,0.5)
  #       # Send to PosVel update to Estimator
  #       attitude = %{roll: phi, pitch: theta, yaw: 0}
  #       attitude_bodyrate_value_map = %{attitude: attitude, bodyrate: bodyrate}
  #       Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :attitude_bodyrate}, attitude_bodyrate_value_map}, {:pv_calculated, :attitude_bodyrate}, self())
  #       velocity = %{north: 0, east: 0, down: -v}
  #       position_velocity_value_map = %{position: position, velocity: velocity}
  #       Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :position_velocity}, position_velocity_value_map}, {:pv_calculated, :position_velocity}, self())

  #       # Logger.info("pred agl/agl_est: #{z}/#{Estimation.LaserAltimeterEkf.agl(ra)}")
  #       measure_time = if(dt_since_measure > dt_range) do
  #         # Logger.info("meas")
  #         sign_z_error = :rand.normal()
  #         z_meas = z/(:math.cos(phi)*:math.cos(theta))
  #         z_meas = if (sign_z_error>0), do: z_meas*1.015, else: z_meas*0.985
  #         # Logger.warn("z_meas: #{z_meas}")
  #         # Send range measured to Estimator
  #         Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_measured, :range}, z_meas}, {:pv_measured, :range}, self())
  #         # {Estimation.LaserAltimeterEkf.update(ra, z_meas), current_time}
  #         current_time
  #       else
  #         state.measure_time
  #       end
  #       Process.sleep(round(dt_imu*1000))
  #       # Logger.info("agl/agl_est: #{z}/#{Estimation.LaserAltimeterEkf.agl(ra)}")
  #       %{phi: phi, theta: theta, z: z, measure_time: measure_time}
  #     end)
  #   z_est = Estimation.Estimator.get_range()
  #   Logger.info("est/act: #{z_est}/#{state.z}")
  #   assert_in_delta(z_est,state.z, 1.0)

  # end

  test "Range with TerarangerEvo Test" do
    Comms.System.start_operator(__MODULE__)
    Peripherals.Uart.TerarangerEvo.start_link(%{device_description: "STM32"})
    Peripherals.Uart.VnIns.start_link(Configuration.Module.Estimation.get_vn_ins_config(nil))
    Process.sleep(200000)
  end
end
