defmodule Peripherals.Gpio.Utils do
  alias Circuits.GPIO
  require Logger

  def get_gpio_ref_input(pin) do
    case GPIO.open(pin, :input) do
      {:error, error} ->
        Logger.warn("GPIO open error: #{inspect(error)}")
        nil
      {:ok, ref} -> ref
    end
  end

  def get_gpio_ref_output(pin) do
    case GPIO.open(pin, :output) do
      {:error, error} ->
        Logger.warn("GPIO open error: #{inspect(error)}")
        nil
      {:ok, ref} -> ref
    end
  end

  def get_gpio_ref_input_pullup(pin) do
    case GPIO.open(pin, :input,[pull_mode: :pullup]) do
      {:error, error} ->
        Logger.warn("GPIO open error: #{inspect(error)}")
        nil
      {:ok, ref} -> ref
    end
  end

  def get_gpio_ref_input_pulldown(pin) do
    case GPIO.open(pin, :input,[pull_mode: :pulldown]) do
      {:error, error} ->
        Logger.warn("GPIO open error: #{inspect(error)}")
        nil
      {:ok, ref} -> ref
    end
  end
end
