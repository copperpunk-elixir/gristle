from enum import Enum

def calculate_checksum(buffer):
	chka = 0
	chkb = 0
	for x in buffer:
		chka = chka + x
		chkb = chkb + chka
		chka = chka & 0xFF
		chkb = chkb & 0xFF
	return chka, chkb

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
			# Logger.debug("msglen: #{msglen)")
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
			self.chka = chka
			self.chkb = chkb
			self.count = count
			self.payload_rev = payload_rev
		elif state == State.PAYLOAD:
			if (byte == self.chka):
				self.state = State.CHKA
			else:
				self.state = State.NONE
		elif state == State.CHKA:
			self.state =State.NONE
			if (byte == self.chkb):
				self.payload_ready = True
			else:
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

