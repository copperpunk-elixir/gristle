defmodule Control.GetControlStateTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    Comms.Operator.start_link()
    swarm_gsm_config =%{
        modules_to_monitor: [:estimator],
        state_loop_interval_ms: 50,
        initial_state: :disarmed
    }
    Swarm.Gsm.start_link(swarm_gsm_config)
    {:ok, []}
  end

  test "Control Get Control State" do
    process_variables = [:roll, :pitch]
    controller_config = TestConfigs.Control.get_config_with_pvs(process_variables)
    {:ok, pid} = Control.Controller.start_link(controller_config)
    Process.sleep(200)
    assert Control.Controller.get_control_state() == nil
    new_state = Swarm.Gsm.get_state_enum(:attitude)
    Swarm.Gsm.add_desired_control_state(new_state, [0], 200)
    Process.sleep(100)
    assert Control.Controller.get_control_state() == new_state
    Process.sleep(200)
    assert Control.Controller.get_control_state() == new_state
  end

 end
