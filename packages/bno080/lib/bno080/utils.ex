defmodule Bno080.Utils do
  require Logger

  # GPIO
  def get_gpio_ref_output(pin) do
    case Circuits.GPIO.open(pin, :output) do
      {:error, error} ->
        Logger.warn("GPIO open error: #{inspect(error)}")
        nil
      {:ok, ref} -> ref
    end
  end

  def gpio_write(pin_ref, output) do
    # TODO: Put some error handling here
    Circuits.GPIO.write(pin_ref, output)
  end
  # UART
  def get_uart_ref do
    {:ok, ref} = Circuits.UART.start_link
    ref
  end

  def open_active(pid, port, speed) do
    Circuits.UART.open(pid, port, [speed: speed, active: true])
  end

  def write(pid, data, timeout) do
    Circuits.UART.write(pid, data, timeout)
  end

  # MATH
  def quat_in_bounds?(quat, error_bounds \\ 0.02) do
    quat_mag =
    if is_map(quat) do
      Enum.reduce(quat,0, fn({_key, x}, acc) ->
        acc + :math.pow(x,2)
      end)
    else
      Enum.reduce(0..3,0,fn (index, acc) ->
        acc + :math.pow(elem(quat,index), 2)
      end)
    end
    quat_mag = :math.sqrt(quat_mag)
    (abs(quat_mag - 1.0) <= error_bounds)
  end

  def quat2euler(quat) do
    # Convert from Android Coordinate Frame to NED
    {qx, qy, qz, qw} = {quat.y, quat.x, -quat.z, quat.w}
    #roll
    sinr_cosp = 2 * (qw * qx + qy * qz)
    cosr_cosp = 1 - 2 * (qx * qx + qy * qy)
    roll = :math.atan2(sinr_cosp, cosr_cosp)

    # pitch
    sinp = 2 * (qw * qy - qz * qx)
    pitch = cond do
      sinp >= 1 ->
        :math.pi()*0.5
      sinp <= -1 ->
        -:math.pi()*0.5
      true ->
        :math.asin(sinp)
    end
    # yaw
    siny_cosp = 2 * (qw * qz + qx * qy)
    cosy_cosp = 1 - 2 * (qy * qy + qz * qz)
    yaw = :math.atan2(siny_cosp, cosy_cosp)
    %{roll: roll, pitch: pitch, yaw: yaw}
  end


end
