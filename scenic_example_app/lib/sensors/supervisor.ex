# a simple supervisor that starts up the Scenic.SensorPubSub server
# and any set of other sensor processes

defmodule ScenicExampleApp.Sensor.Supervisor do
  use Supervisor
  require Logger

  alias ScenicExampleApp.Sensor.Temperature

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    estimator_config = %{
      imu_loop_interval_ms: 50,
      imu_loop_timeout_ms: 1000,
      ins_loop_interval_ms: 100,
      ins_loop_timeout_ms: 2000,
      telemetry_loop_interval_ms: 100,
    }
    
    Logger.debug("Sensor.Supervisor init")
    children = [
      Scenic.Sensor,
      {Estimation.Estimator, estimator_config},
      {Peripherals.Uart.VnIns, %{}},
      # Temperature
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
