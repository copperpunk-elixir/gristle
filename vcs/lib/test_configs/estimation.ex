defmodule TestConfigs.Estimation do
  def get_estimator_config() do
    %{estimator:
      %{
        imu_loop_interval_ms: 50,
        imu_loop_timeout_ms: 1000,
        ins_loop_interval_ms: 100,
        ins_loop_timeout_ms: 2000,
        telemetry_loop_interval_ms: 1000,
      }}
  end
end
