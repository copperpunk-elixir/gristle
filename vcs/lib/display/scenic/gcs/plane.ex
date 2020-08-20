defmodule Display.Scenic.Gcs.Plane do
  use Scenic.Scene
  require Logger

  import Scenic.Primitives
  # @body_offset 80
  @font_size 24
  @degrees "°"
  # @radians "rads"
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

    # col = vp_width / 12
    label_value_width = 300
    label_value_height = 50
    goals_width = 400
    goals_height = 50
    # build the graph
    graph =
      Scenic.Graph.build(font: :roboto, font_size: 16, theme: :dark)
      |> Display.Scenic.Gcs.Utils.add_label_value_to_graph(%{width: label_value_width, height: 4*label_value_height, offset_x: 10, offset_y: 10, labels: ["latitude", "longitude", "altitude", "AGL"], ids: [:lat, :lon, :alt, :agl], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_label_value_to_graph(%{width: label_value_width, height: 3*label_value_height, offset_x: 10, offset_y: 4*label_value_height+40, labels: ["airspeed", "speed", "course"], ids: [:airspeed, :speed, :course], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_label_value_to_graph(%{width: label_value_width, height: 3*label_value_height, offset_x: 10, offset_y: 7*label_value_height+70, labels: ["roll", "pitch", "yaw"], ids: [:roll, :pitch, :yaw], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_goals_to_graph(%{goal_id: {:goals, 3}, width: goals_width, height: 2*goals_height, offset_x: 60+label_value_width, offset_y: 10, labels: ["speed", "course", "altitude"], ids: [:speed_cmd, :course_cmd, :altitude_cmd], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_goals_to_graph(%{goal_id: {:goals, 2}, width: goals_width, height: 2*goals_height, offset_x: 60+label_value_width, offset_y: 2*goals_height + 40, labels: ["thrust", "roll", "pitch", "yaw"], ids: [:thrust_2_cmd, :roll_cmd, :pitch_cmd, :yaw_cmd], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_goals_to_graph(%{goal_id: {:goals, 1}, width: goals_width, height: 2*goals_height, offset_x: 60+label_value_width, offset_y: 4*goals_height + 70, labels: ["thrust", "rollrate", "pitchrate", "yawrate"], ids: [:thrust_1_cmd, :rollrate_cmd, :pitchrate_cmd, :yawrate_cmd], font_size: @font_size})

    # subscribe to the simulated temperature sensor
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:telemetry, :pvat}, self())
    Comms.Operator.join_group(__MODULE__, :tx_goals, self())
    Comms.Operator.join_group(__MODULE__, :control_state, self())
    {:ok, graph, push: graph}
  end

  # --------------------------------------------------------
  # receive PV updates from the vehicle
  def handle_cast({{:telemetry, :pvat}, position, velocity, attitude}, graph) do
    # Logger.debug("position: #{Navigation.Utils.LatLonAlt.to_string(position)}")
    roll = Map.get(attitude, :roll,0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(1)
    pitch = Map.get(attitude, :pitch,0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(1)
    yaw =
      Map.get(attitude, :yaw,0) |>
      Common.Utils.Motion.constrain_angle_to_compass()
      |> Common.Utils.Math.rad2deg()
      |> Common.Utils.eftb(1)

    lat = Map.get(position, :latitude,0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(5)
    lon = Map.get(position, :longitude,0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(5)
    alt = Map.get(position, :altitude,0) |> Common.Utils.eftb(2)
    agl = Map.get(position, :agl, 0) |> Common.Utils.eftb(2)

    # v_down = Common.Utils.eftb(velocity.down,1)
    airspeed = Map.get(velocity, :airspeed, 0) |> Common.Utils.eftb(1)
    # Logger.info("disp #{airspeed}")
    speed = Map.get(velocity, :speed,0) |> Common.Utils.eftb(1)

    course=
    Map.get(velocity, :course, 0)
    |> Common.Utils.Motion.constrain_angle_to_compass()
    |> Common.Utils.Math.rad2deg()
    |> Common.Utils.eftb(1)

    graph = Scenic.Graph.modify(graph, :lat, &text(&1, lat <> @degrees))
    |> Scenic.Graph.modify(:lon, &text(&1, lon <> @degrees))
    |> Scenic.Graph.modify(:alt, &text(&1, alt <> @meters))
    |> Scenic.Graph.modify(:agl, &text(&1, agl <> @meters))
    |> Scenic.Graph.modify(:airspeed, &text(&1, airspeed <> @mps))
    |> Scenic.Graph.modify(:speed, &text(&1, speed <> @mps))
    |> Scenic.Graph.modify(:course, &text(&1, course <> @degrees))
    |> Scenic.Graph.modify(:roll, &text(&1, roll <> @degrees))
    |> Scenic.Graph.modify(:pitch, &text(&1, pitch <> @degrees))
    |> Scenic.Graph.modify(:yaw, &text(&1, yaw <> @degrees))
    {:noreply, graph, push: graph}
  end

  def handle_cast({{:tx_goals, level}, cmds}, graph) do
    graph =
      cond do
      level <=1 ->
        rollrate = Map.get(cmds, :rollrate, 0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(0)
        pitchrate = Map.get(cmds, :pitchrate, 0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(0)
        yawrate = Map.get(cmds, :yawrate, 0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(0)
        thrust = Map.get(cmds, :thrust,0)*100 |> Common.Utils.eftb(0)
        graph
        |> Scenic.Graph.modify(:rollrate_cmd, &text(&1,rollrate <> @dps))
        |> Scenic.Graph.modify(:pitchrate_cmd, &text(&1,pitchrate <> @dps))
        |> Scenic.Graph.modify(:yawrate_cmd, &text(&1,yawrate <> @dps))
        |> Scenic.Graph.modify(:thrust_1_cmd, &text(&1,thrust <> @pct))
      level == 2 ->
        roll= Map.get(cmds, :roll, 0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(0)
        pitch = Map.get(cmds, :pitch, 0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(0)
        yaw = Map.get(cmds, :yaw, 0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(0)
        thrust = Map.get(cmds, :thrust, 0)*100 |> Common.Utils.eftb(0)
        graph
        |> Scenic.Graph.modify(:roll_cmd, &text(&1,roll<> @degrees))
        |> Scenic.Graph.modify(:pitch_cmd, &text(&1,pitch<> @degrees))
        |> Scenic.Graph.modify(:yaw_cmd, &text(&1,yaw<> @degrees))
        |> Scenic.Graph.modify(:thrust_2_cmd, &text(&1,thrust <> @pct))
      level == 3 ->
        speed= Map.get(cmds, :speed, 0) |> Common.Utils.eftb(1)
        course= Map.get(cmds, :course, 0) |> Common.Utils.Math.rad2deg() |> Common.Utils.eftb(1)
        altitude= Map.get(cmds, :altitude, 0) |> Common.Utils.eftb(1)
        graph
        |> Scenic.Graph.modify(:speed_cmd, &text(&1,speed<> @mps))
        |> Scenic.Graph.modify(:course_cmd, &text(&1,course<> @degrees))
        |> Scenic.Graph.modify(:altitude_cmd, &text(&1,altitude <> @meters))
      true -> graph
      end
    {:noreply, graph, push: graph}
  end

  def handle_cast({:control_state, control_state}, graph) do
    graph = Enum.reduce(3..-1, graph, fn (goal_level, acc) ->
      if goal_level == control_state do
        {stroke_color, display_level} =
          case goal_level do
            -1 -> {:red, 1}
            0 -> {:yellow, 1}
            _other -> {:green, goal_level}
          end
        Scenic.Graph.modify(acc, {:goals, display_level}, &update_opts(&1, stroke: {@rect_border, stroke_color}))
      else
        Scenic.Graph.modify(acc, {:goals, goal_level}, &update_opts(&1, stroke: {@rect_border, :white}))
      end
    end)
    {:noreply, graph, push: graph}
  end
end
