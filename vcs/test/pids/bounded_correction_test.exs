defmodule Pids.BoundedCorrectionTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    pid_config = Configuration.Vehicle.Plane.Pids.get_config()
    Comms.Operator.start_link(%{name: __MODULE__})
    {:ok, [
        config: pid_config
      ]}
  end

  test "start PID server", context do
    max_delta = 0.001
    config = context[:config]
    Pids.System.start_link(config)
    Process.sleep(300)
    pv_cmd_map = %{rollrate: -0.2}
    pv_value_map = %{bodyrate: %{rollrate: 0}}
    rollrate_corr = Common.Utils.Math.constrain(pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate, config.pids.rollrate.aileron.input_min, config.pids.rollrate.aileron.input_max)
    Logger.debug("corr actual/used: #{pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate}/#{rollrate_corr}") 
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,0.05},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    exp_rollrate_aileron_output =
      get_in(config, [:pids, :rollrate, :aileron, :kp])*rollrate_corr + 0.5
      |> Common.Utils.Math.constrain(0, 1)
    Logger.info("output/exp output: #{rollrate_aileron_output}/#{exp_rollrate_aileron_output}")
    assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)

    pv_cmd_map = %{pitch: -0.3}
    pv_value_map = %{attitude: %{pitch: 0}, bodyrate: %{pitchrate: 0}}
    pitch_corr = Common.Utils.Math.constrain(pv_cmd_map.pitch - pv_value_map.attitude.pitch, config.pids.pitch.pitchrate.input_min, config.pids.pitch.pitchrate.input_max)
    Logger.debug("corr actual/used: #{pv_cmd_map.pitch - pv_value_map.attitude.pitch}/#{pitch_corr}")
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_cmds_values, 2}, pv_cmd_map, pv_value_map,0.05},{:pv_cmds_values, 2}, self())
    Process.sleep(100)
    pitch_pitchrate_output = Pids.Pid.get_output(:pitch, :pitchrate)
    exp_pitch_pitchrate_output =
      get_in(config, [:pids, :pitch, :pitchrate, :kp])*pitch_corr
      |> Common.Utils.Math.constrain(config.pids.pitch.pitchrate.output_min, config.pids.pitch.pitchrate.output_max)
    Logger.info("output/exp output: #{pitch_pitchrate_output}/#{exp_pitch_pitchrate_output}")
    assert_in_delta(pitch_pitchrate_output, exp_pitch_pitchrate_output, max_delta)

  end
end
