defmodule Configuration.Module.Cluster do
  require Logger

  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, node_type) do
    [
      heartbeat: get_heartbeat_config(node_type),
      network: get_network_config()
    ]
  end

  @spec get_heartbeat_config(binary()) :: list()
  def get_heartbeat_config(node_type) do
    {node, ward, num_nodes} = get_node_and_ward(node_type)
    get_heartbeat_config(node, ward, num_nodes)
  end

  @spec get_node_and_ward(binary()) :: tuple()
  def get_node_and_ward(node_type) do
    [node_type, _metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
        case node_type do
      "gcs" -> {-1,-1, 1}
      "all" -> {0,0, 1}
      "sim" -> {0,0, 1}
      "server" -> {0,0,1}

      "left-side" -> {0,1,2}
      "right-side" -> {1,0,2}

      "steering" -> {0,1,2}
      "throttle" -> {1,0,2}
    end
  end

  @spec get_heartbeat_config(integer(), integer(), integer()) :: list()
  def get_heartbeat_config(node, ward, num_nodes) do
    [
      heartbeat_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      heartbeat_node_sorter_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      node: node,
      ward: ward,
      num_nodes: num_nodes
    ]
  end

  @spec get_network_config() :: list()
  def get_network_config() do
    {interface, vintage_net_config} = get_interface_and_config()
    [
      interface: interface,
      vintage_net_config: vintage_net_config,
      broadcast_ip_loop_interval_ms: 1000,
      cookie: get_cookie(),
      src_port: 8780,
      dest_port: 8780
    ]
  end

  @spec get_cookie() :: atom()
  def get_cookie() do
    :guestoftheday
  end

  @spec get_interface_type() :: binary()
  def get_interface_type() do
      case Common.Utils.File.get_filenames_with_extension(".network") do
        [interface_type] -> interface_type
        _other -> nil
      end
  end

  @spec get_interface_and_config() :: tuple()
  def get_interface_and_config() do
    computer_name = :inet.gethostname() |> elem(1) |> to_string()

    case get_interface_type() do
      "wired" ->
        interface =
        cond do
          String.contains?(computer_name, "system76") -> "eno1"
          String.contains?(computer_name, "macmini") -> "enp1s0f0"
          true -> "eth0"
        end
        {interface, get_wired_config()}
      "wireless" ->
        interface =
          cond do
          String.contains?(computer_name, "system76") -> "wlp0s20f3"
          String.contains?(computer_name, "nerves") -> "wlan0"
          String.contains?(computer_name, "pi") -> "wlan0"
          true -> raise "Unknown Computer Type: #{computer_name}"
        end
        {interface, get_wireless_config()}
      _none -> {nil, nil}
    end
  end

  @spec get_wireless_config() :: map()
  def get_wireless_config do
     %{type: VintageNetWiFi,
       vintage_net_wifi: %{
         networks: [
           %{
             key_mgmt: :wpa_psk,
             ssid: "vcs_air",
             psk: "nervesofsteel",
           }
         ]
       },
       ipv4: %{method: :dhcp}}
  end

  @spec get_wired_config() :: map()
  def get_wired_config() do
    %{
      type: VintageNetEthernet,
      ipv4: %{
        method: :dhcp
      }
    }
  end

  @spec get_sorter_configs(binary()) :: list()
  def get_sorter_configs(_model_type) do
    [
      [
      name: {:hb, :node},
      default_message_behavior: :default_value,
      default_value: nil,
      value_type: :tuple,
      publish_messages_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow)
      ]
    ]
  end
end
