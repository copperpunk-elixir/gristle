defmodule TestConfigs.Operator do
  def get_config() do
    %{
      name: :super_important_process,
      refresh_groups_loop_interval_ms: 100,
    }
  end
end
