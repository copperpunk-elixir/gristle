defmodule Comms.OperatorTest do
  use ExUnit.Case
  doctest Comms.Operator

  test "Operator tests" do
    node_name = :master
    groups = [:test_cmds_a, :test_cmds_b]
    # interface = :wlan0 # use with RPi
    interface = :wlp0s20f3 # use with System76
    cookie = :monster
    config = %{node_name: node_name, groups: groups, interface: interface, cookie: cookie}
  end

end
