defmodule Control.GetControlStateTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    swarm_gsm_config =%{
        modules_to_monitor: [:estimator],
        state_loop_interval_ms: 50,
        initial_state: :disarmed
    }
    Swarm.Gsm.start_link(swarm_gsm_config)
    {:ok, []}
  end

  test "Control Get Control State" do
    config = %{controller: TestConfigs.Control.get_config_car()}
    Control.System.start_link(config)
    Process.sleep(300)
    assert Control.Controller.get_control_state() == -1#initializing
    new_state = 1#:manual
    Swarm.Gsm.add_desired_control_state(new_state, [0], 200)
    Process.sleep(100)
    assert Control.Controller.get_control_state() == new_state
    Process.sleep(200)
    assert Control.Controller.get_control_state() == new_state
  end

 end
