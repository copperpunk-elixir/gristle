from src.comms.operator import Operator
import src.comms.ublox as ub
import pytest
from time import sleep

def test_open_serial_port():
    baud = 115200
    device_desc = "USB Serial"
    op = Operator(baud, device_desc)
    op.open()

    msg_type = "test"
    values = [1.2345, -5.4321, 0xFFFFFFFF, -1]
    msg = ub.construct_message(msg_type, values)
    op.send_list(msg)
    sleep(0.1)
    op.read()
    assert op.x == pytest.approx(values[0],0.0001)
    assert op.y == pytest.approx(values[1],0.0001)
    assert op.a == values[2]
    assert op.b == values[3]