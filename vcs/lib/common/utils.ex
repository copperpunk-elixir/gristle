defmodule Common.Utils do
  require Logger

  def start_link_redudant(parent_module, module, config, name \\ nil) do
    name =
      case name do
        nil -> module
        atom -> atom
      end
    result =
      case parent_module do
        GenServer -> GenServer.start_link(module, config, name: name)
        GenStateMachine -> GenStateMachine.start_link(module, config, name: name)
        Supervisor -> Supervisor.start_link(module, config, name: name)
        DynamicSupervisor -> DynamicSupervisor.start_link(module, config, name: name)
        Registry -> apply(Registry, :start_link, [config])
      end
    case result do
      {:ok, pid} ->
        Logger.debug("#{module}: #{inspect(name)} successfully started")
        wait_for_genserver_start(pid)
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.debug("#{module}: #{inspect(name)} already started at #{inspect(pid)}. This is fine.")
        {:ok, pid}
    end
  end

  def start_link_singular(parent_module, module, config, name \\ nil) do
    name =
      case name do
        nil -> module
        atom -> atom
      end
    result =
      case parent_module do
        GenServer -> GenServer.start_link(module, config, name: name)
        GenStateMachine -> GenStateMachine.start_link(module, config, name: name)
        Supervisor -> Supervisor.start_link(module, config, name: name)
        DynamicSupervisor -> DynamicSupervisor.start_link(module, config, name: name)
        Registry -> apply(Registry, :start_link, [config])
      end
    case result do
      {:ok, pid} ->
        Logger.debug("#{module}: #{inspect(name)} successfully started")
        wait_for_genserver_start(pid)
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        raise "#{module}: #{inspect(name)} already started at #{inspect(pid)}. This is not okay."
        {:error, pid}
    end

  end

  def wait_for_genserver_start(process_name, current_time \\ 0, timeout \\ 60000) do
    Logger.debug("Wait for GenServer process: #{inspect(process_name)}")
    if GenServer.whereis(process_name) == nil do
      if current_time < timeout do
        Process.sleep(100)
        wait_for_genserver_start(process_name, current_time + 10, timeout)
      else
        Logger.error("Wait for GenServer Start TIMEOUT. Waited #{timeout/1000}s")
      end
    end
  end

  def assert_list(value_or_list) do
    if is_list(value_or_list) do
      value_or_list
    else
      [value_or_list]
    end
  end

  def list_to_enum(input_list) do
    input_list
    |> Enum.with_index()
    |> Map.new()
  end

  def assert_valid_config(config, config_type) do
    {verify_fn, default_value} =
      case config_type do
        Map -> {:is_map, %{}}
        List -> {:is_list, []}
      end
    if apply(Kernel, verify_fn, [config]) do
      config
    else
      default_value
    end
  end
  # def validate_config_with_default(config,, default_config) do
  # end

  def start_loop(process_id, loop_interval_ms, loop_callback) do
      case :timer.send_interval(loop_interval_ms, process_id, loop_callback) do
        {:ok, timer} ->
          Logger.debug("#{loop_callback} timer started!")
          timer
        {_, reason} ->
          Logger.debug("Could not start #{loop_callback} timer: #{inspect(reason)} ")
          nil
      end
  end

  def stop_loop(timer) do
    case :timer.cancel(timer) do
      {:ok, _} ->
        nil
      {_, reason} ->
        Logger.debug("Could not stop #{inspect(timer)} timer: #{inspect(reason)} ")
        timer
    end
  end

  @spec get_uart_devices_containing_string(binary()) :: list()
  def get_uart_devices_containing_string(device_string) do
    device_string = String.downcase(device_string)
    Logger.debug("devicestring: #{device_string}")
    uart_ports = Circuits.UART.enumerate()
    matching_ports = Enum.reduce(uart_ports, [], fn ({port_name, port}, acc) ->
      device_description = Map.get(port, :description)
      Logger.debug("description: #{String.downcase(device_description)}")
      if (device_description != nil) && String.contains?(String.downcase(device_description), device_string) do
        acc ++ [port_name]
      else
        acc
      end
    end)
    case length(matching_ports) do
      0 -> nil
      _ -> Enum.min(matching_ports)
    end
  end

  # Erlang float_to_binary shorthand
  @spec eftb(float(), integer()) :: binary()
  def eftb(number, num_decimals) do
    :erlang.float_to_binary(number, [decimals: num_decimals])
  end

  # Convert North/East velocity to Speed/Course
  @spec get_speed_course_for_velocity(number(), number(), number(), number()) :: float()
  def get_speed_course_for_velocity(v_north, v_east, min_speed_for_course, yaw) do
    speed = Common.Utils.Math.hypot(v_north, v_east)
    course =
    if speed >= min_speed_for_course do
      :math.atan2(v_east, v_north)
    else
      yaw
    end
    {speed, course}
  end

  # Turn correctly left or right using delta Yaw/Course
  @spec turn_left_or_right_for_correction(number()) :: number()
  def turn_left_or_right_for_correction(correction) do
    cond do
      correction < -:math.pi() -> correction + 2.0*:math.pi()
      correction > :math.pi() -> correction - 2.0*:math.pi()
      true -> correction
    end
  end

  @spec constrain_angle_to_compass(number()) :: number()
  def constrain_angle_to_compass(angle) do
    cond do
      angle < 0.0 -> angle + 2.0*:math.pi()
      angle > 2.0*:math.pi() -> angle - 2.0*:math.pi()
      true -> angle
    end
  end
end
