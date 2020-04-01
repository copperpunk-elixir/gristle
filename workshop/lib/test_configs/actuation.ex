defmodule TestConfigs.Actuation do
  def get_hw_config_pololu do
    %{
      interface_driver_name: :pololu
    }
  end

  def get_sw_config_single_actuator(actuator_name) do
    actuator = %{
      channel_number: 0,
      reversed: false,
      min_pw_ms: 1100,
      max_pw_ms: 1900,
      cmd_limit_min: 0,
      cmd_limit_max: 1,
      failsafe_cmd: 0.5,
      one_or_two_sided: :two_sided
    }
    actuators = Map.put(%{}, actuator_name, actuator)
    config = %{
      actuator_loop_interval_ms: 50,
      actuators: actuators
    }

  end
end
