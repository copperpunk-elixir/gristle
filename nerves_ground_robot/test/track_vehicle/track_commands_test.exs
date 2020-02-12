defmodule TrackVehicle.TrackCommandsTest do
  require Logger
  use ExUnit.Case
  doctest TrackVehicle.Controller

@assert_tol 1.0e-04

  test "TrackVehicle Commands calculator" do
    speed = 1.0
    turn = 0
    assert calculate_track_cmd_for_speed_and_turn(1.0, 0) == {1.0, 1.0}
    assert calculate_track_cmd_for_speed_and_turn(-1.0, 0) == {-1.0, -1.0}
    {left, right} = calculate_track_cmd_for_speed_and_turn(1.0, 1.0)
    assert_in_delta(left, 1.0, @assert_tol)
    assert_in_delta(right, 0.0, @assert_tol)
    {left, right} = calculate_track_cmd_for_speed_and_turn(1.0, -1.0)
    assert_in_delta(left, 0.0, @assert_tol)
    assert_in_delta(right, 1.0, @assert_tol)
    {left, right} = calculate_track_cmd_for_speed_and_turn(-1.0, 1.0)
    assert_in_delta(left, -1.0, @assert_tol)
    assert_in_delta(right, 0.0, @assert_tol)
    {left, right} = calculate_track_cmd_for_speed_and_turn(-1.0, -1.0)
    assert_in_delta(left, 0.0, @assert_tol)
    assert_in_delta(right, -1.0, @assert_tol)
    {left, right} = calculate_track_cmd_for_speed_and_turn(0.5, 1.0)
    assert_in_delta(left, 0.5, @assert_tol)
    assert_in_delta(right, 0.0, @assert_tol)
    # "50%" turn right
    {left, right} = calculate_track_cmd_for_speed_and_turn(1.0, 0.5)
    assert_in_delta(left, 1.0, @assert_tol)
    assert_in_delta(right, :math.sqrt(1-0.25), @assert_tol)
    # try "50%" left
    {left, right} = calculate_track_cmd_for_speed_and_turn(1.0, -0.5)
    assert_in_delta(right, 1.0, @assert_tol)
    assert_in_delta(left, :math.sqrt(1-0.25), @assert_tol)

    Process.sleep(200)
  end

  def calculate_track_cmd_for_speed_and_turn(speed, turn) do
    x = turn
    # x = 1-abs(y)
    # multiplier = 1/(x*x + y*y)
    # y = multiplier*y
    # x = multiplier*x
    y = :math.sqrt(1-x*x)

    # alpha = :math.atan2(y,x)
    Logger.debug("speed/turn: #{speed}/#{turn}")
    Logger.debug("x/y: #{x}/#{y}")
    cond do
      x < 0 ->
        Logger.debug("left turn")
        {speed*y, speed}
      true ->
        Logger.debug("right turn")
        {speed, speed*y}
    end
  end

end
