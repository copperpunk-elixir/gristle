defmodule TestLibraryUsage do
  require Logger
  def info() do
    Logger.debug(TestLibrary.info())
    Logger.debug(inspect(TestLibrary.Team.get_team()))
  end
end
