--!strict

--
-- apt install lua5.2 lua-socket
--

local socket = require("socket")

local huffman = require("luluman")

local base = require("luluworlds.base")
local chunks = require("luluworlds.chunks")
local twpacket = require("luluworlds.packet")
local bits = require("luluworlds.bits")
local packer = require("luluworlds.packer")
local Unpacker = require("luluworlds.unpacker")
local connection = require("luluworlds.connection")
-- local t = require("luluworlds.table")

CTRL_KEEP_ALIVE = 0x00
CTRL_CONNECT = 0x01
CTRL_ACCEPT = 0x02
CTRL_CLOSE = 0x04
CTRL_TOKEN = 0x05

SYS_INFO = 1
SYS_MAP_CHANGE = 2
SYS_MAP_DATA = 3
SYS_SERVER_INFO = 4
SYS_CON_READY = 5
SYS_SNAP = 6
SYS_SNAP_EMPTY = 7
SYS_SNAP_SINGLE = 8
SYS_SNAP_SMALL = 9

SYS_ENTER_GAME = string.char(0x27)
SYS_INPUT = string.char(0x29)
SYS_INPUT_TIMING = 10

GAME_SV_CHAT = 3
GAME_READY_TO_ENTER = 8


-- @type table<string, (string | integer)>
local TeeworldsClient = {
	-- 4 byte security token
	-- the servers token
	peer_token = string.char(0xFF, 0xFF, 0xFF, 0xFF),

	-- 4 byte security token
	-- our client token
	token = string.char(0xAA, 0x02, 0x03, 0x04),

	-- the amount of vital chunks sent
	sequence = 0,

	-- the amount of vital chunks received
	ack = 0,

	-- the amount of vital chunks acknowledged by the peer
	peerack = 0,

	-- snapshot stuff
	ack_game_tick = -1,
	num_received_snapshots = 0,

	-- udp socket
	socket = assert(socket.udp()),

	-- teeworlds stuff
	input = {
		direction = 0,
		jump = 0,
		hook = 0,
		fire = 0,
	},
}
TeeworldsClient.__index = TeeworldsClient


function TeeworldsClient.new()
	local self = setmetatable({}, TeeworldsClient)
	return self
end

-- @return string
function TeeworldsClient:ctrl_msg_token()
	local msg = string.char(CTRL_TOKEN) .. self.token
	for _ = 1, 512, 1 do
		msg = msg .. string.char(0x00)
	end
	return connection.build_packet(self, {msg}, true)
end

function TeeworldsClient:ctrl_connect()
	local msg = string.char(CTRL_CONNECT) .. self.token
	for _ = 1, 512, 1 do
		msg = msg .. string.char(0x00)
	end
	return connection.build_packet(self, {msg}, true)
end

function TeeworldsClient:version_and_password()
	self.sequence = self.sequence + 1
	local msg = string.char(
		0x40, 0x28, 0x01, 0x03, 0x30, 0x2E, 0x37, 0x20, 0x38,
		0x30, 0x32, 0x66, 0x31, 0x62, 0x65, 0x36, 0x30, 0x61,
		0x30, 0x35, 0x36, 0x36, 0x35, 0x66, 0x00, 0x6D, 0x79,
		0x5F, 0x70, 0x61, 0x73, 0x73, 0x77, 0x6F, 0x72, 0x64,
		0x5F, 0x31, 0x32, 0x33, 0x00, 0x85, 0x1C, 0x00
	)
	return connection.build_packet(self, {msg})
end

function TeeworldsClient:ready()
	self.sequence = self.sequence + 1
	local msg = string.char(
		0x40, 0x01, 0x02, 0x25
	)
	return connection.build_packet(self, {msg})
end

function TeeworldsClient:start_info()
	self.sequence = self.sequence + 1
	local msg = string.char(
		0x41, 0x19, 0x03, 0x36,
		0x63, 0x69, 0x6c, 0x72, 0x64, 0x72, 0x67, 0x6e, 0x2e, 0x6c, 0x75, 0x61,
		0x00, 0x00, 0x40, 0x73, 0x70, 0x69, 0x6B, 0x79,
		0x00, 0x64, 0x75, 0x6F, 0x64, 0x6F, 0x6E, 0x6E, 0x79, 0x00, 0x00, 0x73,
		0x74, 0x61, 0x6E, 0x64, 0x61, 0x72, 0x64, 0x00, 0x73, 0x74, 0x61, 0x6E,
		0x64, 0x61, 0x72, 0x64, 0x00, 0x73, 0x74, 0x61, 0x6E, 0x64, 0x61, 0x72,
		0x64, 0x00, 0x01, 0x01, 0x00, 0x01, 0x01, 0x01, 0xA0, 0xAC, 0xDD, 0x04,
		0xBD, 0xD2, 0xA9, 0x85, 0x0C, 0x80, 0xFE, 0x07, 0x80, 0xC0, 0xAB, 0x05,
		0x9C, 0xDE, 0xAA, 0x05, 0x9E, 0xC9, 0xE5, 0x01
	)
	return connection.build_packet(self, {msg})
end

-- @return string
function TeeworldsClient:msg_input()
	local data =
		packer.pack_int(self.ack_game_tick) ..
		packer.pack_int(self.ack_game_tick + 1) .. -- prediction tick
		string.char(0x28) ..
		packer.pack_int(self.input.direction) .. -- direction
		packer.pack_int(200) .. -- target x
		packer.pack_int(-200) .. -- target y
		packer.pack_int(self.input.jump) .. -- jump
		packer.pack_int(self.input.fire) .. -- fire
		packer.pack_int(self.input.hook) .. -- hook
		packer.pack_int(0) .. -- player flags
		packer.pack_int(0) .. -- wanted weapon
		packer.pack_int(0) .. -- next weapon
		packer.pack_int(0) .. -- prev weapon
		packer.pack_int(0) -- ping correction
	return connection.build_packet(self, {connection.build_chunk(self, SYS_INPUT, data, {flags = { vital = false }})})
end

-- @return string
function TeeworldsClient:enter_game()
	return connection.build_packet(self, {connection.build_chunk(self, SYS_ENTER_GAME)})
end

local hack_known_sequence_numbers = {}

-- @param msg_id integer
-- @param chunk table
-- @return boolean `true` if the message is known
function TeeworldsClient:on_game_msg(msg_id, _, unpacker)
	if msg_id == GAME_READY_TO_ENTER then
		print("assume this is ready to enter xd")
		assert(self.socket:send(self:enter_game()))
	elseif msg_id == GAME_SV_CHAT then
		local mode = unpacker:get_int()
		local client_id = unpacker:get_int()
		local target_id = unpacker:get_int()
		print("[chat] " .. unpacker:remaining_data())
	else
		return false
	end
	return true
end

function TeeworldsClient:on_snap(unpacker)
	self.ack_game_tick = unpacker:get_int()
	self.num_received_snapshots = self.num_received_snapshots + 1
	assert(self.socket:send(self:msg_input()))
end

-- @param msg_id integer
-- @param chunk table
-- @return boolean `true` if the message is known
function TeeworldsClient:on_system_msg(msg_id, _, unpacker)
	if msg_id == SYS_CON_READY then
		print("got motd, server settings and con ready")
		assert(self.socket:send(self:start_info()))
	elseif msg_id == SYS_SNAP then
		if self.num_received_snapshots < 3 then
			print("oh snap")
		end
		self:on_snap(unpacker)
	elseif msg_id == SYS_SNAP_EMPTY then
		if self.num_received_snapshots < 3 then
			print("oh snap (empty)")
		end
		self:on_snap(unpacker)
	elseif msg_id == SYS_SNAP_SINGLE then
		if self.num_received_snapshots < 3 then
			print("oh snap (single)")
		end
		self:on_snap(unpacker)
	elseif msg_id == SYS_MAP_CHANGE then
		print("got map change sending ready")
		assert(self.socket:send(self:ready()))
	elseif msg_id == SYS_INPUT_TIMING then
		-- who dis? new number
	else
		print("unknown system msg " .. msg_id)
		return false
	end
	return true
end

-- @param chunk table
-- @return boolean `true` if the message is known
function TeeworldsClient:on_message(chunk)
	-- print("got message vital=" .. tostring(chunk.header.flags.vital) .. " size=" .. chunk.header.size .. " data=" .. base.str_hex(chunk.data))
	if chunk.header.flags.vital then
		-- TODO: do not keep all known sequence numbers in a table
		--       that is a full on memory leak!
		if hack_known_sequence_numbers[chunk.header.seq] == nil then
			self.ack = self.ack + 1
		end
		hack_known_sequence_numbers[chunk.header.seq] = true
	end

	local unpacker = Unpacker.new(chunk.data)
	local msg_id = unpacker:get_int()
	local sys = bits.bit_and(msg_id, 1) ~= 0
	msg_id = bits.rshift(msg_id, 1)
	-- print("sys=" .. tostring(sys) .. " msg_id=" .. msg_id)

	if sys == true then
		return self:on_system_msg(msg_id, chunk, unpacker)
	else
		return self:on_game_msg(msg_id, chunk, unpacker)
	end
end

-- @param data string
function TeeworldsClient:on_data(data)
	-- print("INCOMING DATA: " .. base.str_hex(data))
	local packet = twpacket.unpack_packet(data)
	-- print(t.print(packet))
	if packet.header.flags.resend == true then
		-- TODO: this is nasty we should actually resend
		--       we drop our own vital packets and decrement the sequence number
		--       so the server thinks it got all the packets and stops requesting resends
		self.sequence = packet.header.ack
	end
	if #data < 8 then
		if packet.header.flags.resend == true then
			print("got resend request packet without payload")
			assert(self.socket:send(connection.build_packet(self, {string.char(CTRL_KEEP_ALIVE)}, true)))
			return
		end
		print("ignoring too short packet!!!! this should not happen!")
		return
	end
	if packet.header.flags.compression == true then
		packet.payload = huffman.decompress(packet.payload, #packet.payload)
	end

	if data:byte(1) == 0x04 then -- control message
		local ctrl = packet.payload:byte(1)
		print("got ctrl: " .. ctrl)
		if ctrl == CTRL_TOKEN then
			self.peer_token = packet.payload:sub(2)
			print("got token: " .. base.str_hex(self.peer_token))
			assert(self.socket:send(self:ctrl_connect()))
		elseif ctrl == CTRL_ACCEPT then
			print("got accept")
			assert(self.socket:send(self:version_and_password()))
		elseif ctrl == CTRL_CLOSE then
			io.write("got disconnect from server")
			local reason = packet.payload:sub(2)
			if #reason > 0 then
				print(" (" .. packet.payload:sub(2) .. ")")
			else
				print("")
			end
			os.exit(0)
		end
	else -- sys and game messages
		local messages = chunks.get_all_chunks(packet.payload)
		-- print("payload: " .. base.str_hex(packet.payload))
		-- print("messages " .. #messages)
		local known = false
		for _, msg in ipairs(messages) do
			if self:on_message(msg) == true then
				known = true
			end
		end

		if known == false then
			print("got packet without any known messages sending keepalive")
			assert(self.socket:send(connection.build_packet(self, {string.char(CTRL_KEEP_ALIVE)}, true)))
		end
	end
	-- needed for neovim
	io.flush()
end

function TeeworldsClient:connect(ip, port)
	-- client.socket = assert(socket.udp())

	self.socket:settimeout(1)
	assert(self.socket:setsockname("*", 0))

	print("connecting to " .. ip .. ":" .. port)
	assert(self.socket:setpeername(ip, port))
	assert(self.socket:send(self:ctrl_msg_token()))
end

return TeeworldsClient

