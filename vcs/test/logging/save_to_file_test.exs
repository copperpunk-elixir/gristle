defmodule Logging.SaveToFileTest do
  use ExUnit.Case
  require Logger

  setup do
    config = Configuration.Module.Logging.get_config(nil,nil)
    Logging.Logger.start_link(config.logger)
    Process.sleep(400)
    {:ok, []}
  end

  test "Save RingLogger to file" do
    Logging.Logger.save_log("estimation")
    Process.sleep(100)
    file_loc = Logging.Logger.get_log_directory()
    Logger.debug("file loc: #{file_loc}")
    {:ok, logs} = File.ls(file_loc)
    assert Enum.empty?(logs) == false
  end
end
