defmodule Configuration.Module.Estimation do
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, _node_type) do
    %{
      estimator: %{
        imu_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        ins_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        pv_3_local_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
        att_rate_expected_interval_ms: 20,
        pos_vel_expected_interval_ms: 20,
        airspeed_expected_interval_ms: 200,
        range_expected_interval_ms: 100,
      },
    }
  end
end
