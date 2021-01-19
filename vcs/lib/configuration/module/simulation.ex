defmodule Configuration.Module.Simulation do
  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, node_type) do
    [
      receive: get_simulation_xplane_receive_config(),
      send: get_simulation_xplane_send_config(model_type),
      realflight: get_realflight_config(model_type, node_type)
    ]
  end

  @spec get_simulation_xplane_receive_config() :: list()
  def get_simulation_xplane_receive_config() do
    [
      port: 49002
    ]
  end

  @spec get_simulation_xplane_send_config(binary()) :: list()
  def get_simulation_xplane_send_config(model_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    sim_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    |> Module.concat(Simulation)
    pwm_channels = apply(sim_module, :get_pwm_channels, [model_type])

    actuation_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    |> Module.concat(Actuation)
    reversed_channels = apply(actuation_module, :get_reversed_actuators, [model_type])
    [
      dest_ip: {127,0,0,1},
      source_port: 49003,
      dest_port: 49000,
      pwm_channels: pwm_channels,
      reversed_channels: reversed_channels
    ]
  end

  @spec get_realflight_config(binary(), binary()) :: list()
  def get_realflight_config(model_type, node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    sim_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    |> Module.concat(Simulation)
    pwm_channels = apply(sim_module, :get_pwm_channels, [model_type])

    actuation_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    |> Module.concat(Actuation)
    reversed_channels = apply(actuation_module, :get_reversed_actuators, [model_type])

    [
      host_ip: "192.168.7.136",
      sim_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:super_fast),
      pwm_channels: pwm_channels,
      reversed_channels: reversed_channels,
      update_actuators_software: false#(node_type == "sim")
    ]
  end
end
