--!strict

--
-- apt install lua5.2 lua-socket
--

local base = require("./base")
local chunks = require("chunks")
local twpacket = require("packet")

CTRL_KEEP_ALIVE = 0x00
CTRL_CONNECT = 0x01
CTRL_ACCEPT = 0x02
CTRL_CLOSE = 0x04
CTRL_TOKEN = 0x05


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
	peerack = 0
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
	local msg = string.char(
		0x40, 0x01, 0x02, 0x25
	)
	return build_packet({msg})
end

local function start_info()
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

local function enter_game()
	local msg = string.char(
		0x40, 0x01, 0x04, 0x27
	)
	return build_packet({msg})
end

local socket = require("socket")
local udp = assert(socket.udp())

udp:settimeout(1)
assert(udp:setsockname("*", 0))
assert(udp:setpeername("127.0.0.1", 8303))

assert(udp:send(ctrl_msg_token()))

local hack_known_sequence_numbers = {}

-- @param chunk
local function on_message(chunk)
	print("got message vital=" .. tostring(chunk.header.flags.vital) .. " size=" .. chunk.header.size .. " data=" .. base.str_hex(chunk.data))
	if chunk.header.flags.vital then
		-- TODO: do not keep all known sequence numbers in a table
		--       that is a full on memory leak!
		if hack_known_sequence_numbers[chunk.header.seq] == nil then
			teeworlds_client.ack = teeworlds_client.ack + 1
		end
		hack_known_sequence_numbers[chunk.header.seq] = true
	end
end

-- @param data string
local function on_data(data)
	print(base.str_hex(data))
	if #data < 8 then
		print("ignoring too short packet")
		return
	end
	local payload = data:sub(8)
	if data:byte(1) == 0x04 then -- control message
		local ctrl = payload:byte(1)
		print("got ctrl: " .. ctrl)
		if ctrl == CTRL_TOKEN then
			teeworlds_client.server_token = payload:sub(2)
			print("got token: " .. base.str_hex(teeworlds_client.server_token))
			assert(udp:send(ctrl_connect()))
		elseif ctrl == CTRL_ACCEPT then
			print("got accept")
			assert(udp:send(version_and_password()))
		elseif ctrl == CTRL_CLOSE then
			io.write("got disconnect from server")
			local reason = payload:sub(2)
			if #reason > 0 then
				print(" (" .. payload:sub(2) .. ")")
			else
				print("")
			end
			os.exit(0)
		end
	else -- sys and game messages
		local messages = chunks.get_all_chunks(payload)
		print("messages " .. #messages)
		for _, msg in ipairs(messages) do
			on_message(msg)
		end

		local hack_chunk_header = payload:sub(2, 4)
		print("chunk headrer: " .. base.str_hex(hack_chunk_header))
		if hack_chunk_header == string.char(0x3A, 0x01, 0x05) then
			print("got map change sending ready")
			assert(udp:send(ready()))
		elseif  hack_chunk_header == string.char(0x02, 0x02, 0x02) then
			print("got motd, server settings and con ready")
			assert(udp:send(start_info()))
		elseif  hack_chunk_header == string.char(0x01, 0x05, 0x16) then
			print("assume this is ready to enter xd")
			assert(udp:send(enter_game()))
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
