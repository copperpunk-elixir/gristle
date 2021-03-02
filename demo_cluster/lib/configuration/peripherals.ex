defmodule Configuration.Peripherals do
  @spec get_config(binary()) :: list()
  def get_config(node_type) do
    [
      uart: Configuration.Peripherals.Uart.get_config(node_type),
      gpio: Configuration.Peripherals.Gpio.get_config(node_type),
    ]
  end

  def get_sorter_configs() do
    [
      [
        name: :servo_output,
        default_message_behavior: :default_value,
        default_value: %{0 => 4, 1 => 4, 2 => 4, 3 => 4},
        value_type: :map,
        publish_value_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
      ],
      [
        name: :mux_status,
        default_message_behavior: :default_value,
        default_value: -1,
        value_type: :number,
        publish_messages_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow)
      ]
    ]
  end
end
