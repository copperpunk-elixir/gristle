defmodule Navigation.Path.Vector do
  require Logger
  @enforce_keys [:x, :y, :z]
  defstruct [:x, :y, :z]

  @spec new(float(), float(), float()) :: struct()
  def new(x, y, z) do
    %Navigation.Path.Vector{
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
    %Navigation.Path.Vector{
      x: -vector.x,
      y: -vector.y,
      z: -vector.z
    }
  end
end
