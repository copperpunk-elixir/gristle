defmodule CommandSorter.CmdStruct do
  defstruct priority: nil, authority: nil, expiration_mono_ms: nil, value: nil

  def create_cmd(priority, authority, expiration_mono_ms, value) do
    %CommandSorter.CmdStruct{
      priority: priority,
      authority: authority,
      expiration_mono_ms: expiration_mono_ms,
      value: value
    }
  end
end
