import math

earth_radius_m = 6371008.8
pi_4 = 0.785398163

def position_with_distance_and_bearing(lat1, lon1, distance, bearing):
    dx = distance*math.cos(bearing)
    dy = distance*math.sin(bearing)
    dlat = dx/earth_radius_m
    lat2 = lat1 + dlat
    dpsi = math.log(math.tan(pi_4 + lat2/2)/ math.tan(pi_4 + lat1/2))
    if (abs(dpsi) > 0.0000001):
        q = dlat/dpsi
    else:
        q = math.cos(lat1)
    dlon = (dy/earth_radius_m) / q
    lon2 = lon1 + dlon
    return lat2, lon2
