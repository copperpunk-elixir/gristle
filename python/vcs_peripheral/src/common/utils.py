import struct

def list_to_int(x,endian='little'):
    if endian=='little':
        value = 0
        index = 0
        for b in x:
            value += b<<(8*index)
            index+=1
        return value
    elif endian=='big':
        value = 0
        index = 0
        for b in reversed(x):
            value += b<<(8*index)
            index+=1
        return value
    print("Endianness must be \'big\' or \'little\'")
    return None

def int_to_list(x,bytes=4,endian='little'):
    result = []
    if bytes < 4 or bytes > 8:
        print("bytes must be 4 or 8")
        return None

    for _i in range(bytes):
        byte = x & 0xFF
        # print("i/x/byte: %d/%d/%d" % (i,x,byte))
        result.insert(0, byte)
        x = x >> 8
    if endian == 'little':
        result.reverse()
        return result
    elif endian == 'big':
        return result

    print("Endianness must be \'big\' or \'little\'")
    return None

def decimal_to_list(x, bytes=4, endian='little'):
    x_int = decimal_to_int(x, bytes)
    return int_to_list(x_int, bytes, endian)

def list_to_decimal(x, bytes=4, endian='little'):
    x_int = list_to_int(x, endian=endian)
    # print('x_int: %d' % x_int)
    return int_to_decimal(x_int,bytes)

def int_to_decimal(x, bytes=4):
    if bytes == 4:
        x_bytes = struct.pack('I',x)
        (x_float,) = struct.unpack('f',x_bytes)
    elif bytes == 8:
        x_bytes = struct.pack('Q',x)
        (x_float,) = struct.unpack('d',x_bytes)
    else:
        print("bytes must be 4 or 8")
        return None
    return x_float

def decimal_to_int(x, bytes=4):
    if bytes == 4:
        packed = struct.pack('f', x)
        (x_int,) = struct.unpack('I', packed)
    elif bytes == 8:
        packed = struct.pack('d', x)
        (x_int,) = struct.unpack('Q', packed)
    else:
        print("bytes must be 4 or 8")
        return None
    return x_int