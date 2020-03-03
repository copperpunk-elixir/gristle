defmodule Vl53tof.Utils do
  def get_bus_ref(bus) do
    {:ok, ref} = Circuits.I2C.open(bus)
    ref
  end

  def write_packet(ref, address, byte_list) do
    Circuits.I2C.write(ref, address, :binary.list_to_bin(byte_list))
  end

  def read_packet(ref, address, num_bytes) do
    case Circuits.I2C.read(ref, address, num_bytes) do
      {:ok, data} ->
        # IO.puts("packet read: #{inspect(data <> <<0>>)}")
        :binary.bin_to_list(data)
      error ->
        IO.puts("Read packet error!: #{inspect(error)}")
        []
    end
  end
end
