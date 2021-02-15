defmodule Common.Application do
  use Application
  require Logger

  def start(_type, _args) do
    Boss.System.start()
    {:ok, self()}
  end
end
