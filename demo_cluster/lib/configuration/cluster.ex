defmodule Configuration.Cluster do
  require Logger

  @spec get_config(binary()) :: list()
  def get_config(node_type) do
    [
      heartbeat: get_heartbeat_config(node_type),
      network: get_network_config(),
      led: get_led_config()
    ]
  end

  @spec get_heartbeat_config(binary()) :: list()
  def get_heartbeat_config(node_type) do
    {node, ward, num_nodes} = get_node_and_ward(node_type)
    get_heartbeat_config(node, ward, num_nodes)
  end

  @spec get_node_and_ward(binary()) :: tuple()
  def get_node_and_ward(node_type) do
    [node_type, metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    case node_type do
      "all" -> {1,1,1}
      "sim" -> {1,1,1}
      "remote" ->
        num_nodes = 4
        node = String.to_integer(metadata)
        ward = if (node < num_nodes), do: node + 1, else: 1
        {node, ward, num_nodes}
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

  @spec get_interface_and_config() :: tuple()
  def get_interface_and_config() do

    computer_name = :inet.gethostname() |> elem(1) |> to_string()

    if String.contains?(computer_name, "system76") do
      {"eno1", get_wired_config()}
    else
      interface =
        cond do
        String.contains?(computer_name, "system76") -> "wlp0s20f3"
        String.contains?(computer_name, "nerves") -> "wlan0"
        String.contains?(computer_name, "pi") -> "wlan0"
        true -> raise "Unknown Computer Type: #{computer_name}"
      end
      {interface, get_wireless_config()}
    end
  end

  @spec get_wireless_config() :: map()
  def get_wireless_config do
     %{type: VintageNetWiFi,
       vintage_net_wifi: %{
         networks: [
           %{
             key_mgmt: :wpa_psk,
             ssid: "dialup",
             psk: "binghamplace",
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

  @spec get_led_config() :: list()
  def get_led_config do
    [
      led_loop_interval_ms: 1000
    ]
  end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
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
