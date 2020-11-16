defmodule Health.Hardware.Battery do
  use Bitwise
  require Logger

  @enforce_keys [:type, :channel]
  defstruct [type: nil, channel: nil, voltage_V: nil, current_A: nil, energy_discharged_As: nil]

  @spec new(atom(), integer()) :: struct()
  def new(type, channel) do
    %Health.Hardware.Battery{type: type, channel: channel}
  end

  @spec update_voltage(struct(), float()) :: struct()
  def update_voltage(battery, voltage) do
    %{battery | voltage_V: voltage}
  end

  @spec update_current(struct(), float(), float()) :: struct()
  def update_current(battery, current, dt) do
    dE = current*dt
    energy_discharged = if is_nil(battery.energy_discharged_As), do: dE, else: max(0,battery.energy_discharged_As + dE)
    # Logger.debug("I/dt/dE/E: #{Common.Utils.eftb(current,2)}/#{Common.Utils.eftb(dt,3)}/#{Common.Utils.eftb(dE,3)}/#{Common.Utils.eftb(energy_discharged, 0)}")
    %{battery | current_A: current, energy_discharged_As: energy_discharged}
  end

  @spec get_value(struct(), atom()) :: float()
  def get_value(battery, key) do
    if is_nil(battery) do
      nil
    else
      case key do
        :voltage -> battery.voltage_V
        :current -> battery.current_A
        :energy_discharged ->
          if is_nil(battery.energy_discharged_As), do: nil, else: battery.energy_discharged_As/3.6
        _other -> nil
      end
    end
  end

  # Voltage/Current/Energy
  @spec get_vie(struct()) :: list()
  def get_vie(battery) do
    [get_value(battery, :voltage), get_value(battery, :current), get_value(battery, :energy_discharged)]
  end

  @spec get_battery_id(struct()) :: list()
  def get_battery_id(battery) do
    type_int = battery_type_enum(battery.type)
    <<x>> = <<type_int::3, battery.channel::5>>
    x
  end

  @spec get_type_channel_for_id(integer()) :: tuple()
  def get_type_channel_for_id(id) do
    type = id >>> 5 |> battery_type_enum()
    channel = id &&& 0x1F
    {type, channel}
  end

  @spec battery_type_enum(atom()) :: integer()
  def battery_type_enum(type) do
    Common.Utils.get_key_or_value(battery_type_structure(), type)
  end

  @spec battery_type_structure() :: list()
  def battery_type_structure() do
    %{
      "cluster" => 0,
      "motor" => 1
    }
  end

end
