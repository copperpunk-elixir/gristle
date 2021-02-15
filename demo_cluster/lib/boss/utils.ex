defmodule Boss.Utils do
  require Logger

  @spec get_config(atom(), binary()) :: map()
  def get_config(module, node_type) do
    module_atom = Module.concat(Configuration, module)
    # Logger.debug("module atom: #{module_atom}")
    apply(module_atom, :get_config, [node_type])
  end

  @spec get_remaining_modules() :: list()
  def get_remaining_modules() do
    [Uart]
  end


  def common_prepare() do
    Cluster.Network.Utils.set_host_name()
    Process.sleep(200)
    node_type = Common.Utils.Configuration.get_node_type()
    attach_ringlogger(node_type)
    define_atoms()
    Process.sleep(100)
    # Comms.System.start_link()
    # Process.sleep(1000)
    node_type
  end

  @spec attach_ringlogger(atom()) :: atom()
  def attach_ringlogger(node_type) do
    [node_type, _metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    case Mix.target() do
      :host -> nil
      _other -> RingLogger.attach()
    end
  end

  @spec define_atoms() :: atom()
  def define_atoms() do
    atoms_as_strings = [
      "Remote",
    ]
    Enum.each(atoms_as_strings, fn x ->
      String.to_atom(x)
    end)
  end
end
