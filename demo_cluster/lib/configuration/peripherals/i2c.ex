defmodule Configuration.Peripherals.I2c do
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
        self: 0x0A,
        mux: 0x09,
        control: 0x08
      }
    ]
  end
end
