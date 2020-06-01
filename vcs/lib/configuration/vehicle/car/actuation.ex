defmodule Configuration.Vehicle.Car.Actuation do

  @spec get_config() :: map()
  def get_config() do
    %{
      hw_interface: get_hw_config(),
      sw_interface: get_sw_config()
    }
  end

  @spec get_hw_config() :: map()
  def get_hw_config() do
    %{
      interface_driver_name: :pololu
    }
  end

  @spec get_names_channels_failsafes() :: tuple()
  def get_names_channels_failsafes() do
    actuator_names = [:steering, :throttle]
    channels = [0, 1]
    failsafes = [0.5, 0.0]
    {actuator_names, channels, failsafes}
  end

  @spec get_sw_config() :: map()
  def get_sw_config() do
    {actuator_names, channels, failsafes} = get_names_channels_failsafes()
    actuators = Enum.reduce(0..length(actuator_names)-1, %{}, fn (index, acc) ->
      Map.put(acc, Enum.at(actuator_names, index), %{
            channel_number: Enum.at(channels, index),
            reversed: false,
            min_pw_ms: 1100,
            max_pw_ms: 1900,
            cmd_limit_min: 0.0,
            cmd_limit_max: 1.0,
            failsafe_cmd: Enum.at(failsafes, index)
              })
    end)

    #return config
    %{
      actuator_loop_interval_ms: 20,
      actuators: actuators
    }
  end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    {actuator_names, _channels, failsafes} = get_names_channels_failsafes()
    names_with_index = Enum.with_index(actuator_names)
    failsafe_map = Enum.reduce(names_with_index, %{}, fn({actuator_name, index}, acc) ->
        Map.put(acc, actuator_name, Enum.at(failsafes,index))
    end)
    # return config
    [
      %{
        name: :actuator_cmds,
        default_message_behavior: :default_value,
        default_value: failsafe_map,
        value_type: :map
      }
    ]
  end

end
