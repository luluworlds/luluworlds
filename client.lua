--!strict

--
-- apt install lua5.2 lua-socket
--

local socket = require("socket")

-- cd huffman
-- sudo luarocks make
local huffman = require("huffman")

local base = require("src/base")
local chunks = require("src/chunks")
local twpacket = require("src/packet")
local bits = require("src/bits")
local packer = require("src/packer")

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

-- @type table<string, (string | integer)>
local teeworlds_client = {
	-- 4 byte security token
	server_token = string.char(0xFF, 0xFF, 0xFF, 0xFF),

	-- 4 byte security token
	client_token = string.char(0xAA, 0x02, 0x03, 0x04),

	-- the amount of vital chunks sent
	sequence = 0,

	-- the amount of vital chunks received
	ack = 0,

	-- the amount of vital chunks acknowledged by the peer
	peerack = 0,

	-- snapshot stuff
	ack_game_tick = -1
}

-- @param messages table of strings with fully packed messages (with chunk header)
-- @param control boolean indicating if it is a control packet or not
-- @return string
local function build_packet(messages, control)
	if control == nil then
		control = false
	end
	local packet = {
		header = {
			flags = {
				control = control,
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
	packet.header.num_chunks = #messages
	if packet.header.flags.control == true then
		packet.header.num_chunks = 0
	end
	packet.header.token = teeworlds_client.server_token
	packet.header.ack = teeworlds_client.ack

	for _, msg in ipairs(messages) do
		packet.payload = packet.payload .. msg
	end

	return twpacket.pack_packet(packet)
end

-- @return string
local function ctrl_msg_token()
	local msg = string.char(CTRL_TOKEN) .. teeworlds_client.client_token
	for _ = 1, 512, 1 do
		msg = msg .. string.char(0x00)
	end
	return build_packet({msg}, true)
end

local function ctrl_connect()
	local msg = string.char(CTRL_CONNECT) .. teeworlds_client.client_token
	for _ = 1, 512, 1 do
		msg = msg .. string.char(0x00)
	end
	return build_packet({msg}, true)
end

local function version_and_password()
	teeworlds_client.sequence = teeworlds_client.sequence + 1
	local msg = string.char(
		0x40, 0x28, 0x01, 0x03, 0x30, 0x2E, 0x37, 0x20, 0x38,
		0x30, 0x32, 0x66, 0x31, 0x62, 0x65, 0x36, 0x30, 0x61,
		0x30, 0x35, 0x36, 0x36, 0x35, 0x66, 0x00, 0x6D, 0x79,
		0x5F, 0x70, 0x61, 0x73, 0x73, 0x77, 0x6F, 0x72, 0x64,
		0x5F, 0x31, 0x32, 0x33, 0x00, 0x85, 0x1C, 0x00
	)
	return build_packet({msg})
end

local function ready()
	teeworlds_client.sequence = teeworlds_client.sequence + 1
	local msg = string.char(
		0x40, 0x01, 0x02, 0x25
	)
	return build_packet({msg})
end

local function start_info()
	teeworlds_client.sequence = teeworlds_client.sequence + 1
	local msg = string.char(
		0x41, 0x19, 0x03, 0x36, 0x6E, 0x61, 0x6D, 0x65, 0x6C, 0x65, 0x73, 0x73,
		0x20, 0x74, 0x65, 0x65, 0x00, 0x00, 0x40, 0x73, 0x70, 0x69, 0x6B, 0x79,
		0x00, 0x64, 0x75, 0x6F, 0x64, 0x6F, 0x6E, 0x6E, 0x79, 0x00, 0x00, 0x73,
		0x74, 0x61, 0x6E, 0x64, 0x61, 0x72, 0x64, 0x00, 0x73, 0x74, 0x61, 0x6E,
		0x64, 0x61, 0x72, 0x64, 0x00, 0x73, 0x74, 0x61, 0x6E, 0x64, 0x61, 0x72,
		0x64, 0x00, 0x01, 0x01, 0x00, 0x01, 0x01, 0x01, 0xA0, 0xAC, 0xDD, 0x04,
		0xBD, 0xD2, 0xA9, 0x85, 0x0C, 0x80, 0xFE, 0x07, 0x80, 0xC0, 0xAB, 0x05,
		0x9C, 0xDE, 0xAA, 0x05, 0x9E, 0xC9, 0xE5, 0x01
	)
	return build_packet({msg})
end

-- @param client teeworlds_client table
-- @param msg string containing packed msg id and system flag
-- @param payload string message payload without its msg id
-- @param header chunk header table can contain nil values will be auto filled
-- @return string
local function pack_chunk(client, msg, payload, header)
	assert(type(client) == "table", "client has to be table")
	assert(type(msg) == "string", "msg has to be string")
	if payload == nil then
		payload = ""
	end
	assert(type(payload) == "string", "payload has to be string")
	local data = msg .. payload
	if header == nil then
		header = {}
	end
	if header.flags == nil then
		header.flags = {
			vital = true,
			resend = false
		}
	end
	if header.flags.vital == true then
		client.sequence = client.sequence + 1
	end
	if header.seq == nil then
		header.seq = client.sequence
	end
	if header.size == nil then
		header.size = #data
	end
	return chunks.pack({header = header, data = data})
end

-- @return string
local function msg_input()
	local data =
		packer.pack_int(teeworlds_client.ack_game_tick) ..
		packer.pack_int(teeworlds_client.ack_game_tick + 1) .. -- prediction tick
		string.char(0x28) ..
		packer.pack_int(1) .. -- direction
		packer.pack_int(0) .. -- target x
		packer.pack_int(0) .. -- target y
		packer.pack_int(0) .. -- jump
		packer.pack_int(0) .. -- fire
		packer.pack_int(0) .. -- hook
		packer.pack_int(0) .. -- player flags
		packer.pack_int(0) .. -- wanted weapon
		packer.pack_int(0) .. -- next weapon
		packer.pack_int(0) .. -- prev weapon
		packer.pack_int(0) -- ping correction
	return build_packet({pack_chunk(teeworlds_client, SYS_INPUT, data)})
end

-- @return string
local function enter_game()
	return build_packet({pack_chunk(teeworlds_client, SYS_ENTER_GAME)})
end

local udp = assert(socket.udp())

udp:settimeout(1)
assert(udp:setsockname("*", 0))
assert(udp:setpeername("127.0.0.1", 8303))

assert(udp:send(ctrl_msg_token()))

local hack_known_sequence_numbers = {}

-- @param msg_id integer
-- @param chunk table
local function on_game_msg(msg_id, chunk, unpacker)

end

-- @param msg_id integer
-- @param chunk table
local function on_system_msg(msg_id, chunk, unpacker)
	if msg_id == SYS_CON_READY then
		print("XXXXXXXXXXXXXX READY")
	elseif msg_id == SYS_SNAP then
		print("oh snap")
		teeworlds_client.ack_game_tick = packer.get_int(unpacker)
	elseif msg_id == SYS_SNAP_EMPTY then
		print("oh snap (empty)")
		teeworlds_client.ack_game_tick = packer.get_int(unpacker)
	elseif msg_id == SYS_SNAP_SINGLE then
		print("oh snap (single)")
		teeworlds_client.ack_game_tick = packer.get_int(unpacker)
	else
		print("unknown system msg " .. msg_id)
	end
end

-- @param chunk table
local function on_message(chunk)
	-- print("got message vital=" .. tostring(chunk.header.flags.vital) .. " size=" .. chunk.header.size .. " data=" .. base.str_hex(chunk.data))
	if chunk.header.flags.vital then
		-- TODO: do not keep all known sequence numbers in a table
		--       that is a full on memory leak!
		if hack_known_sequence_numbers[chunk.header.seq] == nil then
			teeworlds_client.ack = teeworlds_client.ack + 1
		end
		hack_known_sequence_numbers[chunk.header.seq] = true
	end

	local msg_id = chunk.data:byte(1)
	local sys = bits.bit_and(msg_id, 1) ~= 0
	msg_id = bits.rshift(msg_id, 1)
	-- print("sys=" .. tostring(sys) .. " msg_id=" .. msg_id)
	local unpacker = packer.reset(chunk.data)

	if sys == true then
		on_system_msg(msg_id, chunk, unpacker)
	else
		on_game_msg(msg_id, chunk, unpacker)
	end
end

-- @param data string
local function on_data(data)
	-- print("INCOMING DATA: " .. base.str_hex(data))
	if #data < 8 then
		print("ignoring too short packet")
		return
	end
	local packet = twpacket.unpack_packet(data)
	if packet.header.flags.compression == true then
		packet.payload = huffman.decompress(packet.payload, #packet.payload)
	end

	if data:byte(1) == 0x04 then -- control message
		local ctrl = packet.payload:byte(1)
		print("got ctrl: " .. ctrl)
		if ctrl == CTRL_TOKEN then
			teeworlds_client.server_token = packet.payload:sub(2)
			print("got token: " .. base.str_hex(teeworlds_client.server_token))
			assert(udp:send(ctrl_connect()))
		elseif ctrl == CTRL_ACCEPT then
			print("got accept")
			assert(udp:send(version_and_password()))
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
		for _, msg in ipairs(messages) do
			on_message(msg)
		end

		local hack_chunk_header = packet.payload:sub(2, 4)
		-- print("chunk headrer: " .. base.str_hex(hack_chunk_header))
		if hack_chunk_header == string.char(0x3A, 0x01, 0x05) then
			print("got map change sending ready")
			assert(udp:send(ready()))
		elseif  hack_chunk_header == string.char(0x02, 0x02, 0x02) then
			print("got motd, server settings and con ready")
			assert(udp:send(start_info()))
		elseif  hack_chunk_header == string.char(0x01, 0x05, 0x16) then
			print("assume this is ready to enter xd")
			assert(udp:send(enter_game()))
		else
			-- print("unknown msg just respond with keepalive lmao")
			-- assert(udp:send(build_packet({string.char(CTRL_KEEP_ALIVE)}, true)))
			assert(udp:send(msg_input()))
		end
	end
	-- needed for neovim
	io.flush()
end

while true do
	local data = udp:receive()
	if data ~= nil then
		on_data(data)
	end
end
