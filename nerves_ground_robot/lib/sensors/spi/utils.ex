defmodule Sensors.Spi.Utils do
  alias Circuits.SPI

  def get_bus_ref(bus, opts \\ []) do
    {:ok, ref} = SPI.open(bus,opts)
    ref
  end

  def write_packet(ref, byte_list) do
    SPI.transfer(ref, :binary.list_to_bin(byte_list))
  end

  def write_read(ref, byte_list) do
    case SPI.transfer(ref, :binary.list_to_bin(byte_list)) do
      {:ok, data} ->
        :binary.bin_to_list(data)
      error ->
        IO.puts("Transfer error! #{inspect(error)}")
        []
    end
  end

  def write_read_byte(ref, byte) do
    case SPI.transfer(ref, <<byte>>) do
      {:ok, <<data>>} ->
        data
      error ->
        IO.puts("Transfer error! #{inspect(error)}")
        []
    end
  end
end
