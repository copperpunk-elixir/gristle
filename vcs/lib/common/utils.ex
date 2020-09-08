defmodule Common.Utils do
  require Logger
  use Bitwise

  def start_link_redundant(parent_module, module, config, name \\ nil) do
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

  @spec safe_call(tuple(), any(), integer(), any()) :: atom()
  def safe_call(pid, msg, timeout, default) do
    unless (GenServer.whereis(pid) == nil) do
      GenServer.call(pid, msg, timeout)
    else
      default
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

  # Erlang float_to_binary shorthand
  @spec eftb(float(), integer()) :: binary()
  def eftb(number, num_decimals) do
    :erlang.float_to_binary(number/1, [decimals: num_decimals])
  end

  @spec eftb_deg(float(), integer()) ::binary()
  def eftb_deg(number, num_decimals\\1) do
    :erlang.float_to_binary(Common.Utils.Math.rad2deg(number), [decimals: num_decimals])
  end

  @spec eftb_rad(float(), integer()) ::binary()
  def eftb_rad(number, num_decimals) do
    :erlang.float_to_binary(Common.Utils.Math.deg2rad(number), [decimals: num_decimals])
  end

  @spec map_rad2deg(map()) :: map()
  def map_rad2deg(values) do
    Enum.reduce(values, %{}, fn ({key, value}, acc) ->
    Map.put(acc, key, Common.Utils.Math.rad2deg(value))
    end)
  end

  @spec map_deg2rad(map()) :: map()
  def map_deg2rad(values) do
    Enum.reduce(values, %{}, fn ({key, value}, acc) ->
    Map.put(acc, key, Common.Utils.Math.deg2rad(value))
    end)
  end

  def list_to_int(x_list, bytes) do
    Enum.reduce(0..bytes-1, 0, fn(index,acc) ->
      acc + (Enum.at(x_list,index)<<<(8*index))
    end)
  end

  @spec get_key_or_value(map(), any()) :: any()
  def get_key_or_value(key_value_map, id) do
    Enum.reduce(key_value_map, nil, fn ({key, value}, acc) ->
      cond do
        (key == id) -> value
        (value == id) -> key
        true -> acc
      end
    end)
  end

  @spec default_to(any(), any()) :: any()
  def default_to(input, default_value) do
    if is_nil(input), do: default_value, else: input
  end

  @spec power_off() ::tuple()
  def power_off() do
    System.cmd("poweroff", ["now"])
  end
end
