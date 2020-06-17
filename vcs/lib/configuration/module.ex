defmodule Configuration.Module do
  require Logger

  @spec get_config(atom(), atom(), atom()) :: map()
  def get_config(module, vehicle_type, node_type) do
    module_atom = Module.concat(__MODULE__, module)
    Logger.info("module atom: #{module_atom}")
    apply(module_atom, :get_config, [vehicle_type, node_type])
  end
end
