defmodule Sc.Path do
  def lm() do
    Navigation.PathPlanner.Plans.load_lawnmower()
  end
end
