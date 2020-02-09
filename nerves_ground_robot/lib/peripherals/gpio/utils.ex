defmodule Peripherals.Gpio.Utils do
  alias Circuits.GPIO

  def get_gpio_ref_input(pin) do
    {:ok, ref} = GPIO.open(pin, :input)
    ref
  end

  def get_gpio_ref_output(pin) do
    {:ok, ref} = GPIO.open(pin, :output)
    ref
  end

  def get_gpio_ref_input_pullup(pin) do
    {:ok, ref} = GPIO.open(pin, :input,[pull_mode: :pullup])
    ref
  end

  def get_gpio_ref_input_pulldown(pin) do
    {:ok, ref} = GPIO.open(pin, :input,[pull_mode: :pulldown])
    ref
  end

end
