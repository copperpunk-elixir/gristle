defmodule NodeConfig.Master do
  require Bitwise
  require Logger

  def get_config() do
    node_module = get_node_module()
    sw_config = get_sw_config(node_module)
    Map.put(sw_config, :node_module, node_module)
  end

  def read_hw_gpio() do
    # IMPORTANT!!!!
    # THESE ARE HARDCODED
    pins = [19, 16, 13, 12, 6, 5]
    pins
    |> Enum.with_index
    |> Enum.reduce(0, fn ({pin, index}, acc) ->
      pin_ref = Peripherals.Gpio.Utils.get_gpio_ref_input_pullup(pin)
      value =
        case pin_ref do
          nil -> 0
          ref ->
            Process.sleep(1)
            1 - Circuits.GPIO.read(ref)
        end
      Logger.debug("value at pin #{pin}: #{value}")
      acc + Bitwise.<<<(value, index)
    end)
  end

  def get_node_module() do
    hw_config_map = %{
      0 => Pc,
      1 => Gimbal,
      2 => GimbalJoystick,
      3 => TrackVehicle,
      4 => TrackVehicleJoystick,
      5 => TrackVehicleAndGimbalJoystick
      # 3 => :time_of_flight
    }
    hw_config_key = read_hw_gpio()
    node_module = Map.get(hw_config_map, hw_config_key, :unknown)
    if node_module == :unknown do
      raise("Node type is unknown! Please check jumpers.")
    else
      Logger.debug("Loading node: #{node_module}")
    end
    node_module
  end

  def get_cookie() do
    :cargoship
  end

  def get_interface() do
    :wlan0
  end

  def get_sw_config(node_module) do
    apply(Module.concat([NodeConfig, node_module], :get_config, [])
    # case node_type do
    #   :pc ->
    #     NodeConfig.Pc.get_config()
    #   :gimbal ->
    #     NodeConfig.Gimbal.get_config()
    #   :gimbal_joystick ->
    #     NodeConfig.GimbalJoystick.get_config()
    #   :track_vehicle ->
    #     NodeConfig.TrackVehicle.get_config()
    #   :track_vehicle_joystick ->
    #     NodeConfig.TrackVehicleJoystick.get_config()
    #   :track_vehicle_and_gimbal_joystick ->
    #     NodeConfig.TrackVehicleAndGimbalJoystick.get_config()
    # end
  end

  def get_network_config(interface) do
    case interface do
      :wlan0 ->
        %{type: VintageNetWiFi,
          vintage_net_wifi: %{
            networks: [
              %{
                key_mgmt: :wpa_psk,
                psk: "binghamplace",
                ssid: "dialup"
              }
            ]
          },
          ipv4: %{method: :dhcp}
         }
      :eth0 ->
        %{}
    end
  end
end
