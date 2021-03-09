defmodule Peripherals.I2c.Utils do
  @brightness 50
  defmacro self_led_address, do: 0x0A
  defmacro servo_output_led_address, do: 0x09
  defmacro mux_led_address, do: 0x08

  def get_color_for_node_number(node) do
    case node do
      1 -> {@brightness,0,0} # RED
      2 -> {0, @brightness, 0} # GREEN
      3 -> {0, 0, @brightness} # BLUE
      4 -> {@brightness, @brightness, 0} # YELLOW?
      _other -> {0,0,0} #OFF
    end
  end

end
