defmodule Configuration.Module.Peripherals.I2c do
  require Logger
  @spec get_config(atom(), atom()) :: list()
  def get_config(_model_type, node_type) do
    peripherals = Common.Utils.Configuration.get_i2c_peripherals(node_type)
    Logger.debug("peripherals: #{inspect(peripherals)}")
    Enum.reduce(peripherals, [], fn (peripheral, acc) ->
      Logger.debug("peripheral: #{inspect(peripheral)}")
      device_and_metadata = String.split(peripheral, "_")
      device = Enum.at(device_and_metadata,0)
      metadata = Enum.at(device_and_metadata,1)
      {module_key, module_config} =
        case device do
          "Ina260" ->
            {module, type, channel} = get_battery_module_type_channel(device, metadata)
            {Health.Battery, get_battery_config(module, type, channel)}
          "Ina219" ->
            {module, type, channel} = get_battery_module_type_channel(device, metadata)
            {Health.Battery, get_battery_config(module, type, channel)}
          "Sixfab" ->
            {module, type, channel} = get_battery_module_type_channel(device, metadata)
            {Health.Battery, get_battery_config(module, type, channel)}
          "Atto90" ->
            {module, type, channel} = get_battery_module_type_channel(device, metadata)
            {Health.Battery, get_battery_config(module, type, channel)}

        end
      acc ++ Keyword.put([], module_key, module_config)
    end)
  end

  @spec get_battery_module_type_channel(binary(), binary()) :: tuple()
  def get_battery_module_type_channel(device, metadata) do
    module = String.to_existing_atom(device)
    [type, channel] = String.split(metadata,"-")
    channel = String.to_integer(channel)
    {module, type, channel}
  end

  @spec get_battery_config(binary(), binary(), integer()) :: list()
  def get_battery_config(module, battery_type, battery_channel) do
    read_battery_interval_ms =
      case battery_type do
        "cluster" -> 1000
        "motor" -> 1000
      end
    [
      module: module,
      battery_type: battery_type,
      battery_channel: battery_channel,
      read_battery_interval_ms: read_battery_interval_ms
    ]
  end

  @spec get_ina260_config(binary(), integer()) :: map()
  def get_ina260_config(battery_type, channel) do
    %{
      battery_type: battery_type,
      battery_channel: channel,
      read_voltage_interval_ms: 1000,
      read_current_interval_ms: 1000
    }
  end

  @spec get_ina219_config(atom(), integer()) :: map()
  def get_ina219_config(battery_type, channel) do
    %{
      battery_type: battery_type,
      battery_channel: channel,
      read_voltage_interval_ms: 1000,
      read_current_interval_ms: 1000
    }
  end

  @spec get_sixfab_config(atom(), integer()) :: map()
  def get_sixfab_config(battery_type, channel) do
    %{
      battery_type: battery_type,
      battery_channel: channel,
      read_voltage_interval_ms: 1000,
      read_current_interval_ms: 1000
    }
  end

  @spec get_ads1015_config(atom(), integer(), integer()) :: map()
  def get_ads1015_config(battery_type, channel, version) do
    {voltage_mult, current_mult} =
      case version do
        180 -> {1.0/63.69, 1.0/18.3}
        90 -> {1.0/63.69, 1.0/36.6}
        45 -> {1.0/242.3, 1.0/73.2}
        _other -> raise "Incorrect Voltage/Current measurement settings for Ads1015"
      end
    Logger.debug("Ads1015 version: #{version}")
    Logger.debug("V/I mults: #{voltage_mult}/#{current_mult}")
    %{
      battery_type: battery_type,
      battery_channel: channel,
      read_battery_interval_ms: 1000,
      voltage_mult: voltage_mult,
      current_mult: current_mult
    }
  end

end
