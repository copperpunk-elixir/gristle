defmodule Simulation.XplaneReceive do
  require Logger
  use Bitwise
  use GenServer

  @deg2rad 0.017453293
  @ft2m 0.3048
  @knots2mps 0.51444444
  @rad2deg 57.295779513


  def start_link(config) do
    Logger.debug("Start Simulation.XplaneReceive")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    Logger.debug("recieve config: #{inspect(config)}")
    {:ok, %{
        socket: nil,
        port: config.port,
        bodyaccel: %{},
        attitude: %{},
        bodyrate: %{},
        position: %{},
        velocity: %{},
        agl: 0,
        airspeed: 0,
        new_simulation_data_to_publish: false,
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    {:ok, socket} = :gen_udp.open(state.port, [broadcast: false, active: true])
    {:noreply, %{state | socket: socket}}
  end

  @impl GenServer
  def handle_cast(:publish_pv_measured, state) do
    keys = [:attitude, :bodyrate, :bodyaccel, :velocity, :position]
    value_map = Enum.reduce(keys, %{}, fn (key, acc) ->
      value = Map.get(state,key)
      if Enum.empty?(value), do: %{}, else: Map.put(acc, key, value)
    end)

    unless Enum.empty?(value_map) do
      Comms.Operator.send_local_msg_to_group(__MODULE__, {:pv_measured, value_map}, :pv_measured, self())
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:udp, _socket, _src_ip, _src_port, msg}, state) do
    # Logger.info("received data from #{inspect(src_ip)} on port #{src_port} with length #{length(msg)}")
    state = parse_data_buffer(msg, state)
    state =
    if state.new_simulation_data_to_publish == true do
      # publish_simulation_data(state)
      publish_perfect_simulation_data(state)
      %{state | new_simulation_data_to_publish: false}
    else
      state
    end
    {:noreply, state}
  end

  @spec parse_data_buffer(list(), map()) :: map()
  def parse_data_buffer(entire_buffer, state) do
    {header, data_buffer} = Enum.split(entire_buffer, 4)
    if (header == [68,65,84,65]) do
      data_buffer = Enum.drop(data_buffer,1)
      parse_message(data_buffer, state)
    else
      state
    end
  end

  @spec parse_message(list(), map()) :: map()
  def parse_message(buffer, state) do
    message_type = Enum.at(buffer,0)
    buffer = Enum.drop(buffer,4)
    {state, buffer} =
    if (length(buffer) >= 32) do
      state =
        case message_type do
          3 ->
            {indicated_airspeed_knots_uint32, _buffer} = Enum.split(buffer, 4)
            indicated_airspeed_knots = list_to_int(indicated_airspeed_knots_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            %{state | airspeed: indicated_airspeed_knots*@knots2mps}
          4 ->
            {_mach_uint32, buffer} = Enum.split(buffer, 4)
            {_unknown, buffer} = Enum.split(buffer, 4)
            {_unknown, buffer} = Enum.split(buffer, 4)
            {_unknown, buffer} = Enum.split(buffer, 4)
            {accel_z_g_int32, buffer} = Enum.split(buffer, 4)
            {accel_x_g_uint32, buffer} = Enum.split(buffer, 4)

            {accel_y_g_uint32, _buffer} = Enum.split(buffer, 4)

            accel_z_mpss =
              list_to_int(accel_z_g_int32,4) |> Common.Utils.Math.fp_from_uint(32)
              |> Kernel.-(1)
              |> Kernel.*(Common.Constants.gravity())
            accel_x_mpss = list_to_int(accel_x_g_uint32,4) |> Common.Utils.Math.fp_from_uint(32) |> Kernel.*(Common.Constants.gravity())
            accel_y_mpss = list_to_int(accel_y_g_uint32,4) |> Common.Utils.Math.fp_from_uint(32) |> Kernel.*(Common.Constants.gravity())
            # Add accel due to gravity
            # Logger.debug("accel_mpss xyz: #{eftb(accel_x_mpss,3)}/#{eftb(accel_y_mpss, 3)}/#{eftb(accel_z_mpss, 3)}")
            attitude = if Enum.empty?(state.attitude), do: %{roll: 0.0, pitch: 0.0, yaw: 0.0}, else: state.attitude
            accel_gravity = Common.Utils.attitude_to_accel(attitude)
            accel = %{x: accel_gravity.x + accel_x_mpss, y: accel_gravity.y + accel_y_mpss, z: accel_gravity.z + accel_z_mpss}
            # Logger.debug("accel xyz: #{eftb(accel.x,3)}/#{eftb(accel.y, 3)}/#{eftb(accel.z, 3)}")
            %{state | bodyaccel: accel}
          16 ->
            {pitch_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
            {roll_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
            {yaw_rate_rad_uint32, _buffer} = Enum.split(buffer, 4)
            roll_rate_rad = list_to_int(roll_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            pitch_rate_rad = list_to_int(pitch_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            yaw_rate_rad = list_to_int(yaw_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            # Logger.debug("body: #{eftb(roll_rate_rad*@rad2deg,1)}/#{eftb(pitch_rate_rad*@rad2deg,1)}/#{eftb(yaw_rate_rad*@rad2deg,1)}")
            %{state | bodyrate: %{rollrate: roll_rate_rad, pitchrate: pitch_rate_rad, yawrate: yaw_rate_rad}}
          17 ->
            {pitch_deg_uint32, buffer} = Enum.split(buffer, 4)
            {roll_deg_uint32, buffer} = Enum.split(buffer, 4)
            {yaw_deg_uint32, _buffer} = Enum.split(buffer, 4)
            yaw_deg = list_to_int(yaw_deg_uint32, 4) |> Common.Utils.Math.fp_from_uint(32)
            pitch_deg = list_to_int(pitch_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            roll_deg = list_to_int(roll_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            # Logger.debug("rpy: #{eftb(roll_deg,1)}/#{eftb(pitch_deg, 1)}/#{eftb(yaw_deg, 1)}")
            %{state | attitude: %{roll: roll_deg*@deg2rad, pitch: pitch_deg*@deg2rad, yaw: yaw_deg*@deg2rad}}
          20 ->
            {latitude_deg_uint32, buffer} = Enum.split(buffer, 4)
            {longitude_deg_uint32, buffer} = Enum.split(buffer, 4)
            {altitude_ft_uint32, buffer} = Enum.split(buffer, 4)
            {agl_ft_uint32, _buffer} = Enum.split(buffer, 4)
            latitude_deg = list_to_int(latitude_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            longitude_deg = list_to_int(longitude_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            altitude_ft = list_to_int(altitude_ft_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            agl_ft = list_to_int(agl_ft_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            # Logger.debug("lat/lon/alt: #{eftb(latitude_deg,7)}/#{eftb(longitude_deg, 7)}/#{eftb(altitude_ft, 1)}/#{eftb(agl_ft,1)}")
            %{state | position: %{latitude: latitude_deg*@deg2rad, longitude: longitude_deg*@deg2rad, altitude: altitude_ft*@ft2m}, agl: agl_ft*@ft2m}
          21 ->
            buffer = Enum.drop(buffer, 12)
            {vel_east_mps_uint32, buffer} = Enum.split(buffer, 4)
            {vel_up_mps_uint32, buffer} = Enum.split(buffer, 4)
            {vel_south_mps_uint32, _buffer} = Enum.split(buffer, 4)
            vel_north_mps = -(list_to_int(vel_south_mps_uint32,4) |> Common.Utils.Math.fp_from_uint(32))
            vel_east_mps = list_to_int(vel_east_mps_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            vel_down_mps = -(list_to_int(vel_up_mps_uint32,4) |> Common.Utils.Math.fp_from_uint(32))
            # Logger.debug("vNED: #{eftb(vel_north_mps,1)}/#{eftb(vel_east_mps, 1)}/#{eftb(vel_down_mps, 1)}")
            GenServer.cast(__MODULE__, :publish_pv_measured)
            %{state | velocity: %{north: vel_north_mps, east: vel_east_mps, down: vel_down_mps}}
          _other ->
            Logger.debug("unknown type")
            state
        end
      {%{state | new_simulation_data_to_publish: true}, Enum.drop(buffer,32)}
    else
      {state, []}
    end

    # If there is more data in the buffer, parse it
    unless Enum.empty?(buffer) do
      parse_message(buffer, state)
    else
      state
    end
  end

  @spec publish_perfect_simulation_data(map()) ::atom()
  def publish_perfect_simulation_data(state) do
    attitude_bodyrate_value_map = %{attitude: state.attitude, bodyrate: state.bodyrate}
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :attitude_bodyrate}, attitude_bodyrate_value_map}, {:pv_calculated, :attitude_bodyrate}, self())
    position_velocity_value_map = %{position: state.position, velocity: state.velocity}
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :position_velocity}, position_velocity_value_map}, {:pv_calculated, :position_velocity}, self())
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :airspeed}, state.airspeed}, {:pv_calculated, :airspeed}, self())
    if !is_nil(state.attitude) do
      range_meas =state.agl/(:math.cos(state.attitude.roll)*:math.cos(state.attitude.pitch))
      if range_meas < Peripherals.Uart.TerarangerEvo.max_range() do
        Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_measured, :range}, range_meas}, {:pv_measured, :range}, self())
      end
    end
  end

  @spec publish_simulation_data(map()) ::atom()
  def publish_simulation_data(state) do
    pv_measured = %{attitude: state.attitude, bodyrate: state.bodyrate, bodyaccel: state.bodyaccel, position: state.position, velocity: state.velocity}
    Comms.Operator.send_local_msg_to_group(__MODULE__, {:pv_measured, pv_measured}, :pv_measured, self())
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :agl}, state.agl}, {:pv_calculated, :agl}, self())
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :airspeed}, state.airspeed}, {:pv_calculated, :airspeed}, self())
  end

  @spec list_to_int(list(), integer()) :: integer()
  defp list_to_int(x_list, bytes) do
    Enum.reduce(0..bytes-1, 0, fn(index,acc) ->
      acc + (Enum.at(x_list,index)<<<(8*index))
    end)
  end

  defp eftb(num, dec) do
    Common.Utils.eftb(num,dec)
  end

end
