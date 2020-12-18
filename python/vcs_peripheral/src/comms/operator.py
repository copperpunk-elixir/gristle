import serial
import serial.tools.list_ports as list_ports
import src.comms.ublox as ublox

MAX_READ_BYTES = 100

class Operator:

    def __init__(self, baud, device_desc):
        device = locate_com_port(device_desc) 
        print("located %s at %s: " %(device_desc, device))
        self.baud = baud
        self.device = device
        self.serial_port = None
        self.ublox = ublox.Ublox()
        self.x = None
        self.y = None
        self.a = None
        self.b = None

    def open(self):
        print("open %s" % self.device)
        self.serial_port = serial.Serial(self.device, self.baud, timeout=0.010)

    def read(self):
        if self.serial_port.in_waiting > 0:
            buffer = self.serial_port.read(MAX_READ_BYTES)
            print("rx: buffer {}".format(buffer))
            self.parse(buffer)

    def parse(self, buffer):
        for byte in buffer:
            self.ublox.parse(byte)
            if self.ublox.payload_ready:
                # Dispatch message
                self.dispatch_message(self.ublox.msg_class, self.ublox.msg_id, self.ublox.get_payload())
                self.ublox.payload_ready = False
    
    def dispatch_message(self, msg_class, msg_id, payload):
        if msg_class == 0x01:
            if msg_id == 0x02:
                print("received a test message")
                [x, y, a, b] = ublox.deconstruct_message("test", payload) # pylint: disable=unbalanced-tuple-unpacking
                self.x = x
                self.y = y
                self.a = a
                self.b = b
        elif msg_class == 0x52:
            if msg_id == 0x00:
                print("rx orbit inline")
                [radius, confirmation] = ublox.deconstruct_message("orbit_inline", payload) # pylint: disable=unbalanced-tuple-unpacking
                print("rad/conf: %f/%d" %(radius, confirmation))
            elif msg_id == 0x01:
                print("rx orbit centered")
                [radius, confirmation] = ublox.deconstruct_message("orbit_centered", payload) # pylint: disable=unbalanced-tuple-unpacking
                print("rad/conf: %f/%d" %(radius, confirmation))
    
    def send_message(self, msg_type, values):
        msg = ublox.construct_message(msg_type, values)
        self.send_list(msg)

    def send_list(self, message):
        self.send_byte_array(bytearray(message))

    def send_byte_array(self, message):
        self.serial_port.write(message)

def locate_com_port(description):
    ports = list_ports.comports()
    description_upper = description.upper()
    for port in ports:
        if port.description.upper().find(description_upper) > -1:
            return port.device
    return None