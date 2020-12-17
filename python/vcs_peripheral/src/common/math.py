def convert_from_twos_comp(val, bytes):
    """compute the 2's complement of int value val"""
    if (val & (1 << (bytes*8 - 1))) != 0: # if sign bit is set e.g., 8bit: 128-255
        # val = val ^ inverter(bits)
        # return -(val+1)
        val = val - (1 << bytes*8)        # compute negative value
    return val

def convert_to_twos_comp(val, bytes):
    if (val < 0): # if sign bit is set e.g., 8bit: 128-255
        return (1<< bytes*8) + val # subtracting negative of value
    return val

def inverter(bits):
    x = 1
    for _i in range(1,bits):
        x = x<<1
        x = x^1
    return x