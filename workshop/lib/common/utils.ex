defmodule Common.Utils do
  require Logger

  def start_link_redudant(parent_module, module, config, name) do
    result =
      case parent_module do
        GenServer -> GenServer.start_link(module, config, name: name)
        DynamicSupervisor -> DynamicSupervisor.start_link(module, config, name: name)
      end
    case result do
      {:ok, pid} ->
        Logger.debug("#{module}:#{name} successfully started")
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.debug("#{module}:#{name} already started at #{inspect(pid)}. This is fine.")
        {:ok, pid}
    end
  end

  def wait_for_genserver_start(process_name, current_time \\ 0, timeout \\ 60000) do
    Logger.debug("Wait for GenServer process: #{inspect(process_name)}")
    if GenServer.whereis(process_name) == nil do
      if current_time < timeout do
        Process.sleep(10)
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
end
