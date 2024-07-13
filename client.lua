--!strict

--
-- apt install lua5.2 lua-socket
--

local socket = require("socket")

local signal = require("posix.signal")
local getch = require("lua-getch")

-- cd huffman
-- sudo luarocks make
local huffman = require("huffman")

local base = require("src/base")
local chunks = require("src/chunks")
local twpacket = require("src/packet")
local bits = require("src/bits")
local packer = require("src/packer")
-- local t = require("src/table")

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

GAME_READY_TO_ENTER = 8


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
		packer.pack_int(teeworlds_client.input.direction) .. -- direction
		packer.pack_int(200) .. -- target x
		packer.pack_int(-200) .. -- target y
		packer.pack_int(teeworlds_client.input.jump) .. -- jump
		packer.pack_int(teeworlds_client.input.fire) .. -- fire
		packer.pack_int(teeworlds_client.input.hook) .. -- hook
		packer.pack_int(0) .. -- player flags
		packer.pack_int(0) .. -- wanted weapon
		packer.pack_int(0) .. -- next weapon
		packer.pack_int(0) .. -- prev weapon
		packer.pack_int(0) -- ping correction
	return build_packet({pack_chunk(teeworlds_client, SYS_INPUT, data, {flags = { vital = false }})})
end

-- @return string
local function enter_game()
	return build_packet({pack_chunk(teeworlds_client, SYS_ENTER_GAME)})
end

local hack_known_sequence_numbers = {}

-- @param msg_id integer
-- @param chunk table
-- @return boolean `true` if the message is known
local function on_game_msg(msg_id, chunk, unpacker)
	if msg_id == GAME_READY_TO_ENTER then
		print("assume this is ready to enter xd")
		assert(teeworlds_client.socket:send(enter_game()))
	else
		return false
	end
	return true
end

local function on_snap(unpacker)
	teeworlds_client.ack_game_tick = packer.get_int(unpacker)
	teeworlds_client.num_received_snapshots = teeworlds_client.num_received_snapshots + 1
	assert(teeworlds_client.socket:send(msg_input()))
end

-- @param msg_id integer
-- @param chunk table
-- @return boolean `true` if the message is known
local function on_system_msg(msg_id, chunk, unpacker)
	if msg_id == SYS_CON_READY then
		print("got motd, server settings and con ready")
		assert(teeworlds_client.socket:send(start_info()))
	elseif msg_id == SYS_SNAP then
		if teeworlds_client.num_received_snapshots < 3 then
			print("oh snap")
		end
		on_snap(unpacker)
	elseif msg_id == SYS_SNAP_EMPTY then
		if teeworlds_client.num_received_snapshots < 3 then
			print("oh snap (empty)")
		end
		on_snap(unpacker)
	elseif msg_id == SYS_SNAP_SINGLE then
		if teeworlds_client.num_received_snapshots < 3 then
			print("oh snap (single)")
		end
		on_snap(unpacker)
	elseif msg_id == SYS_MAP_CHANGE then
		print("got map change sending ready")
		assert(teeworlds_client.socket:send(ready()))
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

	local unpacker = packer.reset(chunk.data)
	local msg_id = packer.get_int(unpacker)
	local sys = bits.bit_and(msg_id, 1) ~= 0
	msg_id = bits.rshift(msg_id, 1)
	-- print("sys=" .. tostring(sys) .. " msg_id=" .. msg_id)

	if sys == true then
		return on_system_msg(msg_id, chunk, unpacker)
	else
		return on_game_msg(msg_id, chunk, unpacker)
	end
end

-- @param data string
local function on_data(data)
	-- print("INCOMING DATA: " .. base.str_hex(data))
	local packet = twpacket.unpack_packet(data)
	-- print(t.print(packet))
	if packet.header.flags.resend == true then
		-- TODO: this is nasty we should actually resend
		--       we drop our own vital packets and decrement the sequence number
		--       so the server thinks it got all the packets and stops requesting resends
		teeworlds_client.sequence = packet.header.ack
	end
	if #data < 8 then
		if packet.header.flags.resend == true then
			print("got resend request packet without payload")
			assert(teeworlds_client.socket:send(build_packet({string.char(CTRL_KEEP_ALIVE)}, true)))
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
			teeworlds_client.server_token = packet.payload:sub(2)
			print("got token: " .. base.str_hex(teeworlds_client.server_token))
			assert(teeworlds_client.socket:send(ctrl_connect()))
		elseif ctrl == CTRL_ACCEPT then
			print("got accept")
			assert(teeworlds_client.socket:send(version_and_password()))
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
			if on_message(msg) == true then
				known = true
			end
		end

		if known == false then
			print("got packet without any known messages sending keepalive")
			assert(teeworlds_client.socket:send(build_packet({string.char(CTRL_KEEP_ALIVE)}, true)))
		end
	end
	-- needed for neovim
	io.flush()
end

local function connect(client, ip, port)
	-- client.socket = assert(socket.udp())

	client.socket:settimeout(1)
	assert(client.socket:setsockname("*", 0))

	print("connecting to " .. ip .. ":" .. port)
	assert(client.socket:setpeername(ip, port))
	assert(client.socket:send(ctrl_msg_token()))
end


local server_ip = "127.0.0.1"
local server_port = 8303

if arg[1] ~= nil then
	local cmd = arg[1]
	if base.str_starts_with(cmd, "connect ") == true then
		local full_ip = base.str_sep(cmd, " ")[2]
		server_ip = base.str_sep(full_ip, ":")[1]
		local port_num = tonumber(base.str_sep(full_ip, ":")[2])
		if port_num == nil then
			print("invalid port")
			os.exit(1)
		end
		server_port = port_num
	else
		print("unknown command " .. cmd)
		os.exit(1)
	end
end
connect(teeworlds_client, server_ip, server_port)

local function on_shutdown()
	io.write("Quitting. Sending disconect ...\n")
	assert(teeworlds_client.socket:send(build_packet({string.char(CTRL_CLOSE)}, true)))

	-- restore old terminal mode
	getch.restore_mode()

	-- enter line-buffered mode
	io.stdin:setvbuf("line")

	-- set blocking mode
	getch.set_nonblocking(io.stdin, false)
end

signal.signal(signal.SIGINT, function(signum)
	on_shutdown()
	os.exit(128 + signum)
end)


-- function love.draw()
--     love.graphics.print("Hello World", 400, 300)
-- end
-- 
-- function love.update(dt)
-- 	teeworlds_client.input.hook = 0
-- 	teeworlds_client.input.jump = 0
-- 	teeworlds_client.input.direction = 0
-- 
-- 	if love.keyboard.isDown("space") then
-- 		print("jump")
-- 		teeworlds_client.input.jump = 1
-- 	end
-- 
-- 	if love.keyboard.isDown('a') then
-- 		print("left")
-- 		teeworlds_client.input.direction = -1
-- 	end
-- 
-- 	if love.keyboard.isDown('d') then
-- 		print("right")
-- 		teeworlds_client.input.direction = 1
-- 	end
-- end

KEY_LEFT = 97
KEY_RIGHT = 100
KEY_SPACE = 32
KEY_W = 119
KEY_S = 115

-- disable buffering through libc
io.stdin:setvbuf("no")

-- set raw(non-linebuffered) mode, disable automatic echo of characters
getch.set_raw_mode(io.stdin)

-- set the non-blocking mode for stdin
getch.set_nonblocking(io.stdin, true)

while true do
	local data = teeworlds_client.socket:receive()
	if data ~= nil then
		on_data(data)
	end

	local char = getch.get_char(io.stdin)

	-- quit on q key
	if (char==("q"):byte()) or (char==("Q"):byte()) then
		on_shutdown()
		break
	end

	teeworlds_client.input.hook = 1
	teeworlds_client.input.jump = 0
	teeworlds_client.input.fire = 0
	teeworlds_client.input.direction = 0

	if char == KEY_LEFT then
		print("left")
		teeworlds_client.input.direction = -1
	end
	if char == KEY_RIGHT then
		print("right")
		teeworlds_client.input.direction = 1
	end
	if char == KEY_SPACE then
		print("jump")
		teeworlds_client.input.jump = 1
	end
	if char == KEY_W then
		print("hook")
		teeworlds_client.input.hook = 0
	end
	if char == KEY_S then
		print("fire")
		teeworlds_client.input.fire = teeworlds_client.input.fire + 1
	end
end
