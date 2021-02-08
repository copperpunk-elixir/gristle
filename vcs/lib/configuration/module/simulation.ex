defmodule Configuration.Module.Simulation do
  require Logger

  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, node_type) do
    [_, sim_host] = String.split(node_type, "_")
    modules = get_modules(model_type, node_type, sim_host)
    [
      # receive: get_simulation_xplane_receive_config(),
      # send: get_simulation_xplane_send_config(model_type),
      # realflight: get_realflight_config(model_type, node_type),
      # static: get_static_config(model_type, node_type)
      children: get_children(modules, model_type, node_type)
    ]
  end

  @spec get_modules(binary(), binary(), binary()) :: list()
  def get_modules(model_type, node_type, sim_host) do
    # Logger.info("get modules for sim host: #{sim_host}")
    case sim_host do
      "static" -> [Simulation.Static]
      "realflight" -> [Simulation.Realflight]
      "xplane" -> [Simulation.XplaneReceive, Simulation.XplaneSend]
    end
  end

  @spec get_children(list(), binary(), binary()) :: list()
  def get_children(modules, model_type, node_type) do
    # Logger.debug("modules: #{inspect(modules)}")
    Enum.reduce(modules, [], fn (module, acc) ->
      config =
        case module do
          Simulation.Static -> {module,  get_static_config(model_type, node_type)}
          Simulation.Realflight -> {module, get_realflight_config(model_type, node_type)}
          Simulation.XplaneReceive -> {module, get_simulation_xplane_receive_config()}
          Simulation.XplaneSend -> {module, get_simulation_xplane_send_config(model_type)}
        end
      [config] ++ acc
    end)
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
  def get_realflight_config(model_type, _node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    sim_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    |> Module.concat(Simulation)
    pwm_channels = apply(sim_module, :get_pwm_channels, [model_type])

    actuation_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    |> Module.concat(Actuation)
    reversed_channels = apply(actuation_module, :get_reversed_actuators, [model_type])

    [
      host_ip: "192.168.7.247",
      sim_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
      pwm_channels: pwm_channels,
      reversed_channels: reversed_channels,
      update_actuators_software: false#(node_type == "sim")
    ]
  end

  @spec get_static_config(binary(), binary()) :: list()
  def get_static_config(_model_type, _node_type) do
    [
      sim_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
    ]
  end
end
