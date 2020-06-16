defmodule Common.Utils.Math do
  require Bitwise
  require Logger

  @spec constrain(number(), number(), number()) :: number()
  def constrain(x, min_value, max_value) do
    case x do
      _ when x > max_value -> max_value
      _ when x < min_value -> min_value
      x -> x
    end
  end

@spec in_range?(number(), number(), number()) :: boolean()
  def in_range?(x, min_value, max_value) do
    cond do
      x > max_value -> false
      x < min_value -> false
      true -> true
    end
  end

  @spec constrain?(number(), number(), number()) :: tuple()
  def constrain?(x, min_value, max_value) do
    case x do
      _ when x > max_value -> {max_value, true}
      _ when x < min_value -> {min_value, true}
      x -> {x, false}
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

  @log2 0.69314718056
  @spec uint_from_fp(float(), integer) :: integer()
  def uint_from_fp(x, bits) do
    # abs_x = abs(x)
    # int_x = floor(abs_x)
    # dec_x = abs_x-int_x
    # dec_x = Enum.reduce()
    # significand = :erlang.integer_to_list(int_x, 2)
    # exp = length(significand)-1 + 127
    # exponent = :erlang.integer_to_list(exp, 2)
    # Logger.debug("exponent: #{exponent}")
    if x == 0 do
      <<0,0,0,0>>
    else
      abs_x = abs(x)
      exponent = floor(:math.log(abs_x)/@log2)
      biased_exponent = exponent + 127
      exponent_bin = :erlang.integer_to_binary(biased_exponent,2)
      # add leading zeros if necessary
      num_zeros = 8 - String.length(exponent_bin)
      exponent_bin =
      if (num_zeros > 0) do
        Enum.reduce(1..num_zeros, exponent_bin, fn (_x,acc) ->
          "0" <> acc
        end)
      else
        exponent_bin
      end
      exp_mult = :math.pow(2,exponent)
      # Logger.info("exp/exp_mult: #{exponent}/#{exp_mult}")
      {mantissa, mantissa_string} =
        Enum.reduce(1..23, {1,""}, fn (ctr, {mantissa, mantissa_string}) ->
          mantissa_temp = mantissa + 1.0/Bitwise.<<<(1,ctr)
          # Logger.info("ctr/mtemp/mult: #{ctr}/#{mantissa_temp}/#{mantissa_temp*exp_mult}")
          if mantissa_temp*exp_mult <= abs_x do
            {mantissa_temp, mantissa_string <> "1"}
          else
            {mantissa, mantissa_string <> "0"}
          end
        end)
      number =
      if x >= 0 do
        "0"
      else
        "1"
      end
      number = number <> exponent_bin <> mantissa_string
      # Logger.debug("exponent: #{exponent_bin}")
      # Logger.debug("mantissa: #{mantissa}")
      # Logger.debug("mantissa str: #{mantissa_string}")
      # Logger.debug("number: #{number}")
      num_int = :erlang.binary_to_integer(number,2)
      # Logger.info("num_int: #{num_int}")
      <<num_int :: little-unsigned-32>>

    end
    # Logger.debug("[#{a},#{b},#{c},#{d}]")
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
