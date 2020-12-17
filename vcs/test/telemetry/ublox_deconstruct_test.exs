defmodule Telemetry.UbloxDeconstructTest do
  use ExUnit.Case
  require Logger
  alias Common.Utils.Math, as: Mt
  alias Common.Utils, as: Ut

  setup do
    RingLogger.attach
    {:ok, []}
  end

  test "deconstruct test" do
    x = -1.234
    y = 2147500033
    z = -2147467263
    x_bin = Mt.uint_from_fp(x,32)
    y_bin = Mt.int_little_bin(y, 32)
    z_bin = Mt.int_little_bin(z, 32)
    assert y_bin == z_bin

    x_flt = :binary.bin_to_list(x_bin) |> Ut.list_to_int(4) |> Mt.fp_from_uint(32)
    y_int = :binary.bin_to_list(y_bin) |> Ut.list_to_int(4)
    z_int = :binary.bin_to_list(z_bin) |> Ut.list_to_int(4) |> Mt.twos_comp(32)
    assert_in_delta(x, x_flt, 0.0001)
    assert y == y_int
    assert z == z_int
  end
end
