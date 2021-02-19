defmodule Configuration.Sweep do
  def get_config(_node_type) do
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
      }
    ]
  end
end
