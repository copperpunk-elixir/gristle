defmodule Configuration.Module.Peripherals.Leds do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_model_type, node_type) do
    %{
      Status: %{led: "led0"}
    }
  end
end
