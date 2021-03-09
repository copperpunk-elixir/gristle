defmodule Configuration.Peripherals.I2c do
  require Peripherals.I2c.Utils, as: PIU

  @spec get_config(binary()) :: list()
  def get_config(node_type) do
    {node, _ward, num_nodes} = Configuration.Cluster.get_node_and_ward(node_type)
    guardian = Configuration.Cluster.get_guardian_for_node(node, num_nodes)
    [
      node: node,
      guardian: guardian,
      mux_status_sorter_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      servo_output_sorter_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      mux_status_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      leds: %{
        self: PIU.self_led_address,
        servo_output: PIU.servo_output_led_address,
        mux: PIU.mux_led_address
      }
    ]
  end
end
