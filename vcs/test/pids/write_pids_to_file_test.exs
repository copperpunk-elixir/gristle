defmodule Pids.WritePidsToFileTest do
  use ExUnit.Case
  require Logger
  setup do
    Comms.System.start_link()
    Logging.System.start_link(Configuration.Module.get_config(Logging, nil, nil))
    Pids.System.start_link(Configuration.Module.get_config(Pids, :Plane, :all))
    Process.sleep(300)
    {:ok, []}
  end

  test "Update PIDs realtime" do
    Pids.Pid.set_parameter(:rollrate, :aileron, :kp, 1.234)
    Pids.Pid.set_parameter(:course_ground, :roll, :ki, 0.5599)
    Process.sleep(100)
    Pids.Moderator.write_pids_to_file()
    Process.sleep(200)
  end
end
