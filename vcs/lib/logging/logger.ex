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
    root_path = config.root_path
    {:ok, %{
        root_directory: root_path
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    # Logger.warn("log directory: #{state.log_directory}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:save_log, file_suffix}, state) do
    path = get_directory(state.root_directory,"log")
    :filelib.ensure_dir(path)
    filename = path <> (get_file_name(file_suffix))
    Logger.info("save filename: #{filename}")
    RingLogger.save(filename)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:write_to_file, folder, data, file_suffix}, state) do
    path = get_directory(state.root_directory, folder)
    :filelib.ensure_dir(path)
    filename = path <> get_file_name(file_suffix)
    Logger.info("write filename: #{filename}")
    File.write(filename, data)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_log_directory, _from, state) do
    log_directory = state.root_directory <> "log/"
    {:reply, log_directory, state}
  end

  @spec save_log(binary()) ::atom()
  def save_log(file_suffix \\ "") do
    Logger.info("save log: #{file_suffix}")
    GenServer.cast(__MODULE__, {:save_log, file_suffix})
  end

  @spec get_log_directory() :: binary()
  def get_log_directory do
    GenServer.call(__MODULE__, :get_log_directory)
  end

  @spec get_directory(binary(), binary()) :: binary()
  def get_directory(root, directory_name \\ "") do
    now = DateTime.utc_now
    date_directory = get_date_string(now,"-") <> "/"
    root <> directory_name <> "/" <> date_directory
  end

  @spec get_file_name(binary()) :: binary()
  def get_file_name(file_suffix) do
    file_suffix =
      cond do
      is_atom(file_suffix) -> "_" <> Atom.to_string(file_suffix)
      is_binary(file_suffix) ->
        if String.length(file_suffix) == 0, do: "", else: "_" <> file_suffix
    end
    time_string = get_time_string(DateTime.utc_now, "-")
    time_string <> file_suffix <> ".txt"
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

  @spec write_to_log_folder(binary(), binary()) :: atom()
  def write_to_log_folder(data, file_suffix) do
    GenServer.cast(__MODULE__, {:write_to_file, "log", data, file_suffix})
  end

  @spec write_to_folder(binary(), binary(), binary()) :: atom()
  def write_to_folder(folder, data, file_suffix) do
    GenServer.cast(__MODULE__, {:write_to_file, folder, data, file_suffix})
  end
end
