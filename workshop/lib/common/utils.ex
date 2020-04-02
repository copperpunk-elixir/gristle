defmodule Common.Utils do
  require Logger

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
end
