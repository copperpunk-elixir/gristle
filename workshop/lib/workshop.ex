defmodule Workshop do
  use GenServer

  def start_link(_) do
    GenServer.start(__MODULE__, nil)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast({:time, send_time}, state) do
    receive_time = System.os_time(:microsecond)
    IO.puts("msg rx: #{dt_ms(send_time, receive_time)}")
    {:noreply, state}
  end

  def handle_cast({:join_registry, group}, state) do
    Registry.register(:test, group, [])
    {:noreply, state}
  end

  def create(group) do
    start_time = System.monotonic_time(:microsecond)
    :pg2.create(group)
    end_time = System.monotonic_time(:microsecond)
    IO.puts("create time: #{dt_ms(start_time, end_time)}")
  end

  def join(group, pid) do
    start_time = System.monotonic_time(:microsecond)
    if !is_in_group?(group, pid) do
      :pg2.join(group, pid)
    end
    end_time = System.monotonic_time(:microsecond)
    IO.puts("join time: #{dt_ms(start_time, end_time)}")
  end

  def create_and_join(group, pid) do
    start_time = System.monotonic_time(:microsecond)
    :pg2.create(group)
    if !is_in_group?(group, pid) do
      :pg2.join(group, pid)
    end
    end_time = System.monotonic_time(:microsecond)
    IO.puts("create and join time: #{dt_ms(start_time, end_time)}")
  end

  def dt_ms(start_time, end_time) do
    (end_time - start_time)/1000.0
  end

  def is_in_group?(group, pid) do
    members = :pg2.get_members(group)
    Enum.member?(members, pid)
  end

  def send_pg2(group, sender) do
    Enum.each(1..10, fn _ ->
      # Workshop.create_and_join(group, sender)
      :pg2.create(group)
      if !is_in_group?(group, sender) do
        :pg2.join(group, sender)
      end
      Enum.each(:pg2.get_members(group), fn pid ->
        if pid != sender do
          GenServer.cast(pid, {:time, System.os_time(:microsecond)})
        end
      end)
      end)
  end

  def start_registry() do
    Registry.start_link(keys: :duplicate, name: :test, partitions: System.schedulers_online())
  end

  def join_registry(group, pid) do
    GenServer.cast(pid, {:join_registry, group})
  end

  def send_registry(group) do
    Registry.dispatch(:test, group, fn entries ->
      for {pid, _} <- entries do
        GenServer.cast(pid, {:time, System.os_time(:microsecond)})
      end
    end)
  end
end
