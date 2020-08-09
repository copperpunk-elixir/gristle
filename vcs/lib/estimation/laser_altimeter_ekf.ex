defmodule Estimation.LaserAltimeterEkf do
  require Bitwise
  require Logger

  defstruct [phi: 0, theta: 0, zdot: 0, z: 0, q33: 0, p00: 0, p11: 0, p22: 0, p33: 0, r: 0, time_prev_us: -1]

  @default_q_att_sq 0.00274 #3deg^2
  @default_q_zdot_sq 0.25
  @default_q_z_sq 0.1
  @default_r_range_sq 1.0

  @max_phi 0.52
  @max_theta 0.52

  def new(config) do
    q_att_sq = Map.get(config, :q_att_sq, @default_q_att_sq)
    q_zdot_sq = Map.get(config, :q_zdot_sq, @default_q_zdot_sq)
    q_z_sq = Map.get(config, :q_z_sq, @default_q_z_sq)
    r_range_sq = Map.get(config, :r_range_sq, @default_r_range_sq)
    %Estimation.LaserAltimeterEkf{q33: q_z_sq, p00: q_att_sq, p11: q_att_sq, p22: q_zdot_sq, p33: q_z_sq, r: r_range_sq}
  end

  @spec reset(struct(), float()) :: struct()
  def reset(ekf, z) do
    config = %{
      q_att_sq: ekf.p00,
      q_zdot_sq: ekf.p22,
      q_z_sq: ekf.q33,
      r_range_sq: ekf.r
    }
    ekf = Estimation.LaserAltimeterEkf.new(config)
    %{ekf | z: z}
  end


  @spec predict(struct(), float(), float(), float()) :: struct()
  def predict(ekf, phi, theta, zdot) do
    current_time = :os.system_time(:microsecond)
    dt = if (ekf.time_prev_us < 0), do: 0, else: (current_time - ekf.time_prev_us)*(1.0e-6)
    z = ekf.z + ekf.zdot*dt
    # Logger.info("zdot/zprev/z/dt: #{zdot}/#{ekf.z}/#{z}/#{dt}")
    p33 = ekf.p33 + ekf.p22*dt*dt + ekf.q33
    %{ekf | phi: phi, theta: theta, zdot: zdot, z: z, p33: p33, time_prev_us: current_time}
  end

  @spec update(struct(), float()) :: struct()
  def update(ekf, range_meas) do
    if (abs(ekf.phi) > @max_phi) or (abs(ekf.theta) > @max_theta) do
      ekf
    else
      z_sq = ekf.z*ekf.z
      sinphi = :math.sin(ekf.phi)
      sinphi_sq = sinphi*sinphi
      cosphi = :math.cos(ekf.phi)
      cosphi_sq = cosphi*cosphi
      sintheta = :math.sin(ekf.theta)
      sintheta_sq = sintheta*sintheta
      costheta = :math.cos(ekf.theta)
      costheta_sq = costheta*costheta

      s = ekf.r + ekf.p33/(cosphi_sq*costheta_sq) + ekf.p00*(sinphi_sq*z_sq)/(cosphi_sq*cosphi_sq*costheta_sq) + ekf.p11*(sintheta_sq*z_sq)/(cosphi_sq*costheta_sq*costheta_sq)
      s = if (s == 0), do: 0.0, else: 1/s
      dz = range_meas - ekf.z/(cosphi*costheta)
      z = ekf.z + s*dz*ekf.p33/(cosphi_sq*costheta_sq)
      p33 = ekf.p33*(1.0 - ekf.p33*s/(cosphi_sq*costheta_sq))
      %{ekf | z: z, p33: p33}
    end
  end

  @spec agl(struct()) :: float()
  def agl(ekf) do
    ekf.z
  end
end
