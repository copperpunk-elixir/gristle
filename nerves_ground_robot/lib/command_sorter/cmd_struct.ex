defmodule CommandSorter.CmdStruct do
  defstruct priority: nil, authority: nil, expiration_mono_ms: nil, value: nil

  def create_cmd(classification, value) do
    %CommandSorter.CmdStruct{
      priority: classification.priority,
      authority: classification.authority,
      expiration_mono_ms: classification.expiration_mono_ms,
      value: value
    }
  end
end
