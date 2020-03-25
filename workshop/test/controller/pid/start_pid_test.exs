defmodule Controller.Pid.StartPidTest do
  alias Controller.Pid, as: Pid
  use ExUnit.Case

  setup do
    registry_module = Comms.ProcessRegistry
    registry_function = :via_tuple
    {:ok, registry_pid} = apply(registry_module, :start_link, [])
    Common.Utils.wait_for_genserver_start(registry_pid)

    {:ok, [
        registry_module: registry_module,
        registry_function: registry_function
      ]}
  end

  test "start PID server", context do
    config = [
      registry_module: context[:registry_module],
      registry_function: context[:registry_function],
      name: :a,
      kp: 1.0
    ]
    {:ok, pid} = Pid.start_link(config)
    Common.Utils.wait_for_genserver_start(pid)
    assert pid == GenServer.whereis(apply(config[:registry_module], config[:registry_function], [Controller.Pid, config[:name]]))
  end

  test "update PID and check output", context do
    config = [
      registry_module: context[:registry_module],
      registry_function: context[:registry_function],
      name: :a,
      kp: 1.0
    ]
    {:ok, pid} = Pid.start_link(config)
    Common.Utils.wait_for_genserver_start(pid)

    pv_error = 1.0
    pid_output = Pid.update_pid(pid, pv_error, 0.05)
    assert pid_output != 0
    assert pid_output == Pid.get_output(pid)
  end

end
