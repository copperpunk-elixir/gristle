defmodule Configuration.Uart do
  def get_config(node_type) do
    uart_port =
      case node_type do
        "sim" -> "Feather M0"
        _other -> "ttyAMA0"
      end
    [
      uart_port: uart_port,
      port_options: [speed: 115_200],
      servo_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      servo_output_sorter_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
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
      ]
    ]

  end
end
