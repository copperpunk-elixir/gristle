defmodule Boss.Utils do
  require Logger

  @spec get_config(atom(), binary(), binary()) :: map()
  def get_config(module, model_type, node_type) do
    module_atom = Module.concat(Configuration.Module, module)
    # Logger.debug("module atom: #{module_atom}")
    apply(module_atom, :get_config, [model_type, node_type])
  end

  @spec get_modules_for_node(binary()) :: list()
  def get_modules_for_node(node_type) do
    [node_type, _metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    case node_type do
      "gcs" ->[Display.Scenic, Peripherals.Uart, Gcs]
      "sim" ->[
        Actuation,
        Pids,
        Control,
        Estimation,
        Navigation,
        Command,
        Simulation,
        Peripherals.Uart,
        Display.Scenic,
        Gcs
      ]
      "server" -> [Simulation, Peripherals.Uart, Display.Scenic]
      "all" -> [Actuation, Pids, Control, Estimation, Health, Navigation, Command, Peripherals.Uart, Peripherals.Gpio, Peripherals.I2c,Peripherals.Leds]
      _vehicle -> [Actuation, Pids, Control, Estimation, Health, Navigation, Command, Peripherals.Uart, Peripherals.Gpio, Peripherals.I2c, Peripherals.Leds]
    end
  end

  def common_prepare() do
    Common.Utils.File.mount_usb_drive()
    Cluster.Network.Utils.set_host_name()
    Process.sleep(200)
    node_type = Common.Utils.Configuration.get_node_type()
    model_type = Common.Utils.Configuration.get_model_type()
    attach_ringlogger(node_type)
    define_atoms()
    Process.sleep(100)
    Comms.System.start_link()
    Process.sleep(1000)
    {model_type, node_type}
  end

  @spec attach_ringlogger(atom()) :: atom()
  def attach_ringlogger(node_type) do
    [node_type, _metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    case node_type do
      "gcs" -> nil
      "sim" -> nil
      "server" -> nil
      _other -> RingLogger.attach()
    end
  end

  @spec define_atoms() :: atom()
  def define_atoms() do
    atoms_as_strings = [
      "Plane",
      "Multirotor",
      "Car",
      "Cessna",
      "CessnaZ2m",
      "T28",
      "T28Z2m",
      "QuadX",
      "FerrariF1",
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
