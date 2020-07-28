defmodule Logging.SaveOnCrashTest do
  use ExUnit.Case
  require Logger

  setup do
    config = Configuration.Module.Logging.get_config(nil,nil)
    Logging.Logger.start_link(config.logger)
    Process.sleep(400)
    {:ok, []}
  end

  test "Save RingLogger to file" do
    Workshop.start_link(nil)
    Workshop.crash()
    Process.sleep(1000)
  end
end
