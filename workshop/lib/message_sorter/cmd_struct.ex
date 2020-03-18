defmodule MessageSorter.CmdStruct do
  defstruct classification: nil, expiration_mono_ms: nil, value: nil

  def create_cmd(classification, expiration_mono_ms, value) do
    %MessageSorter.CmdStruct{
      classification: classification,
      expiration_mono_ms: expiration_mono_ms,
      value: value
    }
  end
end
