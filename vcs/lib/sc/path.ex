defmodule Sc.Path do
  def lm() do
    Navigation.PathPlanner.Plans.load_lawnmower()
  end

  def fs() do
    Navigation.PathPlanner.Plans.load_flight_school()
  end

  def st() do
    Navigation.PathPlanner.Plans.load_seatac_34L()
  end

  def orbr() do
    Navigation.PathPlanner.Plans.load_orbit_right()
  end

  def orbl() do
    Navigation.PathPlanner.Plans.load_orbit_left()
  end

end
