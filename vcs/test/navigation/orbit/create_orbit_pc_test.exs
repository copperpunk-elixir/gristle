defmodule Navigation.Orbit.CreateOrbitPcTest do
  use ExUnit.Case
  require Logger

  setup do
    model_type = "CessnaZ2m"
    # Boss.System.common_start()
    RingLogger.attach
    {:ok, [model_type: model_type]}
  end

  test "Create Orbit Path Case Test", context do
    model_type = context[:model_type]
    cruise_speed = Navigation.Path.Mission.get_model_spec(model_type, :cruise_speed)
    min_loiter_speed = Navigation.Path.Mission.get_model_spec(model_type, :min_loiter_speed)
    planning_turn_rate = Navigation.Path.Mission.get_model_spec(model_type, :planning_turn_rate)
    # path_case = Navigation.Path.Mission.new_orbit(:right, 100, model_type)
    orbit_radius = 100
    {turn_rate, speed, radius} = Navigation.Path.Mission.calculate_orbit_parameters(model_type, orbit_radius)
    assert radius == orbit_radius
    assert speed == cruise_speed
    orbit_radius = 10
    {turn_rate, speed, radius} = Navigation.Path.Mission.calculate_orbit_parameters(model_type, orbit_radius)
    assert turn_rate == planning_turn_rate
    assert speed == min_loiter_speed
    assert radius == min_loiter_speed/planning_turn_rate
    orbit_radius = 1000
    {turn_rate, speed, radius} = Navigation.Path.Mission.calculate_orbit_parameters(model_type, orbit_radius)
    assert turn_rate == speed/radius
    assert speed == cruise_speed
    assert radius == radius
  end
end
