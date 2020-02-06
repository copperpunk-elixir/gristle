defmodule NodeConfig.Master do
  require Bitwise
  require Logger

  def get_config() do
    node_type = get_node_type()
    sw_config = get_sw_config(node_type)
    Map.put(sw_config, :node_type, node_type)
  end

  def read_hw_gpio() do
    # IMPORTANT!!!!
    # THESE ARE HARDCODED
    pins = [19, 16, 13, 12]
    pins
    |> Enum.with_index
    |> Enum.reduce(0, fn ({pin, index}, acc) ->
      pin_ref = Sensors.Gpio.Utils.get_gpio_ref_input_pullup(pin)
      Process.sleep(1)
      value =  1 - Circuits.GPIO.read(pin_ref)
      Logger.debug("value at pin #{pin}: #{value}")
      acc + Bitwise.<<<(value, index)
    end)
  end

  def get_node_type() do
    hw_config_map = %{
      1 => :gimbal,
      2 => :gimbal_joystick,
      3 => :track_vehicle,
      4 => :track_vehicle_joystick,
      5 => :track_vehicle_and_gimbal_joystick
      # 3 => :time_of_flight
    }
    hw_config_key = read_hw_gpio()
    node_type = Map.get(hw_config_map, hw_config_key, :unknown)
    if node_type == :unknown do
      raise("Node type is unknown! Please check jumpers.")
    else
      Logger.debug("Loading node: #{node_type}")
    end
    node_type
  end

  def get_cookie() do
    :cargoship
  end

  def get_interface() do
    :wlan0
  end

  def get_sw_config(node_type) do
    case node_type do
      :gimbal ->
        NodeConfig.Gimbal.get_config()
      :gimbal_joystick ->
        NodeConfig.GimbalJoystick.get_config()
      :track_vehicle ->
        NodeConfig.TrackVehicle.get_config()
      :track_vehicle_joystick ->
        NodeConfig.TrackVehicleJoystick.get_config()
      :track_vehicle_and_gimbal_joystick ->
        NodeConfig.TrackVehicleAndGimbalJoystick.get_config()
    end
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
