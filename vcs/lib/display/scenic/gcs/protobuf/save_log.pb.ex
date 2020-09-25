defmodule Display.Scenic.Gcs.Protobuf.SaveLog do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          filename: String.t()
        }
  defstruct [:filename]

  field :filename, 1, required: true, type: :string
end
