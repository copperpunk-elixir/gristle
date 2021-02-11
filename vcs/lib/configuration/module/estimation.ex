defmodule Configuration.Module.Estimation do
  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, _node_type) do
    [
      estimator: [
        imu_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        ins_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        sca_values_slow_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
        att_rate_expected_interval_ms: 50,
        pos_vel_expected_interval_ms: 50,
        airspeed_expected_interval_ms: 200,
        range_expected_interval_ms: 100,
      ]
    ]
  end
end
