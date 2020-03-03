defmodule TestLibraryUsage do
  require Logger
  def info() do
    Logger.debug(TestLibrary.info())
    Logger.debug(inspect(TestLibrary.Team.get_team()))
    Logger.debug(inspect(Adsadc.new_adsadc(%{bus_ref: "i2c-2", address: 0x01, input_method: :linear})))
  end
end
