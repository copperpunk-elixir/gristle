defmodule Display.Scenic.Gcs.Utils do
  require Logger
  import Scenic.Primitives
  import Scenic.Components


  @rect_border 6

  def add_label_value_to_graph(graph, config) do
    offset_x = config.offset_x
    offset_y = config.offset_y
    width = config.width
    height = config.height
    labels = config.labels
    font_size = config.font_size
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
          translate: {0, index*row}
        )
      end,
        translate: {offset_x + 1.5*col + h_spacing, offset_y + row/2},
        button_font_size: 24)
    end)
    graph
  end

  def add_goals_to_graph(graph, config) do
    goal_id = config.goal_id
    offset_x = config.offset_x
    offset_y = config.offset_y
    width = config.width
    height = config.height
    labels = config.labels
    font_size = config.font_size
    # ids = Map.get(config, :ids, {:x,:y, :z})
    ids = config.ids
    col = width /length(labels)
    row = height/2
    v_spacing = 1
    h_spacing = 3
    graph = Enum.reduce(Enum.with_index(ids),graph , fn ({id, index}, acc) ->
      group(acc, fn g ->
        g
        |>
        text(
          "",
          text_align: :center_middle,
          font_size:  font_size,
          id: id,
          translate: {index*(col+h_spacing), 0}
        )
      end,
        translate: {offset_x + 0.5*col + h_spacing, offset_y + row/2},
        button_font_size: 24)
    end)
    graph = Enum.reduce(Enum.with_index(labels),graph , fn ({label, index}, acc) ->
      group(acc, fn g ->
        g
        |> button(
          label,
        width: col - 2*h_spacing,
        height: row-2*v_spacing,
        theme: :primary,
        translate: {index*(col+h_spacing), row}
        )
      end,
        translate: {offset_x + h_spacing, offset_y},
        button_font_size: 24)
    end)

    graph
    |> rect(
      {width+2*h_spacing, height},
    id: goal_id,
    translate: {offset_x, offset_y},
    stroke: {@rect_border, :white}
    )
  end

  @interior_angle 2.677945 #= :math.pi/2 + :math.atan(ratio)
  @ratio_sq 4
  @spec draw_arrow(map(), float(), float(), float(), float(), atom(), boolean(), atom()) :: Scenic.Graph.t()
  def draw_arrow(graph, x, y, heading, size, id, is_new \\ false,fill \\ :yellow) do
    # Center of triangle at X/Y
    tail_size = :math.sqrt(size*size*(1 + @ratio_sq))
    head = {x + size*:math.sin(heading), y - size*:math.cos(heading)}
    tail_1 ={x + tail_size*:math.sin(heading + @interior_angle), y - tail_size*:math.cos(heading + @interior_angle)}
    tail_2 ={x + tail_size*:math.sin(heading - @interior_angle), y - tail_size*:math.cos(heading - @interior_angle)}
    if (is_new) do
      triangle(graph, {head, tail_1, tail_2}, fill: fill, id: id)
    else
      Scenic.Graph.modify(graph, id, fn p ->
        triangle(p, {head, tail_1, tail_2}, fill: fill, id: id)
      end)
    end
  end
end
