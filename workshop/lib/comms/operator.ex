defmodule Comms.Operator do
  use GenServer
  require Logger
  @refresh_interval_ms 100

  def start_link() do
    Logger.debug("Start CommsOperator")
    {_, pid} =
      case GenServer.start_link(__MODULE__, nil, name: __MODULE__) do
        {:ok, pid} ->
          Logger.debug("CommsOperator successfully started")
          {:ok, pid}
        {:error, {:already_started, pid}} ->
          Logger.debug("CommsOperator already started at #{inspect(pid)}. This is fine.")
          {:ok, pid}
      end
    :timer.send_interval(@refresh_interval_ms, pid, :refresh_groups)
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:join_group, group, pid}, state_groups) do
    :pg2.create(group)
    if !is_in_group?(group, pid) do
      :pg2.join(group, pid)
    end
    {:noreply, state_groups}
  end

  @impl GenServer
  def handle_cast({:leave_group, group, pid}, state_groups) do
    if is_in_group?(group, pid) do
      :pg2.leave(group, pid)
    end
    {:noreply, state_groups}
  end

  @impl GenServer
  def handle_cast({:send_msg_to_group, message, group, sender}, state_groups) do
    members = Map.get(state_groups, group, [])
    Enum.each(members, fn dest ->
      if dest != sender do
        GenServer.cast(dest, message)
      end
    end)
    {:noreply, state_groups}
  end

  @impl GenServer
  def handle_call({:get_members, group}, _from, state_groups) do
    {:reply, Map.get(state_groups, group, []), state_groups}
  end

  @impl GenServer
  def handle_call(:get_all_groups_and_members, _from, state_groups) do
    {:reply, state_groups, state_groups}
  end

  @impl GenServer
  def handle_info(:refresh_groups, _state_groups) do
    state_groups =
      Enum.reduce(:pg2.which_groups, %{}, fn (group, acc) ->
        group_members = :pg2.get_members(group)
        Map.put(acc, group, group_members)
      end)
    {:noreply, state_groups}
  end

  def join_group(group, pid) do
    GenServer.cast(__MODULE__, {:join_group, group, pid})
  end

  def leave_group(group, pid) do
    GenServer.cast(__MODULE__, {:leave_group, group, pid})
  end

  def send_msg_to_group(message, group, sender) do
    GenServer.cast(__MODULE__, {:send_msg_to_group, message, group, sender})
  end

  def is_in_group?(group, pid) do
    members =
      case :pg2.get_members(group) do
        {:error, _} -> []
        members -> members
      end
    Enum.member?(members, pid)
  end

  def get_members(group) do
    GenServer.call(__MODULE__, {:get_members, group})
  end

  def get_all_groups_and_members() do
    GenServer.call(__MODULE__, :get_all_groups_and_members)
  end

end
