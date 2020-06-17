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
    %{
      interface: get_interface(),
      broadcast_ip_loop_interval_ms: 1000,
      cookie: get_cookie(),
      src_port: 8780,
      dest_port: 8780
    }
  end

  @spec get_interface() :: binary()
  def get_interface() do
    {:ok, computer_name} = :inet.gethostname()
    computer_name = to_string(computer_name)

    cond do
      String.contains?(computer_name, "system76") -> "wlp0s20f3"
      String.contains?(computer_name, "nerves") -> "wlan0"
      String.contains?(computer_name, "pi") -> "wlan0"
      true -> raise "Unknown Computer Type: #{computer_name}"
    end
  end

  @spec get_cookie() :: atom()
  def get_cookie() do
    :guestoftheday
  end
end
