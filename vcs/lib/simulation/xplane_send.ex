defmodule Simulation.XplaneSend do
  require Logger
  use Bitwise
  use GenServer

  @cmd_header <<68, 65, 84, 65, 0>>
  @zeros_1 <<0,0,0,0>>
  @zeros_4 <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>
  @zeros_5 <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>
  @zeros_7 <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>

  def start_link(config) do
    Logger.debug("Start Simulation.XplaneSend")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        socket: nil,
        source_port: config.source_port,
        dest_port: config.dest_port,
        vehicle_type: config.vehicle_type,
        commands: %{}
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    {:ok, socket} = :gen_udp.open(state.source_port, [broadcast: false, active: false])
    {:noreply, %{state | socket: socket}}
  end

  @impl GenServer
  def handle_cast({:update_actuators, actuators_and_outputs}, state) do
    cmds = Enum.reduce(actuators_and_outputs, %{}, fn ({actuator_name, {_actuator,output}}, acc) ->
      case actuator_name do
        :throttle -> Map.put(acc, actuator_name, output)
        name -> Map.put(acc, name, 2*(output - 0.5))
      end
    end)
    case state.vehicle_type do
      :Plane ->
        send_ail_elev_rud_commands(cmds, state.socket, state.dest_port)
        send_throttle_command(cmds, state.socket, state.dest_port)
    end
    # Logger.debug("cmds: #{inspect(state.commands)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send, message_type, message}, state) do
    func = "send_" <> Atom.to_string(message_type)
    |> String.to_atom()
    Logger.warn("function: #{func}")
    Logger.warn("message: #{inspect(message)}")
    apply(__MODULE__, func, [message, state.socket, state.dest_port])
    {:noreply, state}
  end

  @spec update_actuators(map()) :: atom()
  def update_actuators(actuators_and_outputs) do
    GenServer.cast(__MODULE__, {:update_actuators, actuators_and_outputs})
  end

  @spec send_ail_elev_rud_commands(map(), any(), integer()) :: atom()
  def send_ail_elev_rud_commands(commands, socket, port) do
    buffer = @cmd_header <> <<11, 0, 0, 0>>
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Map.get(commands, :elevator,-999),32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Map.get(commands, :aileron,-999),32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Map.get(commands, :rudder,-999),32))
    |> Kernel.<>(@zeros_5)
    # Logger.debug("buffer: #{buffer}")
    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
  end

  @spec send_throttle_command(map(), any(), integer()) :: atom()
  def send_throttle_command(commands, socket, port) do
    buffer = @cmd_header <> <<25, 0, 0, 0>>
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Map.get(commands, :throttle,-999),32))
    |> Kernel.<>(@zeros_7)
    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>)
    # Logger.debug("buffer: #{buffer}")
    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
  end

  @spec send_attitude(map(), any(), integer()) :: atom()
  def send_attitude(values, socket, port) do
    Logger.info("send attitude: #{inspect(values)} to #{port}")
    buffer = @cmd_header <> <<17, 0, 0, 0>>
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.pitch,32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.roll,32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.yaw,32))
    |> Kernel.<>(@zeros_5)
    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0>>)
    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
  end

  @spec send_bodyrate(map(), any(), integer()) :: atom()
  def send_bodyrate(values, socket, port) do
    Logger.info("send bodyrate: #{inspect(values)}")
    buffer = @cmd_header <> <<16, 0, 0, 0>>
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.pitchrate,32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.rollrate,32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.yawrate,32))
    |> Kernel.<>(@zeros_5)
    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>)
    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
  end

  @spec send_accel(map(), any(), integer()) :: atom()
  def send_accel(values, socket, port) do
    Logger.info("send accel: #{inspect(values)}")
    buffer = @cmd_header <> <<4, 0, 0, 0>>
    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>)
    |> Kernel.<>(@zeros_4)
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.z,32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.x,32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.y,32))
    |> Kernel.<>(@zeros_1)
    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
  end

  @spec send_position(map(), any(), integer()) :: atom()
  def send_position(values, socket, port) do
    Logger.info("send position: #{inspect(values)}")
    buffer = @cmd_header <> <<20, 0, 0, 0>>
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Common.Utils.Math.rad2deg(values.latitude),32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Common.Utils.Math.rad2deg(values.longitude),32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.altitude,32))
    |> Kernel.<>(@zeros_5)
    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0>>)
    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
  end

 @spec send_velocity(map(), any(), integer()) :: atom()
  def send_velocity(values, socket, port) do
    Logger.info("send velocity: #{inspect(values)}")
    buffer = @cmd_header <> <<21, 0, 0, 0>>
    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0>>)
    |> Kernel.<>(@zeros_5)
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.east,32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(-values.down,32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(-values.north,32))
    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
  end



 @spec send_message(atom(), map()) :: atom()
  def send_message(message_type, value) do
    GenServer.cast(__MODULE__, {:send, message_type, value})
  end

end
