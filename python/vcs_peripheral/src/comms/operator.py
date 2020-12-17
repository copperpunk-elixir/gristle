import serial
import src.comms.ublox as ublox

MAX_READ_BYTES = 100

class Operator:

    def __init__(self, baud, interface):
        self.baud = baud
        self.interface = interface
        self.serial_port = None
        self.ublox = ublox.Ublox()
        self.x = None
        self.y = None
        self.a = None
        self.b = None

    def open(self):
        print("open %s" % self.interface)
        self.serial_port = serial.Serial(self.interface, self.baud, timeout=0.010)

    def read(self):
        buffer = self.serial_port.read(MAX_READ_BYTES)
        self.parse(buffer)

    def parse(self, buffer):
        for byte in buffer:
            self.ublox.parse(byte)
            if self.ublox.payload_ready:
                # Dispatch message
                self.dispatch_message(self.ublox.msg_class, self.ublox.msg_id, self.ublox.get_payload())
    
    def dispatch_message(self, msg_class, msg_id, payload):
        if msg_class == 0x01:
            if msg_id == 0x02:
                print("received a test message")
                [x, y, a, b] = ublox.deconstruct_message("test", payload)
                self.x = x
                self.y = y
                self.a = a
                self.b = b
    
    def send_list(self, message):
        self.send_byte_array(bytearray(message))

    def send_byte_array(self, message):
        self.serial_port.write(message)
