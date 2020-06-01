defmodule Display.Scenic.Gcs.Plane do
  use Scenic.Scene
  require Logger

  import Scenic.Primitives
  import Scenic.Components
  # @body_offset 80
  @font_size 24
  @degrees "°"
  @dps "°/s"
  @meters "m"
  @mps "m/s"
  @pct "%"

  @offset_x 0
  # @width 300
  @height 50
  @labels {"", "", ""}
  @rect_border 6

  @moduledoc """
  This version of `Sensor` illustrates using spec functions to
  construct the display graph. Compare this with `Sensor` which uses
  anonymous functions.
  """

  # ============================================================================
  def init(_, opts) do
    Logger.debug("Sensor.init: #{inspect(opts)}")
    {:ok, %Scenic.ViewPort.Status{size: {vp_width, _}}} =
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
      |> Display.Scenic.Gcs.Utils.add_label_value_to_graph(%{width: label_value_width, height: 3*label_value_height, offset_x: 10, offset_y: 10, labels: ["latitude", "longitude", "altitude"], ids: [:lat, :lon, :alt], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_label_value_to_graph(%{width: label_value_width, height: 2*label_value_height, offset_x: 10, offset_y: 3*label_value_height+40, labels: ["speed", "course"], ids: [:speed, :course], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_label_value_to_graph(%{width: label_value_width, height: 3*label_value_height, offset_x: 10, offset_y: 5*label_value_height+70, labels: ["roll", "pitch", "yaw"], ids: [:roll, :pitch, :yaw], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_goals_to_graph(%{goal_id: {:goals, 3}, width: goals_width, height: 2*goals_height, offset_x: 60+label_value_width, offset_y: 10, labels: ["speed", "course", "altitude"], ids: [:speed_cmd, :course_cmd, :altitude_cmd], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_goals_to_graph(%{goal_id: {:goals, 2}, width: goals_width, height: 2*goals_height, offset_x: 60+label_value_width, offset_y: 2*goals_height + 40, labels: ["thrust", "roll", "pitch", "yaw"], ids: [:thrust_2_cmd, :roll_cmd, :pitch_cmd, :yaw_cmd], font_size: @font_size})
      |> Display.Scenic.Gcs.Utils.add_goals_to_graph(%{goal_id: {:goals, 1}, width: goals_width, height: 2*goals_height, offset_x: 60+label_value_width, offset_y: 4*goals_height + 70, labels: ["thrust", "rollrate", "pitchrate", "yawrate"], ids: [:thrust_1_cmd, :rollrate_cmd, :pitchrate_cmd, :yawrate_cmd], font_size: @font_size})

    # subscribe to the simulated temperature sensor
    Comms.Operator.start_link(%{name: __MODULE__})
    Comms.Operator.join_group(__MODULE__, :pv_estimate, self())
    Comms.Operator.join_group(__MODULE__, :tx_goals, self())

    {:ok, graph, push: graph}
  end

  # --------------------------------------------------------
  # receive PV updates from the vehicle
  def handle_cast({:pv_estimate, pv_value_map}, graph) do
    position =pv_value_map.position
    velocity = pv_value_map.velocity
    attitude = pv_value_map.attitude

    roll = Common.Utils.eftb(Common.Utils.Math.rad2deg(attitude.roll),1)
    pitch = Common.Utils.eftb(Common.Utils.Math.rad2deg(attitude.pitch),1)
    yaw = Common.Utils.eftb(Common.Utils.Math.rad2deg(attitude.yaw),1)

    lat = Common.Utils.eftb(Common.Utils.Math.rad2deg(position.latitude),5)
    lon = Common.Utils.eftb(Common.Utils.Math.rad2deg(position.longitude),5)
    alt = Common.Utils.eftb(position.altitude,2)

    # v_down = Common.Utils.eftb(velocity.down,1)
    # course = :math.atan2(velocity.east, velocity.north)
    speed_value = Common.Utils.Math.hypot(velocity.north, velocity.east)
    speed = Common.Utils.eftb(speed_value,1)

    course =
    if speed_value > 2.0 do
      :math.atan2(velocity.east, velocity.north)
      |> Common.Utils.Math.rad2deg()
      |> Common.Utils.eftb(1)
    else
      yaw
    end

    graph = Scenic.Graph.modify(graph, :lat, &text(&1, lat <> @degrees))
    |> Scenic.Graph.modify(:lon, &text(&1, lon <> @degrees))
    |> Scenic.Graph.modify(:alt, &text(&1, alt <> @meters))
    |> Scenic.Graph.modify(:speed, &text(&1, speed <> @mps))
    |> Scenic.Graph.modify(:course, &text(&1, course <> @degrees))
    |> Scenic.Graph.modify(:roll, &text(&1, roll <> @degrees))
    |> Scenic.Graph.modify(:pitch, &text(&1, pitch <> @degrees))
    |> Scenic.Graph.modify(:yaw, &text(&1, yaw <> @degrees))
    {:noreply, graph, push: graph}
  end

  def handle_cast({{:tx_goals, level}, cmds}, graph) do
    graph =
      case level do
        1 ->
          rollrate = Common.Utils.eftb(Common.Utils.Math.rad2deg(cmds.rollrate),0)
          pitchrate = Common.Utils.eftb(Common.Utils.Math.rad2deg(cmds.pitchrate),0)
          yawrate = Common.Utils.eftb(Common.Utils.Math.rad2deg(cmds.yawrate),0)
          thrust = Common.Utils.eftb(cmds.thrust*100,0)
          graph
          |> Scenic.Graph.modify(:rollrate_cmd, &text(&1,rollrate <> @dps))
          |> Scenic.Graph.modify(:pitchrate_cmd, &text(&1,pitchrate <> @dps))
          |> Scenic.Graph.modify(:yawrate_cmd, &text(&1,yawrate <> @dps))
          |> Scenic.Graph.modify(:thrust_1_cmd, &text(&1,thrust <> @pct))
        2 ->
          roll= Common.Utils.eftb(Common.Utils.Math.rad2deg(cmds.roll),0)
          pitch= Common.Utils.eftb(Common.Utils.Math.rad2deg(cmds.pitch),0)
          yaw= Common.Utils.eftb(Common.Utils.Math.rad2deg(cmds.yaw),0)
          thrust = Common.Utils.eftb(cmds.thrust*100,0)
          graph
          |> Scenic.Graph.modify(:roll_cmd, &text(&1,roll<> @degrees))
          |> Scenic.Graph.modify(:pitch_cmd, &text(&1,pitch<> @degrees))
          |> Scenic.Graph.modify(:yaw_cmd, &text(&1,yaw<> @degrees))
          |> Scenic.Graph.modify(:thrust_2_cmd, &text(&1,thrust <> @pct))
        3 ->
          speed= Common.Utils.eftb(cmds.speed,1)
          course= Common.Utils.eftb(Common.Utils.Math.rad2deg(cmds.course),0)
          altitude= Common.Utils.eftb(cmds.altitude,1)
          graph
          |> Scenic.Graph.modify(:speed_cmd, &text(&1,speed<> @mps))
          |> Scenic.Graph.modify(:course_cmd, &text(&1,course<> @degrees))
          |> Scenic.Graph.modify(:altitude_cmd, &text(&1,altitude <> @meters))
         _other -> graph
      end

    graph = Enum.reduce(1..4, graph, fn (goal_level, acc) ->
      if goal_level == level do
        Scenic.Graph.modify(acc, {:goals, goal_level}, &update_opts(&1, stroke: {@rect_border, :green}))
      else
        Scenic.Graph.modify(acc, {:goals, goal_level}, &update_opts(&1, stroke: {@rect_border, :white}))
      end
    end)
    {:noreply, graph, push: graph}
  end
end
