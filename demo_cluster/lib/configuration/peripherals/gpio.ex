defmodule Configuration.Peripherals.Gpio do
  require Peripherals.Gpio.Utils, as: PGU
  @spec get_config(binary()) :: list()
  def get_config(node_type) do
    {node, _ward, num_nodes} = Configuration.Cluster.get_node_and_ward(node_type)
    guardian = Configuration.Cluster.get_guardian_for_node(node, num_nodes)
    [
      node: node,
      guardian: guardian,
      mux_status_sorter_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      mux_status_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      pins: %{
        PGU.node_led_pin => [
        direction: :output
      ],
        PGU.guardian_led_pin => [
          direction: :output
        ],
        PGU.mux_status_pin => [
          direction: :input,
          pull_mode: :pullup,
          interrupts: :both
        ]
      }
    ]
  end
end
