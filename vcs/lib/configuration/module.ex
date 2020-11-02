defmodule Configuration.Module do
  require Logger

  @spec get_config(atom(), atom(), atom()) :: map()
  def get_config(module, model_type, node_type) do
    module_atom = Module.concat(__MODULE__, module)
    Logger.debug("module atom: #{module_atom}")
    apply(module_atom, :get_config, [model_type, node_type])
  end

  @spec start_modules(list(), atom(), atom()) :: atom()
  def start_modules(modules, model_type, node_type) do
    Enum.each(modules, fn module ->
      system_module = Module.concat(module, System)
      Logger.debug("system module: #{system_module}")
      case apply(system_module, :start_link, [get_config(module, model_type, node_type)]) do
        {:ok, pid} -> Logger.debug("#{system_module} successfully started")
        other -> Logger.warn("#{system_module} did not start successfully: #{inspect(other)}")
      end
    end)
  end
end
