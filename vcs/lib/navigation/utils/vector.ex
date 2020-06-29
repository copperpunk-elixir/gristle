defmodule Navigation.Utils.Vector do
  require Logger
  @enforce_keys [:x, :y, :z]
  defstruct [:x, :y, :z]

  @spec new(float(), float(), float()) :: struct()
  def new(x, y, z) do
    %Navigation.Utils.Vector{
      x: x,
      y: y,
      z: z
    }
  end

  @spec new(float(), float()) :: struct()
  def new(x, y) do
    new(x, y, 0)
  end

  @spec reverse(struct()) :: struct()
  def reverse(vector) do
    %Navigation.Utils.Vector{
      x: -vector.x,
      y: -vector.y,
      z: -vector.z
    }
  end

  @spec to_string(struct()) :: binary()
  def to_string(vector, num_digits \\ 3) do
    "#{Common.Utils.eftb(vector.x, num_digits)}/#{Common.Utils.eftb(vector.y, num_digits)}/#{Common.Utils.eftb(vector.z, num_digits)}"
  end
end
