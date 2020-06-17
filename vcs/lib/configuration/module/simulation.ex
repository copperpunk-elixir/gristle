defmodule Configuration.Module.Simulation do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    %{
      receive: get_simulation_xplane_receive_config(),
      send: get_simulation_xplane_send_config(vehicle_type)
    }
  end

  @spec get_simulation_xplane_receive_config() :: map()
  def get_simulation_xplane_receive_config() do
    %{
      port: 49002
    }
  end

  @spec get_simulation_xplane_send_config(atom()) :: map()
  def get_simulation_xplane_send_config(vehicle_type) do
    %{
      vehicle_type: vehicle_type,
      port: 49003
    }
  end
end
