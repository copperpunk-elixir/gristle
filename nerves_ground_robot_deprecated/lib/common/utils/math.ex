defmodule Common.Utils.Math do
  require Logger

  def quat_in_bounds?(quat, error_bounds \\ 0.02) do
    quat_mag =
    if is_map(quat) do
      Enum.reduce(quat,0, fn({_key, x}, acc) ->
        acc + :math.pow(x,2)
        end)
    else
      Enum.reduce(0..3,0,fn (index, acc) ->
        acc + :math.pow(elem(quat,index), 2)
      end)
    end
    quat_mag = :math.sqrt(quat_mag)
    (abs(quat_mag - 1.0) <= error_bounds)
  end

  def quat2euler(quat, is_android \\ true) do
    if is_map(quat) do
      quat2euler_map(quat, is_android)
    else
      quat2euler_tuple(quat, is_android)
    end
  end

  defp quat2euler_map(quat, is_android) do
    {qx, qy, qz, qw} =
    if is_android do
      {quat.y, quat.x, -quat.z, quat.w}
    else
      {quat.x, quat.y, quat.z, quat.w}
    end
    #roll
    sinr_cosp = 2 * (qw * qx + qy * qz)
    cosr_cosp = 1 - 2 * (qx * qx + qy * qy)
    roll = :math.atan2(sinr_cosp, cosr_cosp)

    # pitch
    sinp = 2 * (qw * qy - qz * qx)
    pitch = cond do
      sinp >= 1 ->
        :math.pi()*0.5
      sinp <= -1 ->
        -:math.pi()*0.5
      true ->
        :math.asin(sinp)
    end
    # yaw
    siny_cosp = 2 * (qw * qz + qx * qy)
    cosy_cosp = 1 - 2 * (qy * qy + qz * qz)
    yaw = :math.atan2(siny_cosp, cosy_cosp)
    %{roll: roll, pitch: pitch, yaw: yaw}
  end

  defp quat2euler_tuple(quat, is_android) do
    quat = if is_android do
      {
        elem(quat,1),
        elem(quat,0),
        -elem(quat,2),
        elem(quat,3)
      }
    end
    qx = elem(quat,0)
    qy = elem(quat,1)
    qz = elem(quat,2)
    qw = elem(quat,3)
    #roll
    sinr_cosp = 2 * (qw * qx + qy * qz)
    cosr_cosp = 1 - 2 * (qx * qx + qy * qy)
    roll = :math.atan2(sinr_cosp, cosr_cosp)

    # pitch
    sinp = 2 * (qw * qy - qz * qx)
    pitch = cond do
      sinp >= 1 ->
        :math.pi()*0.5
      sinp <= -1 ->
        -:math.pi()*0.5
      true ->
        :math.asin(sinp)
    end
    # yaw
    siny_cosp = 2 * (qw * qz + qx * qy)
    cosy_cosp = 1 - 2 * (qy * qy + qz * qz)
    yaw = :math.atan2(siny_cosp, cosy_cosp)
    {roll,pitch, yaw}
  end

  def euler2quat(rpy) do
    roll = elem(rpy,0)
    pitch = elem(rpy,1)
    yaw = elem(rpy,2)
    sin_roll_2 = :math.sin(roll*0.5)
    cos_roll_2 = :math.cos(roll*0.5)
    sin_pitch_2 = :math.sin(pitch*0.5)
    cos_pitch_2 = :math.cos(pitch*0.5)
    sin_yaw_2 = :math.sin(yaw*0.5)
    cos_yaw_2 = :math.cos(yaw*0.5)

    qw = cos_roll_2*cos_pitch_2*cos_yaw_2 + sin_roll_2*sin_pitch_2*sin_yaw_2
    qx = sin_roll_2*cos_pitch_2*cos_yaw_2 - cos_roll_2*sin_pitch_2*sin_yaw_2
    qy = cos_roll_2*sin_pitch_2*cos_yaw_2 + sin_roll_2*cos_pitch_2*sin_yaw_2
    qz = cos_roll_2*cos_pitch_2*sin_yaw_2 - sin_roll_2*sin_pitch_2*cos_yaw_2
    {qx, qy, qz, qw}
  end

  def print_euler(rpy) do
    Logger.debug("RPY: #{inspect(rpy)}")
  end

  def print_quat(quat) do
    Logger.debug("XYZW: #{inspect(quat)}")
  end

  def rad2deg_with_length(x_tuple, len) do
    x_list = Enum.map(0..len-1, fn index ->
      rad2deg(elem(x_tuple, index))
    end)
    List.to_tuple(x_list)
  end

  def rad2deg_map(x_map) do
    Enum.reduce(x_map, %{}, fn ({key, value}, acc) ->
      put_in(acc, [key], rad2deg(value))
    end)
  end

  def rad2deg(x) do
    x*180/:math.pi()
  end

  def rad2deg_print(x) do
    Float.round(x*180/:math.pi(),3)
  end
  def deg2rad_with_length(x_tuple, len) do
    x_list = Enum.map(0..len-1, fn index ->
      deg2rad(elem(x_tuple, index))
    end)
    List.to_tuple(x_list)
  end

  def deg2rad(x) do
    x*:math.pi()/180
  end

  def constrain(x, min_value, max_value) do
    case x do
      _ when x > max_value -> max_value
      _ when x < min_value -> min_value
      x -> x
    end
  end

  def dec2str(value, decimals) do
    :erlang.float_to_binary(value, [decimals: decimals])
  end
end
