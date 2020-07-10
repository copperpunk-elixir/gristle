defmodule Peripherals.Uart.CpIns do
  use GenServer
  require Logger

  @default_baud 115200

  def start_link(config) do
    Logger.debug("Start CpIns GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, uart_ref} = Circuits.UART.start_link()
    {:ok, %{
        uart_ref: uart_ref,
        ublox_device_description: config.ublox_device_description,
        baud: Map.get(config, :baud, @default_baud),
        antenna_offset: config.antenna_offset,
        imu_loop_interval_ms: config.imu_loop_interval_ms,
        ins_loop_interval_ms: config.ins_loop_interval_ms,
        heading_loop_interval_ms: config.heading_loop_interval_ms,
        attitude: %{},
        bodyrate: %{},
        bodyaccel: %{},
        gps_time: 0,
        position: %{},
        velocity: %{}
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Logger.debug("CP INS begin with process: #{inspect(self())}")
    ins_port = Common.Utils.get_uart_devices_containing_string(state.ublox_device_description)
    case Circuits.UART.open(state.uart_ref, ins_port,[speed: state.baud, active: true]) do
      {:error, error} ->
        Logger.error("Error opening UART: #{inspect(error)}")
        raise "#{ins_port} is unavailable"
      _success ->
        Logger.debug("CP INS opened #{ins_port}")
    end
    Comms.Operator.join_group(__MODULE__, :pv_measured, self())

    Common.Utils.start_loop(self(), state.imu_loop_interval_ms, :imu_loop)
    Common.Utils.start_loop(self(), state.ins_loop_interval_ms, :ins_loop)
    Common.Utils.start_loop(self(), state.heading_loop_interval_ms, :heading_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:pv_measured, values}, state) do
    state = %{state |
              attitude: values.attitude,
              bodyrate: values.bodyrate,
              bodyaccel: values.bodyaccel,
              velocity: values.velocity,
              position: values.position
             }
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _data}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:imu_loop, state) do
    accel = state.bodyaccel
    bodyrate = state.bodyrate
    unless (Enum.empty?(accel) or Enum.empty?(bodyrate)) do
      # Send accel/gyro message to IMU
      accel_gyro = get_accel_gyro(accel, bodyrate, DateTime.utc_now())
      Circuits.UART.write(state.uart_ref, accel_gyro)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:ins_loop, state) do
    position = state.position
    velocity = state.velocity
    unless Enum.empty?(position) or Enum.empty?(velocity) do
      nav_pvt = get_nav_pvt(position, velocity, DateTime.utc_now())
      Circuits.UART.write(state.uart_ref, nav_pvt)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:heading_loop, state) do
    attitude = state.attitude
    unless Enum.empty?(attitude) do
      rel_pos_ned = get_rel_pos_ned(attitude.yaw, state.antenna_offset)
      # Logger.info("send ")
      Circuits.UART.write(state.uart_ref, rel_pos_ned)
    end
    {:noreply, state}
  end


  # @spec send

  @spec eftb(float(), integer()) :: binary()
  def eftb(number, num_decimals) do
    Common.Utils.eftb(number, num_decimals)
  end

  @spec calculate_checksum(list()) :: binary()
  def calculate_checksum(data_buffer) do
    checksum = Enum.reduce(:binary.bin_to_list(data_buffer), 0, fn (x, acc) ->
      Bitwise.^^^(acc, x)
    end)
    |> Bitwise.&&&(255)
    cs_str = Integer.to_string(checksum, 16)
    if String.length(cs_str) < 2, do: "0"<>cs_str, else: cs_str
  end

  @spec get_accel_gyro(map(), map(), struct()) :: binary()
  def get_accel_gyro(accel, bodyrate, now) do
    {now_us, _} = now.microsecond
    header = <<0xB5,0x62>>
    class_id_length = <<0x01, 0x69,32,0>>
    iTOW = get_itow()
    nano = now_us*1000 |> Common.Utils.Math.int32_little_bin()
    accel_x = Common.Utils.Math.uint_from_fp(accel.x,4)
    accel_y = Common.Utils.Math.uint_from_fp(accel.y,4)
    accel_z = Common.Utils.Math.uint_from_fp(accel.z,4)
    gyro_x = Common.Utils.Math.uint_from_fp(bodyrate.rollrate,4)
    gyro_y = Common.Utils.Math.uint_from_fp(bodyrate.pitchrate,4)
    gyro_z = Common.Utils.Math.uint_from_fp(bodyrate.yawrate,4)
    checksum_buffer =
      class_id_length <>
      iTOW <>
      nano <>
      accel_x <>
      accel_y <>
      accel_z <>
      gyro_x <>
      gyro_y <>
      gyro_z
    checksum_bytes = calculate_ublox_checksum(:binary.bin_to_list(checksum_buffer))
    header <> checksum_buffer <> checksum_bytes
  end

  @spec get_nav_pvt(map(), map(), struct()) :: binary()
  def get_nav_pvt(position, velocity, now) do
    {now_us, _} = now.microsecond

    header = <<0xB5,0x62>>
    class_id_length = <<0x01, 0x07,92,0>>
    iTOW = get_itow()
    year = now.year |> Common.Utils.Math.int16_little_bin()
    month = <<now.month>>
    day = <<now.month>>
    hour = <<now.hour>>
    min = <<now.minute>>
    sec = <<now.second>>
    valid = <<15>>
    tAcc = Common.Utils.Math.int32_little_bin(100)
    nano = now_us*1000 |> Common.Utils.Math.int32_little_bin()
    fixType = <<3>>
    flags = <<55>>
    flags2 = <<224>>
    numSV = <<:random.uniform(12)+7>>
    lon = position.longitude |> Common.Utils.Math.rad2deg() |> Kernel.*(10_000_000) |> round() |> Common.Utils.Math.int32_little_bin()
    lat = position.latitude |> Common.Utils.Math.rad2deg() |> Kernel.*(10_000_000) |> round() |> Common.Utils.Math.int32_little_bin()
    height = position.altitude * 1_000 |> round() |> Common.Utils.Math.int32_little_bin()
    hMSL = height
    hACC = Common.Utils.Math.int32_little_bin(:random.uniform(2000))
    vACC = Common.Utils.Math.int32_little_bin(:random.uniform(2000))
    velN = velocity.north * 1_000 |> round() |> Common.Utils.Math.int32_little_bin()
    velE = velocity.east * 1_000 |> round() |> Common.Utils.Math.int32_little_bin()
    velD = velocity.down * 1_000 |> round() |> Common.Utils.Math.int32_little_bin()
    remainder = <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>
    checksum_buffer =
      class_id_length <>
      iTOW <>
      year <>
      month <>
      day <>
      hour <>
      min <>
      sec <>
      valid <>
      tAcc <>
      nano <>
      fixType <>
      flags <>
      flags2 <>
      numSV <>
      lon <>
      lat <>
      height <>
      hMSL <>
      hACC <>
      vACC <>
      velN <>
      velE <>
      velD <>
      remainder
    checksum_bytes = calculate_ublox_checksum(:binary.bin_to_list(checksum_buffer))
    header <> checksum_buffer <> checksum_bytes
  end

  @spec get_rel_pos_ned(float(), float()) :: binary()
  def get_rel_pos_ned(yaw, ant_offset) do
    header = <<0xB5,0x62>>
    class_id_length = <<0x01, 0x3C,40,0>>
    version = <<0>>
    res1 = <<0>>
    refStationId = <<0,0>>
    iTOW = get_itow()
    distance = 1
    relPosN_float = distance*:math.cos(yaw + ant_offset)
    relPosN_cm = relPosN_float * 100 |> trunc()
    relPosN_mm = (relPosN_float - relPosN_cm*0.01) * 10000 |> round()
    relPosE_float = distance*:math.sin(yaw + ant_offset)
    relPosE_cm = relPosE_float * 100 |> trunc()
    relPosE_mm = (relPosE_float - relPosE_cm*0.01) * 10000 |> round()
    relPosN = relPosN_cm |> Common.Utils.Math.int32_little_bin()
    relPosE = relPosE_cm |> Common.Utils.Math.int32_little_bin()
    relPosD = <<0,0,0,0>>
    relPosHPN = relPosN_mm |> Common.Utils.Math.int8_little_bin()
    relPosHPE = relPosE_mm |> Common.Utils.Math.int8_little_bin()
    relPosHPD = <<0>>
    res2 = <<0>>
    accN = Common.Utils.Math.int32_little_bin(:random.uniform(100))
    accE = Common.Utils.Math.int32_little_bin(:random.uniform(100))
    accD = Common.Utils.Math.int32_little_bin(:random.uniform(100))
    flags= Common.Utils.Math.int32_little_bin(:random.uniform(4))
    checksum_buffer =
      class_id_length <>
      version <>
      res1 <>
      refStationId <>
      iTOW <>
      relPosN <>
      relPosE <>
      relPosD <>
      relPosHPN <>
      relPosHPE <>
      relPosHPD <>
      res2 <>
      accN <>
      accE <>
      accD <>
      flags
    checksum_bytes = calculate_ublox_checksum(:binary.bin_to_list(checksum_buffer))
    header <> checksum_buffer <> checksum_bytes
  end

  @spec get_itow() :: integer()
  def get_itow() do
    today = Date.utc_today()
    first_day_str = Date.add(today, - Date.day_of_week(today)) |> Date.to_iso8601()
    |> Kernel.<>("T00:00:00Z")
    {:ok, first_day, 0} = DateTime.from_iso8601(first_day_str)

    DateTime.diff(DateTime.utc_now, first_day, :millisecond)
    |> Common.Utils.Math.int32_little_bin()
  end

  @spec calculate_ublox_checksum(list()) :: binary()
  def calculate_ublox_checksum(buffer) do
    {ck_a, ck_b} =
      Enum.reduce(buffer,{0,0}, fn (x,{ck_a, ck_b}) ->
        ck_a = ck_a + x
        ck_b = ck_b + ck_a
        {Bitwise.&&&(ck_a,0xFF), Bitwise.&&&(ck_b,0xFF)}
      end)
    <<ck_a,ck_b>>
  end
end
