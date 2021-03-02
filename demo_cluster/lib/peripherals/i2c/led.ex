defmodule Peripherals.I2c.Led do
  defstruct interface_ref: nil, address: nil
  require Logger

  @spec new(any(), integer()) :: struct()
  def new(ref, address) do
    %Peripherals.I2c.Led{
      interface_ref: ref,
      address: address
    }
  end

  @spec set_color(struct(), tuple()) :: atom()
  def set_color(led, {red, green, blue}) do
    set_color(led, red, green, blue)
  end


  @spec set_color(struct(), integer(), integer(), integer()) :: atom()
  def set_color(led, red, green , blue) do
    Logger.debug("Set color at address #{led.address} to #{red}/#{green}/#{blue}")
    if Common.Utils.is_target?() do
      Circuits.I2C.write(led.interface_ref, led.address, <<0, red, green, blue>> )
    end
  end

end
