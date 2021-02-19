defmodule Sweep.Servo do
  @enforce_keys [:min_value, :max_value, :direction, :value]
  defstruct [:min_value, :max_value, :direction, :value]

  @spec new(integer(), integer(), integer(), integer()) :: struct()
  def new(min_value, max_value, direction, value) do
    %Sweep.Servo{
      min_value: min_value,
      max_value: max_value,
      direction: direction,
      value: value
    }
  end
end
