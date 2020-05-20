defmodule Common.Utils.Math do
  require Bitwise
  require Logger

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

  def integer_power(x, pow) do
    Enum.reduce(1..pow, 1, fn (_iter, acc) ->
      x*acc
    end)
  end

  def fp_from_uint(x, bits) do
    # Logger.debug("x: #{x}")
    {sig_start,exp_min_index, exp_subtract,significand_div, exp_and} =
      case bits do
        32 -> {0x7FFFFF,23,127, 8388608, 0x100}
        64 -> {0xFFFFFFFFFFFFF,52,1023, 0x10000000000000, 0x800}
      end
    # significand = Bitwise.<<<(1,exp_min_index) -1
    significand =Bitwise.&&&(sig_start,x)
    exponent = Bitwise.>>>(x,exp_min_index)
    # Logger.debug("exp: #{exponent}")
    # exponent = exponent - Bitwise.&&&(exponent,Bitwise.<<<(1,exp_max_index-exp_min_index+1)) - exp_subtract
    exponent = exponent - Bitwise.&&&(exponent,exp_and)
    # Logger.debug("exp: #{exponent}")
    exponent = exponent - exp_subtract

    # Logger.debug("exp: #{exponent}")
    # exponent = exponent - exp_subtract
    # Logger.debug("exp: #{exponent}")
    sign = if Bitwise.>>>(x,bits-1) == 1 do
      -1
    else
      1
    end
    # Logger.debug("sign: #{sign}")
    # Logger.debug("exponent: #{exponent}")
    # Logger.debug("significand: #{significand}")
    exp_mult =
    if exponent > 0 do
      Bitwise.<<<(1,exponent)
    else
      1/Bitwise.<<<(1,-exponent)
    end
    # Logger.debug("exp mult: #{exp_mult}")
    value = sign*(1+significand/significand_div)*exp_mult

    # Logger.debug("value: #{value}")
    value

  end

  def twos_comp_16(x) do
    <<si::signed-integer-16>> = <<x::unsigned-integer-16>>
  si
  end

  def twos_comp_16_bin(x) do
    <<si::signed-integer-16>> = x
    si
  end

  def twos_comp_32(x) do
    <<si::signed-integer-32>> = <<x::unsigned-integer-32>>
  si
  end

  def twos_comp_32_bin(x) do
    <<si::signed-integer-32>> = x
    si
  end

  def twos_comp_64(x) do
    <<si::signed-integer-64>> = <<x::unsigned-integer-64>>
  si
  end

  def twos_comp_64_bin(x) do
    <<si::signed-integer-64>> = x
    si
  end

end
