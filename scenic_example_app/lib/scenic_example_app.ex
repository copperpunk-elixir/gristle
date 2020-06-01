defmodule ScenicExampleApp do
  @moduledoc """
  Starter application using the Scenic framework.
  """

  def start(_type, _args) do
    # load the viewport configuration from config
    main_viewport_config = %{
        name: :main_viewport,
        size: {1400, 600},
        # default_scene: {ScenicExampleApp.Scene.Splash, ScenicExampleApp.Scene.Sensor},
        default_scene: {ScenicExampleApp.Scene.Sensor, nil},
        drivers: [
          %{
            module: Scenic.Driver.Glfw,
            name: :glfw,
            opts: [resizeable: false, title: "scenic_example_app"]
          }
        ]
      }

    # main_viewport_config = Application.get_env(:scenic_example_app, :viewport)

    # start the application with the viewport
    children = [
      ScenicExampleApp.Sensor.Supervisor,
      Comms.ProcessRegistry,
      {Scenic, viewports: [main_viewport_config]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
