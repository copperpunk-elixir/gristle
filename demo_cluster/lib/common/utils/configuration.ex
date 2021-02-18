defmodule Common.Utils.Configuration do
  require Logger

  @spec get_node_type() :: binary()
  def get_node_type() do
    if Common.Utils.is_target?() do
      pins = Enum.with_index([5, 6, 12])
      read_sum = Enum.reduce(pins, 0, fn ({pin, index}, acc) ->
        {:ok, gpio_ref} = Circuits.GPIO.open(pin, :input, [pull_mode: :pullup])
        acc + Bitwise.<<<(1 - Circuits.GPIO.read(gpio_ref), index)
      end)
      case read_sum do
        0 -> "all"
        other -> "remote_#{other}"
      end
    else
      "sim"
    end
  end

  @spec split_safely(binary(), binary()) :: list()
  def split_safely(value, delimitter)do
    # Logger.warn("split: #{value} with #{delimitter}")
    case String.split(value, delimitter) do
      [node_type, meta] -> [node_type, meta]
      [node_type] -> [node_type, nil]
    end
  end
end
