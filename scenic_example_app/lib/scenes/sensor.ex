defmodule ScenicExampleApp.Scene.Sensor do
  use Scenic.Scene
  require Logger
  alias Scenic.Graph
  alias Scenic.ViewPort
  alias Scenic.Sensor

  import Scenic.Primitives
  import Scenic.Components

  # @body_offset 80
  @font_size 24
  @degrees "°"
  @meters "m"
  @mps "m/s"

  @offset_x 0
  # @width 300
  @height 50
  @labels {"", "", ""}


  @moduledoc """
  This version of `Sensor` illustrates using spec functions to
  construct the display graph. Compare this with `Sensor` which uses
  anonymous functions.
  """

  # ============================================================================
  # setup
  # def start_link(_) do
  #   Logger.warn("Sensor start_link")
  #   {:ok, pid} = Common.Utils.start_link_redudant(GenServer, __MODULE__, nil, __MODULE__)
  #   GenServer.cast(__MODULE__, :begin)
  #   {:ok, pid}
  # end
  # --------------------------------------------------------
  def init(_, opts) do
    Logger.debug("Sensor.init: #{inspect(opts)}")
    {:ok, %ViewPort.Status{size: {vp_width, _}}} =
      opts[:viewport]
      |> ViewPort.info()

    # col = vp_width / 12
    com_width = 300
    com_height = 50
    # build the graph
    graph =
      Graph.build(font: :roboto, font_size: 16, theme: :dark)
      |> add_label_value_component_to_graph(%{width: com_width, height: 3*com_height, offset_x: 10, offset_y: 10, labels: ["latitude", "longitude", "altitude"], ids: [:lat, :lon, :alt]})
      |> add_label_value_component_to_graph(%{width: com_width, height: 2*com_height, offset_x: 10, offset_y: 3*com_height+40, labels: ["speed", "course"], ids: [:speed, :course]})

      |> add_label_value_component_to_graph(%{width: com_width, height: 3*com_height, offset_x: 10, offset_y: 5*com_height+70, labels: ["roll", "pitch", "yaw"], ids: [:roll, :pitch, :yaw]})

      # |> Notes.add_to_graph("hi")
    # IO.inspect(graph)
    # subscribe to the simulated temperature sensor
    # Sensor.subscribe(:temperature)
    Comms.Operator.start_link(%{name: __MODULE__})
    Comms.Operator.join_group(__MODULE__, :pv_estimate, self())

    {:ok, graph, push: graph}
  end

  # @impl GenServer
  # def handle_cast(:begin, state) do
  #   Comms.Operator.start_link(%{name: __MODULE__})
  #   Comms.Operator.join_group(__MODULE__, :pv_estimate, self())
  #   {:noreply, state}
  # end

  # --------------------------------------------------------
  # receive updates from the simulated temperature sensor
  def handle_info({:sensor, :data, {:temperature, kelvin, _}}, graph) do
    IO.puts("rx temp")
    # fahrenheit
    temperature =
      (9 / 5 * (kelvin - 273) + 32)
      # temperature = kelvin - 273                      # celsius
      |> :erlang.float_to_binary(decimals: 1)

    # center the temperature on the viewport
    graph = Graph.modify(graph, :lat, &button(&1, temperature <> @degrees))
    {:noreply, graph, push: graph}
  end

  def handle_cast({:pv_estimate, pv_value_map}, graph) do
    Logger.warn("rx pv_estimate")
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

    graph = Graph.modify(graph, :lat, &text(&1, lat <> @degrees))
    |> Graph.modify(:lon, &text(&1, lon <> @degrees))
    |> Graph.modify(:alt, &text(&1, alt <> @meters))
    |> Graph.modify(:speed, &text(&1, speed <> @mps))
    |> Graph.modify(:course, &text(&1, course <> @degrees))
    |> Graph.modify(:roll, &text(&1, roll <> @degrees))
    |> Graph.modify(:pitch, &text(&1, pitch <> @degrees))
    |> Graph.modify(:yaw, &text(&1, yaw <> @degrees))
    {:noreply, graph, push: graph}
  end

  def add_label_value_component_to_graph(graph, config) do
    offset_x = Map.get(config, :offset_x, @offset_x)
    offset_y = Map.get(config, :offset_y, @height)
    width = Map.get(config, :width, @height)
    height = Map.get(config, :height, @height)
    labels = Map.get(config, :labels, @labels)
    font_size = Map.get(config, :font_size, @font_size)
    # ids = Map.get(config, :ids, {:x,:y, :z})
    ids = config.ids
    col = width /2
    row = height/length(labels)
    v_spacing = 1
    h_spacing = 3
    graph = Enum.reduce(Enum.with_index(labels),graph , fn ({label, index}, acc) ->
      group(acc, fn g ->
        g
        |> button(
          label,
        width: col - 2*h_spacing,
        height: row-2*v_spacing,
        theme: :secondary,
        translate: {0, index*(row+v_spacing)}
        )
      end,
        translate: {offset_x + h_spacing, offset_y},
        button_font_size: 24)
    end)
    graph = Enum.reduce(Enum.with_index(ids),graph , fn ({id, index}, acc) ->
      group(acc, fn g ->
        g
        |>
        text(
          "",
          text_align: :center_middle,
          font_size:  font_size,
          id: id,
          translate: {0, index*row},
        )
      end,
        translate: {offset_x + 1.5*col + h_spacing, offset_y + row/2},
        button_font_size: 24)
    end)
    graph


  #   graph
  #   # |> rect({width, 6+height}, stroke: {6,{0,0,0}}, translate: {offset_x, offset_y-3})
  #   |> group(
  #   fn graph ->
  #     graph
  #     |> group(
  #     fn g ->
  #       g
  #       |> button(
  #         elem(labels,0),
  #       width: col - 2*h_spacing,
  #       height: row-2*v_spacing,
  #       theme: :secondary,
  #       translate: {0, 0}
  #       )
  #       |> button(
  #         elem(labels,1),
  #       width: col - 2*h_spacing,
  #       height: row-2*v_spacing,
  #       theme: :secondary,
  #       translate: {0, row+v_spacing}
  #       )
  #       |> button(
  #         elem(labels, 2),
  #       width: col - 2*h_spacing,
  #       height: row-2*v_spacing,
  #       theme: :secondary,
  #       translate: {0, 2*(row+v_spacing)}
  #       )
  #     end,
  #     translate: {h_spacing, 0},
  #     button_font_size: 24
  #     )
  #     |> group(
  #     fn g ->
  #       g
  #       |> text(
  #         "0.0",
  #       text_align: :center_middle,
  #       font_size:  font_size,
  #       id: elem(ids, 0),
  #       )
  #       |> text(
  #         "1.0",
  #       text_align: :center_middle,
  #       font_size:  font_size,
  #       id: elem(ids, 1),
  #       translate: {0, row},
  #       )
  #       |> text(
  #         "2.0",
  #       text_align: :center_middle,
  #       font_size:  font_size,
  #       id: elem(ids, 2),
  #       translate: {0, 2*row},
  #       )
  #     end,
  #     translate: {1.5*col+h_spacing, row/2}
  #     )
  #   end,
  #   translate: {offset_x, offset_y}
  #   )
  end



  # def filter_event({:click, :maintenance}, _from, state) do
  #   IO.puts("maint cloicked")
  #   {:cont, {:click, :maintenance}, state}
  # end
end
