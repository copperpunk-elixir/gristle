defmodule Pids.Tecs.Arm do
  use Agent

  def start_link() do
    Common.Utils.start_link_redundant(Agent, __MODULE__, %{armed: false, takeoff: false})
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  @doc """
  Puts the `value` for the given `key` in the `bucket`.
  """
  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  def takeoff() do
    Agent.update(__MODULE__, &Map.put(&1, :takeoff, true))
  end

  def arm() do
    Agent.update(__MODULE__, &Map.put(&1, :armed, true))
  end

  def disarm() do
    Agent.update(__MODULE__, &Map.put(&1, :armed, false))
    Agent.update(__MODULE__, &Map.put(&1, :takeoff, false))
  end
end
