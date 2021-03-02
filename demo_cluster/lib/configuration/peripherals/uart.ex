defmodule Configuration.Peripherals.Uart do

  def get_config(node_type) do
    [_node_type, metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    metadata = if is_nil(metadata), do: :rand.uniform(10000), else: String.to_integer(metadata)
    {servo_output_classification, servo_output_time_validity_ms} = Configuration.MessageSorter.get_message_sorter_classification_time_validity_ms(Peripherals.Uart.Operator, :servo_output, metadata)


    uart_port =
      case node_type do
        "sim" -> "Feather M0"
        _other -> "ttyAMA0"
      end
    [
      uart_port: uart_port,
      port_options: [speed: 115_200],
      servo_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      servo_output_sorter_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      servo_output_classification: servo_output_classification,
      servo_output_time_validity_ms: servo_output_time_validity_ms

    ]
  end
end
