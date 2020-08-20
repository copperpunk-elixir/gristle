defmodule Configuration.Module.Cluster do
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, _node_type) do
    %{
      heartbeat: get_heartbeat_config(),
      network: get_network_config()
    }
  end

  @spec get_heartbeat_config() :: map()
  def get_heartbeat_config do
    node_type = Common.Utils.get_node_type()
    {node, ward} = get_node_and_ward(node_type)
    get_heartbeat_config(node, ward)
  end

  @spec get_node_and_ward(atom()) :: tuple()
  def get_node_and_ward(node_type) do
    case node_type do
      :gcs -> {-1,-1}
      :all -> {0,0}
      :sim -> {0,0}
      :hil -> {0,0}

      :wing -> {0,1}
      :fuselage -> {1,2}
      :tail -> {2,0}

      :steering -> {0,1}
      :throttle -> {1,0}

      :front_right -> {0,1}
      :rear_right -> {1,2}
      :rear_left -> {2,3}
      :front_left -> {3,0}
    end
  end

  @spec get_heartbeat_config(integer(), integer()) :: map()
  def get_heartbeat_config(node, ward) do
    %{
      heartbeat_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      node: node,
      ward: ward
    }
  end

  @spec get_network_config() :: map()
  def get_network_config() do
    {interface, vintage_net_config} = get_interface_and_config()
    %{
      interface: interface,
      vintage_net_access: vintage_net_access?(),
      vintage_net_config: vintage_net_config,
      broadcast_ip_loop_interval_ms: 1000,
      cookie: get_cookie(),
      src_port: 8780,
      dest_port: 8780
    }
  end

  @spec get_cookie() :: atom()
  def get_cookie() do
    :guestoftheday
  end

  @spec vintage_net_access?() :: boolean()
  def vintage_net_access?() do
    if String.contains?(get_computer_name(), "system76"), do: false, else: true
  end

  @spec get_computer_name() :: binary()
  def get_computer_name do
    {:ok, computer_name} = :inet.gethostname()
    to_string(computer_name)
  end

  @spec get_interface_and_config() :: tuple()
  def get_interface_and_config() do
    [interface_type] = Common.Utils.get_filenames_with_extension(".network")
    computer_name = get_computer_name()
    case interface_type do
      "wired" ->
        interface =
        cond do
          String.contains?(computer_name, "system76") -> "eno1"
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
    %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}
  end
end
