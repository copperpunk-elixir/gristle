defmodule Sensors.I2c.Utils do
  alias Circuits.I2C

  def get_bus_ref(bus) do
    {:ok, ref} = I2C.open(bus)
    ref
  end

  def write_byte(ref, address, data) do
    I2C.write(ref, address, <<data>>)
  end

  def write_packet(ref, address, byte_list) do
    I2C.write(ref, address, :binary.list_to_bin(byte_list))
  end

  def write_byte_to_register(ref, address, register, data) do
    I2C.write(ref, address, <<register,data>>)
  end

  def write_read(ref, address, register, num_bytes) do
    case I2C.write_read(ref, address, <<register>>, num_bytes) do
      {:ok, data} ->
        :binary.bin_to_list(data)
      error ->
        IO.puts("Write/read error! #{inspect(error)}")
        []
    end
  end

  def set_register(ref, address, register) do
    case I2C.write(ref, address, <<register>>) do
      :ok ->
        IO.puts("set register success")
        :ok
       error ->
        IO.puts("Set register error! #{inspect(error)}")
        :error
    end
  end

  def read_packet(ref, address, num_bytes) do
    case I2C.read(ref, address, num_bytes) do
      {:ok, data} ->
        # IO.puts("packet read: #{inspect(data <> <<0>>)}")
        :binary.bin_to_list(data)
      error ->
        IO.puts("Read packet error!: #{inspect(error)}")
        []
    end
  end
end
