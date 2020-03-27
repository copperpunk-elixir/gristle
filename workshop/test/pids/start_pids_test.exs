defmodule Controller.Pid.StartPidTest do
  use ExUnit.Case

  setup do
    {:ok, registry_pid} = Comms.ProcessRegistry.start_link()
    Common.Utils.wait_for_genserver_start(registry_pid)

    pids = %{
      roll: %{aileron: %{kp: 1.0, weight: 0.9},
              rudder: %{kp: 0.1, weight: 0.1}
             },
      yaw: %{aileron: %{kp: 0.2, weight: 0.2},
             rudder: %{kp: 0.5, weight: 0.8}
      }
    }

    {:ok, [
        config: %{
        pids: pids
        }
      ]}
  end

  test "start PID server", context do
    config = %{}
    config = Map.merge(context[:config], config)
    {:ok, process_id} = Pids.System.start_link(config)
    Common.Utils.wait_for_genserver_start(process_id)
    assert process_id == GenServer.whereis(Pids.System)
  end

  test "update PID and check output", context do
    config = %{}
    config = Map.merge(context[:config], config)
    {:ok, process_id} = Pids.System.start_link(config)
    Common.Utils.wait_for_genserver_start(process_id)

    pv_error = 1.0
    Pids.System.update_pids(:roll, pv_error, 0.05)
    Process.sleep(100)
    roll_aileron_output = Pids.Pid.get_output(:roll, :aileron)
    roll_rudder_output = Pids.Pid.get_output(:roll, :rudder)
    assert roll_aileron_output == get_in(config, [:pids, :roll, :aileron, :kp])*pv_error
    assert roll_rudder_output == get_in(config, [:pids, :roll, :rudder, :kp])*pv_error
  end

end
