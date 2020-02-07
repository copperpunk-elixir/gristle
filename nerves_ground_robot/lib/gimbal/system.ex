defmodule Gimbal.System do
  def start_link(config) do
    Common.Utils.Comms.start_registry(:topic_registry)

    Supervisor.start_link(
      [
        Common.ProcessRegistry,
        {Comms.Operator, config.comms},
        {CommandSorter.System, nil},
        {Sensors.Uart.Bno080, config.imu},
        {Gimbal.Controller, config.gimbal_controller},
        {Pid.Controller, config.pid_controller},
        {Actuator.Controller, config.actuator_controller}
      ],
      strategy: :one_for_one
    )
  end
end
