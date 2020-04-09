defmodule TestConfigs.Control do
  def get_config_with_pvs(process_variables) do
    process_variables = Common.Utils.assert_list(process_variables)
    %{
      pv_cmd_loop_interval_ms: 20,
      process_variables: process_variables
    }
  end
end
