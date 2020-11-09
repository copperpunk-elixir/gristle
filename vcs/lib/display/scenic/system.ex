defmodule Display.Scenic.System do
  use Supervisor
  require Logger
  def start_link(config) do
    Logger.info("Display Supervisor start_link()")
    display_module = Map.get(config, :display_module, Display.Scenic)

    #GCS
    gcs_scene =
      Module.concat(display_module, Gcs)
      |> Module.concat(String.to_existing_atom(config.vehicle_type))

    gcs_config = %{
      name: :gcs,
      size: {800, 700},
      default_scene: {gcs_scene, nil},
      drivers: [
        %{
          module: Scenic.Driver.Glfw,
          name: :gcs_driver,
          opts: [resizeable: false, title: "gcs"]
        }
      ]
    }

    #PLANNER
    planner_scene = Module.concat(display_module, Planner)

    planner_config = %{
      name: :planner,
      size: {1000, 1000},
      default_scene: {planner_scene, nil},
      drivers: [
        %{
          module: Scenic.Driver.Glfw,
          name: :planner_driver,
          opts: [resizeable: false, title: "planner"]
        }
      ]
    }

    Comms.System.start_link()

    viewports = [
      gcs_config,
      # planner_config
    ]
    config = %{
      viewports: viewports
    }

    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  def init(config) do
    children = [Supervisor.child_spec({Scenic, viewports: config.viewports}, id: :scenic_app)]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
