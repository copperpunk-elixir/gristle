defmodule Pids.UpdateRealtimeTest do
  use ExUnit.Case
  require Logger
  setup do
    Comms.System.start_link()
    Logging.System.start_link(Configuration.Module.get_config(Logging, nil, nil))
    Process.sleep(100)
    {:ok, []}
  end

  test "Update PIDs realtime" do
    vehicle_type = :Plane
    pid_config = %{
      pids: %{rollrate: %{
                 aileron: %{
                   kp: 1.0,
                   ki: 0.1,
                   kd: 0.001,
                   output_min: 0,
                   output_neutral: 0.5,
                   output_max: 1.0,
                   input_min: -1.57,
                   input_max: 1.57
                 }}
             },
      actuator_cmds_msg_classification: [0,1],
      pv_cmds_msg_classification: [0,1]
    }
    Pids.System.start_link(pid_config)

    max_delta = 0.00001
    op_name = :start_pid_test
    aileron_pid = pid_config.pids.rollrate.aileron
    Comms.System.start_operator(op_name)

    kp = Pids.Pid.get_parameter(:rollrate, :aileron, :kp)
    assert kp == aileron_pid.kp

    new_kp = 2.0
    Pids.Pid.set_parameter(:rollrate, :aileron, :kp, new_kp)
    kp = Pids.Pid.get_parameter(:rollrate, :aileron, :kp)
    assert kp == new_kp

    rr_ail = Pids.Pid.get_all_parameters(:rollrate, :aileron)
    Logger.info("rollrate/aileron: #{inspect(rr_ail)}")
    assert rr_ail.correction_min == aileron_pid.input_min

    # Write to file
    Pids.Pid.write_parameters_to_file(:rollrate, :aileron)
    Process.sleep(200)
  end
end
