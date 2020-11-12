defmodule Configuration.Module.Watchdog do
  @spec get_local(atom(), integer()) :: list()
  def get_local(name, expected_interval_ms) do
    get_config(name, expected_interval_ms, :local)
  end

  @spec get_global(atom(), integer()) :: list()
  def get_global(name, expected_interval_ms) do
    get_config(name, expected_interval_ms, :global)
  end

 @spec get_config(atom(), integer(), atom()) :: list()
  def get_config(name, expected_interval_ms, local_or_global) do
    [
      name: name,
      expected_interval_ms: expected_interval_ms,
      local_or_global: local_or_global
    ]
  end
end
