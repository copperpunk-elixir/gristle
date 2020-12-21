from enum import Enum
import src.common.math as cmath
import src.common.utils as cutils

class State(Enum):
    NONE = 0
    SYNC1 = 1
    SYNC2 = 2
    CLASS = 3
    ID = 4
    LENGTH1 = 5
    LENGTH2 = 6
    PAYLOAD = 7
    CHKA = 8

MAX_PAYLOAD_LENGTH = 1000

class Ublox:
	def __init__(self):
		self.state =  State.NONE
		self.msg_class = -1
		self.msg_id = -1
		self.msg_len = -1
		self.chka = None
		self.chkb = None
		self.count = 0
		self.payload_rev = []
		self.payload_ready = False
		
	def parse(self, byte):
		state = self.state
		# print("state: %d" %state.value)
		if (state == State.NONE) and (byte == 0xB5):
			self.state = State.SYNC1
		elif state == State.SYNC1:
			if (byte == 0x62):
				self.state = State.SYNC2
				self.chka = 0
				self.chkb = 0
				self.payload_rev = []
			else:
				self.state = State.NONE
		elif state == State.SYNC2:
			(chka, chkb) = self.add_to_checksum(byte)
			self.state = State.CLASS
			self.msg_class = byte
			self.chka = chka
			self.chkb = chkb
		elif state == State.CLASS:
			(chka, chkb) = self.add_to_checksum(byte)
			self.state = State.ID
			self.msg_id = byte
			self.chka = chka
			self.chkb = chkb
		elif state == State.ID:
			(chka, chkb) = self.add_to_checksum(byte)
			self.state = State.LENGTH1
			self.msg_len = byte
			self.chka = chka
			self.chkb = chkb
		elif state == State.LENGTH1:
			msglen = self.msg_len + (byte<<8)
			# print("msglen: %d" % msglen)
			if (msglen <= MAX_PAYLOAD_LENGTH):
				(chka, chkb) = self.add_to_checksum(byte)
				self.state =State.LENGTH2
				self.msg_len = msglen
				self.count = 0
				self.chka = chka
				self.chkb = chkb
			else:
				self.state = State.NONE
		elif state == State.LENGTH2:
			(chka, chkb) = self.add_to_checksum(byte)
			payload_rev = [byte] + self.payload_rev
			count = self.count + 1
			if (count == self.msg_len):
				self.state = State.PAYLOAD
				print(payload_rev)	
			self.chka = chka
			self.chkb = chkb
			self.count = count
			self.payload_rev = payload_rev
		elif state == State.PAYLOAD:
			if (byte == self.chka):
				self.state = State.CHKA
			else:
				print("bad chka")
				self.state = State.NONE
		elif state == State.CHKA:
			self.state =State.NONE
			if (byte == self.chkb):
				self.payload_ready = True
			else:
				print("bad chkb")
				self.payload_ready = False
		else:
			# Garbage byte
			print("parse unexpected condition: %d" %self.state.value)
			self.state = State.NONE
		
	def add_to_checksum(self, byte):
		chka = (self.chka + byte) & 0xFF
		chkb = (self.chkb + chka) & 0xFF
		return (chka, chkb)

	def get_payload(self):
		payload = self.payload_rev.copy()
		payload.reverse()
		return payload

def calculate_checksum(buffer):
	chka = 0
	chkb = 0
	for x in buffer:
		chka = chka + x
		chkb = chkb + chka
		chka = chka & 0xFF
		chkb = chkb & 0xFF
	return chka, chkb

def construct_message(msg_type, values):
	(msg_class, msg_id) = get_msg_class_and_id(msg_type)
	payload, payload_length = get_payload_and_length(msg_type, values)
	payload_length_msb = (payload_length >> 8) & 0xFF
	payload_length_lsb = payload_length & 0xFF
	checksum_buffer = [msg_class, msg_id, payload_length_lsb, payload_length_msb] + payload
	chka, chkb = calculate_checksum(checksum_buffer)
	return [0xB5, 0x62] + checksum_buffer + [chka, chkb]

def deconstruct_message(msg_type, payload):
	byte_types = get_bytes_for_msg(msg_type)
	values = []
	remaining_buffer = payload.copy()
	for bytes in byte_types:
		bytes_abs = round(abs(bytes))
		buffer = remaining_buffer[:bytes_abs]
		remaining_buffer = remaining_buffer[bytes_abs:]
		value = cutils.list_to_int(buffer)
		if isinstance(bytes, float):
			value = cutils.int_to_decimal(value, bytes_abs)
		else:
			if bytes < 0:
				value = cmath.convert_from_twos_comp(value, bytes_abs)
		values.append(value)
	return values

def get_payload_and_length(msg_type, values):
	byte_types = get_bytes_for_msg(msg_type)
	payload_length = 0
	payload = []
	for value, bytes in zip(values, byte_types):
		bytes_abs = round(abs(bytes))
		if isinstance(bytes, float):
			value = cutils.decimal_to_int(value, bytes_abs)
		value_list = cutils.int_to_list(value, bytes_abs)	
		payload += value_list
		payload_length += bytes_abs
	return payload, payload_length

msg_type_and_bytes = {
	"orbit_inline": [4.0, 1],
	"orbit_centered": [4.0, 1],
	"orbit_at_location": [4.0, 4.0, 4.0, 4.0, 1],
	"clear_orbit": [1],
	"test": [4.0, 4.0, 4, -4] 
}

msg_class_and_id = {
	"orbit_inline": (0x52, 0x00),
	"orbit_centered": (0x52, 0x01),
	"orbit_at_location": (0x52, 0x02),
	"clear_orbit": (0x52, 0x03),
	"test": (0x01, 0x02)
}

def get_bytes_for_msg(msg_type):
	return msg_type_and_bytes[msg_type]

def get_msg_class_and_id(msg_type):
	return msg_class_and_id[msg_type]
