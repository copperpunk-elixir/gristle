defmodule Display.Scenic.Planner do
  use Scenic.Scene
  require Logger

  import Scenic.Primitives
  # @body_offset 80
  @font_size 24
  @degrees "°"
  @radians "rads"
  @dps "°/s"
  @radpersec "rps"
  @meters "m"
  @mps "m/s"
  @pct "%"

  # @offset_x 0
  # @width 300
  # @height 50
  # @labels {"", "", ""}
  @rect_border 6

  @moduledoc """
  This version of `Sensor` illustrates using spec functions to
  construct the display graph. Compare this with `Sensor` which uses
  anonymous functions.
  """

  # ============================================================================
  def init(_, opts) do
    Logger.debug("Sensor.init: #{inspect(opts)}")
    {:ok, %Scenic.ViewPort.Status{size: {_vp_width, _}}} =
      opts[:viewport]
      |> Scenic.ViewPort.info()

