defmodule Protobufs.Addressbook.Person.PhoneType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  @type t :: integer | :MOBILE | :HOME | :WORK

  field :MOBILE, 0
  field :HOME, 1
  field :WORK, 2
end

defmodule Protobufs.Addressbook.Person.PhoneNumber do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          number: String.t(),
          type: Protobufs.Addressbook.Person.PhoneType.t()
        }
  defstruct [:number, :type]

  field :number, 1, required: true, type: :string

  field :type, 2,
    optional: true,
    type: Protobufs.Addressbook.Person.PhoneType,
    default: :HOME,
    enum: true
end

defmodule Protobufs.Addressbook.Person do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          name: String.t(),
          id: integer,
          email: String.t(),
          phones: [Protobufs.Addressbook.Person.PhoneNumber.t()]
        }
  defstruct [:name, :id, :email, :phones]

  field :name, 1, required: true, type: :string
  field :id, 2, required: true, type: :int32
  field :email, 3, optional: true, type: :string
  field :phones, 4, repeated: true, type: Protobufs.Addressbook.Person.PhoneNumber
end

defmodule Protobufs.Addressbook.AddressBook do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          people: [Protobufs.Addressbook.Person.t()]
        }
  defstruct [:people]

  field :people, 1, repeated: true, type: Protobufs.Addressbook.Person
end
