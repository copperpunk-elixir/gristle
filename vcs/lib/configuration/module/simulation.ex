defmodule Configuration.Module.Simulation do
  @spec get_config(atom(), atom()) :: map()
  def get_config(model_type, _node_type) do
    %{
      receive: get_simulation_xplane_receive_config(),
      send: get_simulation_xplane_send_config(model_type)
    }
  end

  @spec get_simulation_xplane_receive_config() :: map()
  def get_simulation_xplane_receive_config() do
    %{
      port: 49002
    }
  end

  @spec get_simulation_xplane_send_config(atom()) :: map()
  def get_simulation_xplane_send_config(model_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    sim_module = Module.concat(Configuration.Vehicle, vehicle_type)
    |> Module.concat(Simulation)
    pwm_channels = apply(sim_module, :get_pwm_channels, [model_type])

    actuation_module = Module.concat(Configuration.Vehicle, vehicle_type)
    |> Module.concat(Actuation)
    reversed_channels = apply(actuation_module, :get_reversed_actuators, [model_type])
    %{
      vehicle_type: vehicle_type,
      source_port: 49003,
      dest_port: 49000,
      pwm_channels: pwm_channels,
      reversed_channels: reversed_channels
    }
  end

end
