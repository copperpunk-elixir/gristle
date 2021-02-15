defmodule Configuration.Uart do
  def get_config(_node_type) do
    [
      # uart_port: "Feather M0",
      uart_port: "USB Serial",
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
        default_value: 100,
        value_type: :number,
        publish_value_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
      ]
    ]

  end
end
