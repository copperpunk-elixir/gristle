defmodule TestConfigs.Actuation do
  def get_hw_config_pololu do
    %{
      interface_driver_name: :pololu
    }
  end

  def get_sw_config_actuators(actuator_names, channels, failsafes) do
    actuator_names = Common.Utils.assert_list(actuator_names)
    channels = Common.Utils.assert_list(channels)
    failsafes = Common.Utils.assert_list(failsafes)

    actuators = Enum.reduce(0..length(actuator_names)-1, %{}, fn (index, acc) ->

      Map.put(acc, Enum.at(actuator_names, index), %{
      channel_number: Enum.at(channels, index),
      reversed: false,
      min_pw_ms: 1100,
      max_pw_ms: 1900,
      cmd_limit_min: 0,
      cmd_limit_max: 1,
      failsafe_cmd: Enum.at(failsafes, index),
    })
    end)

    config = %{
      actuator_loop_interval_ms: 50,
      actuators: actuators
    }

  end
end
