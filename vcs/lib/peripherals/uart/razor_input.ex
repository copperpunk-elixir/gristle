defmodule Peripherals.Uart.RazorInput do
  use GenServer
  require Logger

  @default_baud 115200

  def start_link(config) do
    Logger.debug("Start RazorInput GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, uart_ref} = Circuits.UART.start_link()
    {:ok, %{
        uart_ref: uart_ref,
        device_description: Map.get(config, :device_description, @default_device_description),
        baud: Map.get(config, :baud, @default_baud),
        imu_loop_interval_ms: config.imu_loop_interval_ms,
        ins_loop_interval_ms: config.ins_loop_interval_ms,
        heading_loop_interval_ms: config.heading_loop_interval_ms,
        attitude: %{roll: 0,pitch: 0,yaw: 0},
        bodyrate: %{rollrate: 0, pitchrate: 0, yawrate: 0},
        body_accel: %{x: 0, y: 0, z: 0},
        gps_time: 0,
        position: %{latitude: 0, longitude: 0, altitude: 0},
        velocity: %{north: 0, east: 0, down: 0}
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Logger.debug("VN INS begin with process: #{inspect(self())}")
    ins_port = Common.Utils.get_uart_devices_containing_string(state.device_description)
    case Circuits.UART.open(state.uart_ref, ins_port,[speed: state.baud, active: true]) do
      {:error, error} ->
        Logger.error("Error opening UART: #{inspect(error)}")
        raise "#{ins_port} is unavailable"
      _success ->
        Logger.debug("VN INS opened #{ins_port}")
    end
    Comms.Operator.join_group(__MODULE__, :pv_measured, self())

    Common.Utils.start_loop(self(), state.imu_loop_interval_ms, :imu_loop)
    Common.Utils.start_loop(self(), state.ins_loop_interval_ms, :ins_loop)
    Common.Utils.start_loop(self(), state.heading_loop_interval_ms, :heading_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:pv_measured, values}, state) do
    Logger.info("razor pv_meas: #{inspect(values)}")
    state = %{state |
              attitude: values.attitude,
              bodyrate: values.bodyrate,
              body_accel: values.accel,
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
    accel = state.body_accel
    bodyrate = state.bodyrate
    unless (Enum.empty?(accel) or Enum.empty?(bodyrate)) do
      # Send accel/gyro message to IMU
      accel_str = "#{eftb(accel.x,4)},#{eftb(accel.y,4)},#{eftb(accel.z,4)},"
      gyro_deg = Common.Utils.map_rad2deg(bodyrate)
      gyro_str = "#{eftb(gyro_deg.rollrate,2)},#{eftb(gyro_deg.pitchrate,2)},#{eftb(gyro_deg.yawrate,2)}"
      data_buffer = "IMU," <> accel_str <> gyro_str
      checksum = calculate_checksum(data_buffer)
      message = "$" <> data_buffer <> "*" <> checksum <> "\r\n"
      Logger.warn("outgoing msg: #{message}")
      Circuits.UART.write(state.uart_ref, message)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:ins_loop, state) do
    position = state.position
    velocity = state.velocity
    unless Enum.empty?(position) or Enum.empty?(velocity) do
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:heading_loop, state) do
    attitude = state.attitude
    unless Enum.empty?(attitude) do
      # Send heading
      heading = attitude.yaw
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

  @spec publish_pubx00(map(), map(), struct()) :: atom()
  def publish_pubx00(position, velocity, utc_now) do
    data_buffer = "PUBX,00"
  end

end
