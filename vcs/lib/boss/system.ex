defmodule Boss.System do
  use DynamicSupervisor
  require Logger

  def start_link() do
    Logger.info("Start Boss Supervisor")
    Common.Utils.start_link_redundant(DynamicSupervisor, __MODULE__, nil, __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_) do
    Logger.info("boss system init")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec common_start() :: atom()
  def common_start() do
    common_prepare()
    Common.Utils.File.mount_usb_drive()
    Cluster.Network.Utils.set_host_name()
    Process.sleep(200)
    node_type = Common.Utils.Configuration.get_node_type()
    model_type = Common.Utils.Configuration.get_model_type()
    attach_ringlogger(node_type)
    Logger.debug("Start Application")
    start_link()
    Process.sleep(200)
    start_module(MessageSorter, model_type, node_type)
    Process.sleep(500)
    generic_modules = [Cluster, Logging, Time]
    Boss.System.start_modules(generic_modules, model_type, node_type)
  end

  @spec start_module(atom(), binary(), binary()) :: atom()
  def start_module(module, model_type, node_type) do
    Logger.debug("Boss Starting Module: #{module}")
    config = get_config(module, model_type, node_type)
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: Module.concat(module, Supervisor),
        start: {
          Module.concat(module, System),
          :start_link,
          [config]
        }
      }
    )
  end

  @spec start_modules(list(), binary(), binary()) :: atom()
  def start_modules(modules, model_type, node_type) do
    Enum.each(modules, fn module ->
      start_module(module, model_type, node_type)
    end)
  end

  @spec get_config(atom(), binary(), binary()) :: map()
  def get_config(module, model_type, node_type) do
    module_atom = Module.concat(Configuration.Module, module)
    Logger.debug("module atom: #{module_atom}")
    apply(module_atom, :get_config, [model_type, node_type])
  end

  @spec start_node_processes() :: atom()
  def start_node_processes() do
    # vehicle_type = Common.Utils.Configuration.get_vehicle_type()
    model_type = Common.Utils.Configuration.get_model_type()
    node_type = Common.Utils.Configuration.get_node_type()

    Logger.debug("Start remaining processes for #{model_type}/#{node_type}")
    modules = get_modules_for_node(node_type)
    start_modules(modules, model_type, node_type)
    # Configuration.Module.start_modules(modules, model_type, node_type)
  end

  @spec get_modules_for_node(binary()) :: list()
  def get_modules_for_node(node_type) do
    case node_type do
      "gcs" ->[Display.Scenic, Peripherals.Uart]
      "sim" ->[
        Actuation,
        Pids,
        Control,
        Estimation,
        Navigation,
        Command,
        Simulation,
        Peripherals.Uart,
        Display.Scenic
      ]
      "server" -> [Simulation, Peripherals.Uart, Display.Scenic]
      "all" -> [Actuation, Pids, Control, Estimation, Health, Navigation, Command, Peripherals.Uart, Peripherals.Gpio, Peripherals.I2c,Peripherals.Leds]
      _vehicle -> [Actuation, Pids, Control, Estimation, Health, Navigation, Command, Peripherals.Uart, Peripherals.Gpio, Peripherals.I2c, Peripherals.Leds]
    end
  end

  @spec attach_ringlogger(atom()) :: atom()
  def attach_ringlogger(node_type) do
    case node_type do
      "gcs" -> nil
      "sim" -> nil
      _other -> RingLogger.attach()
    end
  end

  def common_prepare() do
    define_atoms()
    Process.sleep(100)
    Comms.System.start_link()
    Process.sleep(1000)
  end

  @spec define_atoms() :: atom()
  def define_atoms() do
    atoms_as_strings = [
      "Plane",
      "Cessna",
      "CessnaZ2m",
      "T28",
      "T28Z2m",
      "Ina260",
      "Ina219",
      "Sixfab",
      "Atto90"
    ]
    Enum.each(atoms_as_strings, fn x ->
      String.to_atom(x)
    end)
  end
end
