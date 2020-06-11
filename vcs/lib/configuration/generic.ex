defmodule Configuration.Generic do
  require Logger

  @spec get_loop_interval_ms(atom()) :: integer()
  def get_loop_interval_ms(loop_type) do
    case loop_type do
      :fast -> 50
      :medium -> 100
      :slow -> 200
    end
  end

  @spec get_estimator_config() :: map()
  def get_estimator_config() do
    %{estimator: %{
         imu_loop_interval_ms: get_loop_interval_ms(:fast),
         imu_loop_timeout_ms: 1000,
         ins_loop_interval_ms: get_loop_interval_ms(:fast),
         ins_loop_timeout_ms: 2000,
         telemetry_loop_interval_ms: get_loop_interval_ms(:slow),
      }}
  end

  @spec get_cluster_config() :: map()
  def get_cluster_config() do
    %{
      heartbeat: get_heartbeat_config(),
      network: get_network_config()
    }
  end

  @spec get_heartbeat_config() :: map()
  def get_heartbeat_config do
    node_type = Common.Utils.get_node_type()
    {node, ward} = Configuration.Vehicle.get_node_and_ward(node_type)
    get_heartbeat_config(node, ward)
  end

  @spec get_heartbeat_config(integer(), integer()) :: map()
  def get_heartbeat_config(node, ward) do
    %{
      heartbeat_loop_interval_ms: get_loop_interval_ms(:medium),
      node: node,
      ward: ward
    }
  end

  @spec get_network_config() :: map()
  def get_network_config() do
    {:ok, computer_name} = :inet.gethostname()
    computer_name = to_string(computer_name)

    {interface, embedded} =
      cond do
      String.contains?(computer_name, "system76") -> {"wlp0s20f3", false}
      String.contains?(computer_name, "nerves") -> {"wlan0", true}
      String.contains?(computer_name, "pi") -> {"wlan0", true}
      true -> raise "Unknown Computer Type: #{computer_name}"
    end

    %{
      is_embedded: embedded,
      interface: interface,
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

  @spec get_operator_config(atom()) :: map()
  def get_operator_config(name) do
    %{
      name: name,
      refresh_groups_loop_interval_ms: 100
    }
  end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    [
      %{
        name: {:hb, :node},
        default_message_behavior: :default_value,
        default_value: :nil,
        value_type: :map
      },
      %{
        name: :estimator_health,
        default_message_behavior: :default_value,
        default_value: 0,
        value_type: :number
      },

    ]
  end

  @spec get_display_config(atom()) :: map()
  def get_display_config(vehicle_type) do
    display_vehicle_type =
      case vehicle_type do
        :Car -> :Car
        :FourWheelRobot -> :Car
        :Plane -> :Plane
      end
    %{vehicle_type: display_vehicle_type}
  end

  @spec get_message_sorter_classification_time_validity_ms(atom(), any()) :: tuple()
  def get_message_sorter_classification_time_validity_ms(sender, sorter) do
    Logger.warn("sender: #{inspect(sender)}")
    classification_all = %{
      :actuator_cmds => %{
        Pids.Moderator => [0,1],
        Navigation.Navigator => [0,2]
      },
      :pv_cmds => %{
        Pids.Moderator => [0,1],
        Navigation.Navigator => [0,2]
      },
      :rx_output => %{
        Command.Commander => [0,1]
      },
      :control_state => %{
        Navigation.Navigator => [0,1]
      }
    }

    time_validity_all = %{
      {:hb, :node} => 500,
      :actuator_cmds => 200,
      :pv_cmds => 300,
      :rx_output => 300,
      :control_state => 200
    }

    classification =
      Map.get(classification_all, sorter, %{})
      |> Map.get(sender, nil)
    time_validity = Map.get(time_validity_all, sorter, 0)
    Logger.warn("class/time: #{inspect(classification)}/#{time_validity}")
    {classification, time_validity}
  end

 end
