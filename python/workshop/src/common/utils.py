import struct

def list_to_int(x,endian='little'):
    if endian=='little':
        value = 0
        index = 0
        for b in x:
            value += b<<(8*index)
            index+=1
        return value
    else:
        value = 0
        index = 0
        for b in reversed(x):
            value += b<<(8*index)
            index+=1
        return value

def int_to_list(x,bytes=4,endian='little'):
    result = []
    if bytes < 4 or bytes > 8:
        print("bytes must be 4 or 8")
        return None

    for i in range(bytes):
        byte = x & 0xFF
        print("i/x/byte: %d/%d/%d" % (i,x,byte))
        result.insert(0, byte)
        x = x >> 8
    if endian == 'little':
        result.reverse()
    return result

def decimal_to_list(x, bytes=4, endian='little'):
    x_int = decimal_to_int(x, 4)
    return int_to_list(x_int, 4, endian)

def list_to_decimal(x, bytes=4, endian='little'):
    x_int = list_to_int(x, endian=endian)
    print('x_int: %d' % x_int)
    return int_to_decimal(x_int,bytes)


# def float_to_list(x, endian='little'):
#     x_int = decimal_to_int(x)
#     return int_to_list(x_int, 4, endian)


# def list_to_float(x, endian='little'):
#     x_int = list_to_int(x, 4, endian=endian)
#     print('x_int: %d' % x_int)
#     return int_to_decimal(x_int,4)


def int_to_decimal(x, bytes=4):
    x_bytes = struct.pack('i',x)
    if bytes == 4:
        (x_float,) = struct.unpack('f',x_bytes)
    elif bytes == 8:
        (x_float,) = struct.unpack('d',x_bytes)
    else:
        print("bytes must be 4 or 8")
        return None
    return x_float

def decimal_to_int(x, bytes=4):
    if bytes == 4:
        packed = struct.pack('f', x)
    elif bytes == 8:
        packed = struct.pack('d', x)
    else:
        print("bytes must be 4 or 8")
        return None
    (x_int,) = struct.unpack('i', packed)
    return x_int