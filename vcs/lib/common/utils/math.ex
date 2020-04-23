defmodule Common.Utils.Math do

  def constrain(x, min_value, max_value) do
    case x do
      _ when x > max_value -> max_value
      _ when x < min_value -> min_value
      x -> x
    end
  end

  def hypot(x, y) do
    :math.sqrt(x*x + y*y)
  end

  def rad2deg(x) do
    x*180/:math.pi()
  end

  def deg2rad(x) do
    x*:math.pi()/180
  end
end
