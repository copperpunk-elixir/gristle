defmodule Navigation.Path.Protobuf.Mission.WaypointType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  @type t :: integer | :FLIGHT | :GROUND | :CLIMBOUT | :APPROACH | :LANDING

  field :FLIGHT, 0
  field :GROUND, 1
  field :CLIMBOUT, 2
  field :APPROACH, 3
  field :LANDING, 4
end

defmodule Navigation.Path.Protobuf.Mission.Waypoint do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          name: String.t(),
          latitude: float | :infinity | :negative_infinity | :nan,
          longitude: float | :infinity | :negative_infinity | :nan,
          altitude: float | :infinity | :negative_infinity | :nan,
          speed: float | :infinity | :negative_infinity | :nan,
          course: float | :infinity | :negative_infinity | :nan,
          goto: String.t(),
          type: Navigation.Path.Protobuf.Mission.WaypointType.t()
        }
  defstruct [:name, :latitude, :longitude, :altitude, :speed, :course, :goto, :type]

  field :name, 1, optional: true, type: :string
  field :latitude, 2, required: true, type: :float
  field :longitude, 3, required: true, type: :float
  field :altitude, 4, required: true, type: :float
  field :speed, 5, required: true, type: :float
  field :course, 6, required: true, type: :float
  field :goto, 7, optional: true, type: :string, default: ""
  field :type, 8, required: true, type: Navigation.Path.Protobuf.Mission.WaypointType, enum: true
end

defmodule Navigation.Path.Protobuf.Mission do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          name: String.t(),
          vehicle_turn_rate: float | :infinity | :negative_infinity | :nan,
          waypoints: [Navigation.Path.Protobuf.Mission.Waypoint.t()],
          confirm: boolean
        }
  defstruct [:name, :vehicle_turn_rate, :waypoints, :confirm]

  field :name, 1, required: true, type: :string
  field :vehicle_turn_rate, 2, required: true, type: :float
  field :waypoints, 3, repeated: true, type: Navigation.Path.Protobuf.Mission.Waypoint
  field :confirm, 4, optional: true, type: :bool, default: false
  field :display, 5, optional: true, type: :bool, default: false
end
