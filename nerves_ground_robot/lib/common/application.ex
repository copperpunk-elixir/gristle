defmodule Common.Application do
  use Application
  require Logger
  # TODO: there is no reason to have to hardcode this. We should be able to build the module name from the node_type
  def start(_type, _args) do
    Logger.debug("Start Application")
    Logger.debug("Start ProcessRegistry")
    Comms.ProcessRegistry.start_link()
    Logger.debug("Start local registry")
    Common.Utils.Comms.start_registry(:topic_registry)
    Logger.debug("Start pg2")
    :pg2.start()
    config = NodeConfig.Master.get_config()
    Logger.debug("Load #{config.node_type}")
    case config.node_type do
      :pc ->
        Pc.System.start_link(config)
      :gimbal ->
        Gimbal.System.start_link(config)
      :gimbal_joystick ->
        Joystick.System.start_link(config)
      :track_vehicle ->
        TrackVehicle.System.start_link(config)
      :track_vehicle_joystick ->
        Joystick.System.start_link(config)
      :track_vehicle_and_gimbal_joystick ->
        Joystick.System.start_link(config)
    end
  end
end
