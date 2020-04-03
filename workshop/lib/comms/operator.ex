defmodule Comms.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start CommsOperator")
    {:ok, pid} = Common.Utils.start_link_redudant(GenServer, __MODULE__, config, __MODULE__)
    start_message_sorter_system()
    join_initial_groups(config.groups)
    start_refresh_loop()
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        refresh_groups_loop_interval_ms: Map.get(config, :refresh_groups_loop_interval_ms),
        refresh_groups_timer: nil,
        groups: [],
        message_count: 0 # this is purely for diagnostics
     }}
  end

  @impl GenServer
  def handle_cast(:start_refresh_loop, state) do
    refresh_groups_timer = Common.Utils.start_loop(self(), state.refresh_groups_loop_interval_ms, :refresh_groups)
    {:noreply, %{state | refresh_groups_timer: refresh_groups_timer}}
  end

  @impl GenServer
  def handle_cast(:stop_refresh_loop, state) do
    refresh_groups_timer = Common.Utils.stop_loop(state.refresh_groups_timer)
    {:noreply, %{state | refresh_groups_timer: refresh_groups_timer}}
  end

  @impl GenServer
  def handle_cast({:join_group, group}, state) do
    Logger.debug("join group: #{group}")
    :pg2.create(group)
    groups =
    if !is_in_group?(group, self()) do
      :pg2.join(group, self())
      [group | state.groups]
    else
      state.groups
    end
    MessageSorter.System.start_sorter(group)
    {:noreply, %{state | groups: groups}}
  end

  @impl GenServer
  def handle_cast({:leave_group, group}, state) do
    groups =
    if is_in_group?(group, self()) do
      :pg2.leave(group, self())
      List.delete(state.groups, group)
    else
      state.groups
    end
    {:noreply, %{state | groups: groups}}
  end

  @impl GenServer
  def handle_cast({:send_msg_to_group, message, group, sender}, state) do
    members = Map.get(state.groups, group, [])
    Enum.each(members, fn dest ->
      if dest != sender do
        Logger.debug("Send #{inspect(message)} to #{inspect(dest)}")
        GenServer.cast(dest, message)
      end
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:global_msg, msg_group, classification, time_validity_ms, value}, state) do
    MessageSorter.Sorter.add_message(msg_group, classification, time_validity_ms, value)
    message_count = state.message_count + 1
    {:noreply, %{state | message_count: message_count}}
  end

  @impl GenServer
  def handle_call({:get_members, group}, _from, state) do
    {:reply, Map.get(state.groups, group, []), state}
  end

  @impl GenServer
  def handle_call(:get_all_groups_and_members, _from, state) do
    {:reply, state.groups, state}
  end

  @impl GenServer
  def handle_call(:get_message_count, _from, state) do
    {:reply, state.message_count, state}
  end

  @impl GenServer
  def handle_info(:refresh_groups, state) do
    groups =
      Enum.reduce(:pg2.which_groups, %{}, fn (group, acc) ->
        group_members = :pg2.get_members(group)
        Map.put(acc, group, group_members)
      end)
    {:noreply, %{state | groups: groups}}
  end

  def start_message_sorter_system() do
    MessageSorter.System.start_link()
  end

  defp join_initial_groups(groups) do
    Enum.each(groups, fn group ->
      join_group(group)
    end)
  end

  def start_refresh_loop() do
    GenServer.cast(__MODULE__, :start_refresh_loop)
  end

  def stop_refresh_loop() do
    GenServer.cast(__MODULE__, :stop_refresh_loop)
  end

  def join_group(group) do
    GenServer.cast(__MODULE__, {:join_group, group})
  end

  def leave_group(group) do
    GenServer.cast(__MODULE__, {:leave_group, group})
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

  def get_message_count() do
    GenServer.call(__MODULE__, :get_message_count)
  end
end
