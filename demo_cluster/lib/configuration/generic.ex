defmodule Configuration.Generic do
  require Logger

  @spec get_loop_interval_ms(atom()) :: integer()
  def get_loop_interval_ms(loop_type) do
    case loop_type do
      :super_fast -> 10
      :fast -> 20
      :medium -> 40
      :slow -> 200
      :extra_slow -> 1000
    end
  end
end
