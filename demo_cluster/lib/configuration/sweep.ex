defmodule Configuration.Sweep do
  def get_config(node_type) do
    {node, _, _} = Configuration.Cluster.get_node_and_ward(node_type)
    {servo_output_classification, servo_output_time_validity_ms} = Configuration.MessageSorter.get_message_sorter_classification_time_validity_ms(Sweep.Operator, :servo_output, node)

    [
      # min_values: [0, 0, 0, 0],
      # max_values: [8, 4, 4, 8],
      # values: [0, 0, 4, 8],
      # directions: [1, 1, -1 -1],

      sweep_loop_interval_ms: 500,
      servos: %{
        0 => Sweep.Servo.new(0, 8, 1, 0),
        1 => Sweep.Servo.new(0, 4, 1, 0),
        2 => Sweep.Servo.new(4, 8, -1, 8),
        3 => Sweep.Servo.new(0, 8, -1, 8)
      },
      servo_output_classification: servo_output_classification,
      servo_output_time_validity_ms: servo_output_time_validity_ms
    ]
  end
end
