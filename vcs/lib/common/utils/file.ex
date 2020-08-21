defmodule Common.Utils.File do
  require Logger

  @spec get_mount_path() :: binary()
  def get_mount_path() do
    "/mnt"
  end

  @spec mount_usb_drive() :: binary()
  def mount_usb_drive() do
    path = get_mount_path()
    Logger.debug("Mount USB drive to #{path}")
    System.cmd("mount", ["/dev/sda1", path])
  end

  @spec unmount_usb_drive() :: binary()
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
