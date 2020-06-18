defmodule Display.Scenic.System do
  require Logger
  def start_link(config) do
    Logger.debug("Display Supervisor start_link()")
    display_module = Map.get(config, :display_module, Display.Scenic)
    default_scene =
      Module.concat(display_module, Gcs)
      |> Module.concat(config.vehicle_type)

    main_viewport_config = %{
      name: :main_viewport,
      size: {800, 600},
      default_scene: {default_scene, nil},
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
        {Scenic, viewports: [main_viewport_config]}
      ],
      strategy: :one_for_one
    )
  end
end
