defmodule Controller.Pid.StartPidTest do
  alias Controller.Pid, as: Pid
  use ExUnit.Case

  setup do
    registry_module = Comms.ProcessRegistry
    registry_function = :via_tuple
    {:ok, registry_pid} = apply(registry_module, :start_link, [])
    Common.Utils.wait_for_genserver_start(registry_pid)

    pids = %{
      roll: %{aileron: %{kp: 1.0, weight: 0.9},
              rudder: %{kp: 0.1}, weight: 0.1},
      yaw: %{aileron: %{kp: 0.2, weight: 0.2},
             rudder: %{kp: 0.5, weight: 0.8}
      }
    }

    {:ok, [
        config: [
        registry_module: registry_module,
        registry_function: registry_function,
        pids: pids
        ]
      ]}
  end

  test "start PID server", context do
    {:ok, process_id} = Pids.start_link(config)
    Common.Utils.wait_for_genserver_start(process_id)
    assert pid == GenServer.whereis(apply(config[:registry_module], config[:registry_function], [Controller.Pid, Keyword.get(config, :name)]))
  end

  # test "update PID and check output", context do
  #   config = [
  #     name: :a,
  #     kp: 1.0
  #   ]
  #   config = Keyword.merge(context[:config], config)

  #   {:ok, pid} = Pid.start_link(config)
  #   Common.Utils.wait_for_genserver_start(pid)

  #   pv_error = 1.0
  #   pid_output = Pid.update_pid(pid, pv_error, 0.05)
  #   assert pid_output != 0
  #   assert pid_output == Pid.get_output(pid)
  # end

end
