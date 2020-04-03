defmodule Common.Utils.File do
  require Logger

  def file2json(filename) do
    {:ok, body} = File.read(filename)
    body
    |> String.replace(" ","")
    |> String.replace("\n","")
  end
end
