import src.comms.operator as op
import src.comms.ublox as ub
import src.common.utils as ut
import pytest

def test_parse_fixed():
    ublox = ub.Ublox()
    header = [0xB5, 0x62]
    preamble = [0x01, 0x01, 0x04, 0]
    value = 1.234567
    payload = ut.decimal_to_list(value, bytes=4)

    chka, chkb = ub.calculate_checksum(payload)
    message = header + preamble + payload + [chka,chkb]
    for byte in message:
        ublox.parse(byte)
        print("parse msd_id: %d" %ublox.msg_id)

    payload = ublox.get_payload()
    pay_value = ut.list_to_decimal(payload, 4)
    assert ublox.msg_id == 1
    assert ublox.msg_class == 1
    assert value == pytest.approx(pay_value, 0.0001)