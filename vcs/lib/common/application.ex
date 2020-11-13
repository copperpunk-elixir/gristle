defmodule Common.Application do
  use Application
  require Logger

  def start(_type, _args) do
    common_startup()
    {:ok, self()}
  end

  @spec common_startup() :: atom()
  def common_startup() do
    Common.Utils.common_startup()
    Common.Utils.File.mount_usb_drive()
    Cluster.Network.Utils.set_host_name()
    Process.sleep(200)
    node_type = Common.Utils.Configuration.get_node_type()
    model_type = Common.Utils.Configuration.get_model_type()
    attach_ringlogger(node_type)
    Logger.warn("model/node: #{model_type}/#{node_type}")
    Logger.debug("Start Application")
    Boss.System.start_link()
    Process.sleep(200)
    Boss.System.start_module(MessageSorter, model_type, node_type)
    Process.sleep(500)
    generic_modules = [Cluster, Logging, Time]
    Boss.System.start_modules(generic_modules, model_type, node_type)
  end

  @spec attach_ringlogger(atom()) :: atom()
  def attach_ringlogger(node_type) do
    case node_type do
      # "gcs" -> nil
      # "sim" -> nil
      _other -> RingLogger.attach()
    end
  end

end
