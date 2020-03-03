defmodule Adsadc.Utils do

  def get_bus_ref(bus) do
    {:ok, ref} = Circuits.I2C.open(bus)
    ref
  end

  def write_packet(ref, address, byte_list) do
    Circuits.I2C.write(ref, address, :binary.list_to_bin(byte_list))
  end

  def write_read(ref, address, register, num_bytes) do
    case Circuits.I2C.write_read(ref, address, <<register>>, num_bytes) do
      {:ok, data} ->
        :binary.bin_to_list(data)
      error ->
        IO.puts("Write/read error! #{inspect(error)}")
        []
    end
  end
end
