defmodule Peripherals.I2c.Utils do
  @brightness 50
  defmacro self_led_address, do: 0x08
  defmacro control_led_address, do: 0x09
  defmacro mux_led_address, do: 0x10

  def get_color_for_node_number(node) do
    case node do
      1 -> {@brightness,0,0} # RED
      2 -> {0, @brightness, 0} # GREEN
      3 -> {0, 0, @brightness} # BLUE
      4 -> {0, @brightness, @brightness} # YELLOW?
      _other -> {0,0,0} #OFF
    end
  end

end
