defmodule Display.Scenic.System do
  require Logger
  def start_link(config) do
    Logger.debug("Display Supervisor start_link()")
    display_module = Map.get(config, :display_module, Display.Scenic)

    #GCS
    gcs_scene =
      Module.concat(display_module, Gcs)
      |> Module.concat(config.vehicle_type)

    gcs_config = %{
      name: :gcs
      size: {800, 600},
      default_scene: {gcs_scene, nil},
      drivers: [
        %{
          module: Scenic.Driver.Glfw,
          name: :glfw,
          opts: [resizeable: false, title: "gcs"]
        }
      ]
    }

    #PLANNER
    planner_scene = Module.concat(display_module, Planner)

    planner_config = %{
      name: :planner
      size: {800, 600},
      default_scene: {planner_scene, nil},
      drivers: [
        %{
          module: Scenic.Driver.Glfw,
          name: :glfw,
          opts: [resizeable: false, title: "scenic_example_app"]
        }
      ]
    }

    Comms.System.start_link()

    Supervisor.start_link(
      [
        {Scenic, viewports: [gcs_config]},

      ],
      strategy: :one_for_one
    )
  end
end
