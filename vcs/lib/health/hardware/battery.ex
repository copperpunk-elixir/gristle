defmodule Health.Hardware.Battery do
  require Bitwise
  require Logger

  defstruct [voltage_V: nil, current_A: nil, energy_discharged_As: nil]

  def new() do
    %Health.Hardware.Battery{}
  end

  @spec update_voltage(struct(), float()) :: struct()
  def update_voltage(battery, voltage) do
    %{battery | voltage_V: voltage}
  end

  @spec update_current(struct(), float(), float()) :: struct()
  def update_current(battery, current, dt) do
    dE = current*dt
    energy_discharged = if is_nil(battery.energy_discharged_As), do: dE, else: battery.energy_discharged + dE
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
        :energy_discharged -> battery.energy_discharged_As/3600
        _other -> nil
      end
    end
  end

end
