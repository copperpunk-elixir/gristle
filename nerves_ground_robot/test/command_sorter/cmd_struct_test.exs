defmodule CommandSorter.CmdStructTest do
  use ExUnit.Case
  doctest CommandSorter.CmdStruct

  test "CommandSorter CmdStruct" do
    priority = 1
    authority = 3
    expiration_mono_ms = 3000
    value = -1.23
    cmdstruct = CommandSorter.CmdStruct.create_cmd(priority, authority, expiration_mono_ms, value)
    assert cmdstruct.priority == priority
    assert cmdstruct.authority == authority
    assert cmdstruct.expiration_mono_ms == expiration_mono_ms
    assert cmdstruct.value == value
  end
end
