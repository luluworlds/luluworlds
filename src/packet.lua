local bits = require("src/bits")
local base = require("src/base")

PACKETFLAG_CONTROL=1
PACKETFLAG_RESEND=2
PACKETFLAG_COMPRESSION=4
PACKETFLAG_CONNLESS=8


-- expects a teeworlds packet as table { header, payload }
-- and returns the packed bytes as string
--
-- @param table
-- @return string
local function pack_packet(packet)
	local data = ""

	local flags_int = 0
	if packet.header.flags.control then
		flags_int = bits.bit_or(flags_int, PACKETFLAG_CONTROL)
	end
	if packet.header.flags.resend then
		flags_int = bits.bit_or(flags_int, PACKETFLAG_RESEND)
	end
	if packet.header.flags.compression then
		flags_int = bits.bit_or(flags_int, PACKETFLAG_COMPRESSION)
	end
	if packet.header.flags.connless then
		flags_int = bits.bit_or(flags_int, PACKETFLAG_CONNLESS)
	end

	local flags = bits.bit_and(bits.lshift(flags_int, 2), 0xFC)
	local ack1 = bits.bit_and(bits.rshift(packet.header.ack, 8), 0x03)
	data = string.char(bits.bit_or(flags, ack1))
	data = data .. string.char(bits.bit_and(packet.header.ack, 0xff))
	data = data .. string.char(bits.bit_and(packet.header.num_chunks, 0xff))
	data = data .. packet.header.token

	return data .. packet.payload
end

-- retruns { header, payload }
-- @param data string
-- @return table
local function unpack_packet(data)
	local packet = {
		header = {
			flags = {
				control = false,
				resend = false,
				compression = false,
				connless = false
			},
			num_chunks = 0,
			ack = 0,
			token = string.char(0xff, 0xff, 0xff, 0xff)
		},
		payload = ""
	}

	local flags = bits.rshift(bits.bit_and(data:byte(1), 0xFC), 2)
	packet.header.flags.control = bits.bit_and(flags, PACKETFLAG_CONTROL) ~= 0
	packet.header.flags.resend = bits.bit_and(flags, PACKETFLAG_RESEND) ~= 0
	packet.header.flags.compression = bits.bit_and(flags, PACKETFLAG_COMPRESSION) ~= 0
	packet.header.flags.connless = bits.bit_and(flags, PACKETFLAG_CONNLESS) ~= 0

	local ack1 = bits.lshift(bits.bit_and(data:byte(1), 0x3), 8)
	local ack2 = data:byte(2)
	packet.header.ack = bits.bit_or(ack1, ack2)
	packet.header.num_chunks = data:byte(3)
	packet.header.token = data:sub(4, 7)
	packet.payload = data:sub(8)

	return packet
end

-- this is a fake packet hand crafted and not a correct teeworlds packet
local packet = unpack_packet(string.char(0x10, 0x00, 0x01, 0xAA, 0xBB, 0xCC, 0xDD, 0x40, 0x01, 0x01, 0x27))
assert(packet.header.token == string.char(0xAA, 0xBB, 0xCC, 0xDD))
assert(packet.header.num_chunks == 1)
assert(packet.header.flags.compression == true)
assert(packet.payload == string.char(0x40, 0x01, 0x01, 0x27))

local data = pack_packet(packet)
print(base.str_hex(data))
assert(data == string.char(0x10, 0x00, 0x01, 0xAA, 0xBB, 0xCC, 0xDD, 0x40, 0x01, 0x01, 0x27))

return { unpack_packet = unpack_packet, pack_packet = pack_packet }

