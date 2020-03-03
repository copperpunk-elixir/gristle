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

  def quat2euler(quat, is_android \\ true) do
    if is_map(quat) do
      quat2euler_map(quat, is_android)
    else
      quat2euler_tuple(quat, is_android)
    end
  end


end
