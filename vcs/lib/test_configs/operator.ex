defmodule TestConfigs.Operator do
  def get_config_with_groups(groups) do
    groups = Common.Utils.assert_list(groups)
    %{
      refresh_groups_loop_interval_ms: 100,
      groups: groups
    }
  end
end
