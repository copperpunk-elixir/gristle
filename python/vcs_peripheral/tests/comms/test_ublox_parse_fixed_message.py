import src.comms.operator as op
import src.comms.ublox as ub
import src.common.utils as ut
import src.common.math as mt
import pytest
import random

def test_utils():
    decimal_range = 0.000001
    # float
    x = random.uniform(-180, 180)
    # x = 150.34
    x_list = ut.decimal_to_list(x, 4)
    x_float = ut.list_to_decimal(x_list, 4)
    assert x == pytest.approx(x_float, decimal_range)
    # double
    x = random.uniform(-180, 180)
    # x = -150.34
    x_list = ut.decimal_to_list(x, 8)
    print(x_list)
    x_float = ut.list_to_decimal(x_list, 8)
    assert x == pytest.approx(x_float, decimal_range)
    # # uint32
    x = 0xD2C59400
    x_list = ut.int_to_list(x, 4)
    x_u32 = ut.list_to_int(x_list)
    assert x == x_u32
    # int32
    x_list = ut.int_to_list(x, 4)
    x_u32 = ut.list_to_int(x_list)
    x_i32 = mt.convert_from_twos_comp(x_u32,4)
    assert -758803456 == x_i32
    # uint64
    x = 0x92000000D2C59400
    x_list = ut.int_to_list(x,8)
    x_u64 = ut.list_to_int(x_list)
    assert x == x_u64
    # int64
    x_list = ut.int_to_list(x, 8)
    x_u64 = ut.list_to_int(x_list)
    x_i64 = mt.convert_from_twos_comp(x_u64,8)
    assert -7926335340635909120 == x_i64


def test_parse_single_payload():
    ublox = ub.Ublox()
    header = [0xB5, 0x62]
    preamble = [0x01, 0x01, 0x04, 0]
    value = 1.234567
    payload = ut.decimal_to_list(value, bytes=4)

    chka, chkb = ub.calculate_checksum(preamble + payload)
    message = header + preamble + payload + [chka,chkb]
    for byte in message:
        ublox.parse(byte)
        print("parse msd_id: %d" %ublox.msg_id)

    payload = ublox.get_payload()
    pay_value = ut.list_to_decimal(payload, 4)
    assert ublox.msg_id == 1
    assert ublox.msg_class == 1
    assert value == pytest.approx(pay_value, 0.0001)

def test_payload_deconstruct():
    x_pos = 1.2345
    y_neg = -5.4321
    a_u32 = 0xFFFFFFFF
    a_i32 = -1

    msg_type = "test"
    values = [x_pos, y_neg, a_u32, a_i32]
    payload, payload_length = ub.get_payload_and_length(msg_type, values)
    assert payload_length == sum([abs(ele) for ele in ub.get_bytes_for_msg(msg_type)]) 

    values_rx = ub.deconstruct_message(msg_type, payload)

    assert x_pos == pytest.approx(values_rx[0], 0.0001)
    assert y_neg == pytest.approx(values_rx[1], 0.0001)
    assert a_u32 == values_rx[2]
    assert a_i32 == values_rx[3]

def test_message_with_payload():
    msg_class_exp = 0x01
    msg_id_exp = 0x02
    msg_type = "test"
    values = [1.2345, -5.4321, 0xFFFFFFFF, -1]
    msg = ub.construct_message(msg_type, values)
    ub_op = ub.Ublox()
    for byte in msg:
        ub_op.parse(byte)
        if ub_op.payload_ready:
            msg_class = ub_op.msg_class
            msg_id = ub_op.msg_id
            if msg_class == 0x01:
                if msg_id == 0x02:
                    payload = ub_op.get_payload()
                    values_rx = ub.deconstruct_message("test", payload)
    

    assert msg_class == msg_class_exp
    assert msg_id == msg_id_exp
    for index, value in enumerate(values):
        print("{}/{}".format(index, value))
        assert value == pytest.approx(values_rx[index], 0.0001)