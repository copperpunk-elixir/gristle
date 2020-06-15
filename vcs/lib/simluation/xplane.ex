defmodule Simulation.Xplane do
  require Logger
  use Bitwise
  use GenServer

  @deg2rad 0.017453293
  @rad2deg 57.295779513


  def start_link() do
    Logger.debug("Start Simulation.Xplane")
    config = %{}
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        socket: nil,
        port: 49002,#config.port,
        attitude: %{},
        bodyrate: %{},
        position: %{},
        velocity: %{}
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    {:ok, socket} = :gen_udp.open(state.port, [broadcast: false, active: true])
    {:noreply, %{state | socket: socket}}
  end

  @impl GenServer
  def handle_info({:udp, socket, src_ip, src_port, msg}, state) do
    Logger.info("received data from #{inspect(src_ip)} on port #{src_port} with length #{length(msg)}")
    Enum.each(Enum.with_index(msg), fn {x, index} ->
      Logger.info("#{index}:#{x}")
    end)
    state = parse_data_buffer(msg, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_attitude, _from, state) do
    {:reply, state.attitude, state}
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
    Logger.info("message type: #{inspect(message_type)}")
    buffer = Enum.drop(buffer,4)
    {state, buffer} =
    if (length(buffer) >= 32) do
      Logger.debug("parse buffer: #{inspect(buffer)}")
      state =
        case message_type do
          16 ->
            {pitch_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
            {roll_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
            {yaw_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
            roll_rate_rad = list_to_int(roll_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            pitch_rate_rad = list_to_int(pitch_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            yaw_rate_rad = list_to_int(yaw_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            Logger.debug("body: #{eftb(roll_rate_rad*@rad2deg,1)}/#{eftb(pitch_rate_rad*@rad2deg,1)}/#{eftb(yaw_rate_rad*@rad2deg,1)}")
            state
          17 ->
            {pitch_deg_uint32, buffer} = Enum.split(buffer, 4)
            {roll_deg_uint32, buffer} = Enum.split(buffer, 4)
            {yaw_deg_uint32, buffer} = Enum.split(buffer, 4)
            yaw_deg = list_to_int(yaw_deg_uint32, 4) |> Common.Utils.Math.fp_from_uint(32)
            pitch_deg = list_to_int(pitch_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            roll_deg = list_to_int(roll_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            Logger.debug("rpy: #{eftb(roll_deg,1)}/#{eftb(pitch_deg, 1)}/#{eftb(yaw_deg, 1)}")
            state
          20 ->
            {latitude_deg_uint32, buffer} = Enum.split(buffer, 4)
            {longitude_deg_uint32, buffer} = Enum.split(buffer, 4)
            {altitude_m_uint32, buffer} = Enum.split(buffer, 4)
            latitude_deg = list_to_int(latitude_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            longitude_deg = list_to_int(longitude_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            altitude_m = list_to_int(altitude_m_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            Logger.debug("lat/lon/alt: #{eftb(latitude_deg,7)}/#{eftb(longitude_deg, 7)}/#{eftb(altitude_m, 1)}")
            state
          21 ->
            buffer = Enum.drop(buffer, 12)
            {vel_east_mps_uint32, buffer} = Enum.split(buffer, 4)
            {vel_up_mps_uint32, buffer} = Enum.split(buffer, 4)
            {vel_south_mps_uint32, buffer} = Enum.split(buffer, 4)
            vel_north_mps = -(list_to_int(vel_south_mps_uint32,4) |> Common.Utils.Math.fp_from_uint(32))
            vel_east_mps = list_to_int(vel_east_mps_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
            vel_down_mps = -(list_to_int(vel_up_mps_uint32,4) |> Common.Utils.Math.fp_from_uint(32))
            Logger.debug("vNED: #{eftb(vel_north_mps,1)}/#{eftb(vel_east_mps, 1)}/#{eftb(vel_down_mps, 1)}")
            state
          other ->
            Logger.debug("unknown type")
            state
        end
      {state, Enum.drop(buffer,32)}
    else
      {state, []}
    end

    # If there is more data in the buffer, parse it
    unless Enum.empty?(buffer) do
      parse_message(state, buffer)
    else
      state
    end
  end

  @spec get_output() :: list()
  def get_output() do
    GenServer.call(__MODULE__, :get_output)
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
