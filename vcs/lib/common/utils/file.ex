defmodule Common.Utils.File do
  require Logger

  @mount_count_max 3

  @spec get_mount_path() :: binary()
  def get_mount_path() do
    "/mnt"
  end

  @spec mount_usb_drive() :: atom()
  def mount_usb_drive() do
    path = get_mount_path()
    mount_usb_drive(path, 1, @mount_count_max)
  end

  @spec mount_usb_drive(binary(), integer(), integer()) :: tuple()
  def mount_usb_drive(path, count, count_max) do
    Logger.debug("Mount USB drive to #{path}")
    {_resp, error_code} = System.cmd("mount", ["/dev/sda1", path])
    if (error_code == 0) do
      :ok
    else
      Logger.error("USB Drive could not be mounted to #{path}")
      if (count < count_max) do
        Logger.info("Retry #{count+1}/#{count_max}")
        Process.sleep(1000)
        mount_usb_drive(path, count+1, count_max)
      end
    end
  end

  @spec unmount_usb_drive() :: tuple()
  def unmount_usb_drive() do
    path = get_mount_path()
    Logger.debug("Unmount USB drive from #{path}")
    System.cmd("umount", [path])
  end

  @spec cycle_mount() :: atom()
  def cycle_mount() do
    Logger.debug("Cycling usb drive mount")
    unmount_usb_drive()
    Process.sleep(500)
    mount_usb_drive()
    :ok
  end

  @spec get_filenames_with_extension(binary(), binary()) :: list()
  def get_filenames_with_extension(extension, subdirectory \\ "") do
    path = get_mount_path() <> "/" <> subdirectory
    {:ok, files} = :file.list_dir(path)
    filenames = Enum.reduce(files,[], fn (file, acc) ->
      file = to_string(file)
      if (String.contains?(file,extension)) do
        [filename] = String.split(file,extension,[trim: true])
        acc ++ [filename]
      else
        acc
      end
    end)
    # if (Enum.empty?(filenames)) do
    #   raise "Filename is not available"
    # end
    filenames
  end
end
