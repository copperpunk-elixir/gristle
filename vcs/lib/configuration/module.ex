defmodule Configuration.Module do
  require Logger

  @spec get_config(atom(), atom(), atom()) :: map()
  def get_config(module, model_type, node_type) do
    module_atom = Module.concat(__MODULE__, module)
    Logger.info("module atom: #{module_atom}")
    apply(module_atom, :get_config, [model_type, node_type])
  end

  @spec start_modules(list(), atom(), atom()) :: atom()
  def start_modules(modules, model_type, node_type) do
    Enum.each(modules, fn module ->
      system_module = Module.concat(module, System)
      Logger.info("system module: #{system_module}")
      apply(system_module, :start_link, [get_config(module, model_type, node_type)])
    end)
  end
end
