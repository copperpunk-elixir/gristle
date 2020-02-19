defmodule TrackVehicle.System do
  def start_link(config) do
    Common.Utils.Comms.start_registry(:topic_registry)

    Supervisor.start_link(
      [
        Common.ProcessRegistry,
        {Comms.Operator, config.comms},
        {TrackVehicle.Controller, config.track_vehicle_controller},
        {Actuator.InterfaceOutput, config.actuator_controller}
      ],
      strategy: :one_for_one
    )
  end
end
