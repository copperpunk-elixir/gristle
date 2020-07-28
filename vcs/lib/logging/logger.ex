defmodule Logging.Logger do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Logging.Logger")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    log_path = config.log_path
    now = DateTime.utc_now
    log_folder = get_date_string(now,"-") <> "/"
    {:ok, %{
        log_directory: log_path <> log_folder
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    RingLogger.attach()
    Logger.warn("log directory: #{state.log_directory}")
    :filelib.ensure_dir(state.log_directory)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:save_log, message}, state) do
    time_string = get_time_string(DateTime.utc_now, "-")
    filename = state.log_directory <> time_string <> message <> ".txt"
    # Logger.info("save filename: #{filename}")
    RingLogger.save(filename)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_log_directory, _from, state) do
    {:reply, state.log_directory, state}
  end


  @spec save_log(binary()) ::atom()
  def save_log(message \\ "") do
    # Logger.info("save log: #{message}")
    message = cond do
      is_atom(message) -> "_" <> Atom.to_string(message)
      is_binary(message) ->
        if String.length(message) == 0, do: "", else: "_" <> message
    end
    GenServer.cast(__MODULE__, {:save_log, message})
  end

  @spec get_log_directory() :: binary()
  def get_log_directory do
    GenServer.call(__MODULE__, :get_log_directory)
  end

  @spec get_date_string(struct(), binary()) :: binary()
  def get_date_string(datetime, separator) do
    year = datetime.year |> Integer.to_string()
    month = datetime.month |> Integer.to_string() |> String.pad_leading(2,"0")
    day = datetime.day |> Integer.to_string() |> String.pad_leading(2,"0")
    year <> separator <> month <> separator <> day
  end

  @spec get_time_string(struct(),binary()) :: binary()
  def get_time_string(datetime, separator) do
    hour = datetime.hour |> Integer.to_string() |> String.pad_leading(2,"0")
    minute = datetime.minute |> Integer.to_string() |> String.pad_leading(2,"0")
    second = datetime.second |> Integer.to_string() |> String.pad_leading(2,"0")
    # {us, _} = datetime.microsecond
    # us = us/1000 |> round() |> Integer.to_string |> String.pad_leading(3,"0")
    hour <> separator <> minute <> separator <> second
  end

  @spec log_terminate(tuple(), map(), atom()) :: atom()
  def log_terminate(reason, state, module) do
    Logger.error("trap: #{inspect(reason)}")
    Logger.info("state: #{inspect(state)}")
    save_log(module)
  end
end
