--!strict

--
-- apt install lua5.2 lua-socket
--

CTRL_KEEP_ALIVE = 0x00
CTRL_CONNECT = 0x01
CTRL_ACCEPT = 0x02
CTRL_CLOSE = 0x04
CTRL_TOKEN = 0x05

-- @param data string
-- @return string
function STR_HEX(data)
	local hex_str = ""
	for i = 1, #data do
		local c = data:sub(i, i)
		hex_str = hex_str .. string.format("%02X ", string.byte(c))
	end
	return hex_str
end

local teeworlds_client = {
	server_token = "",
	client_token = string.char(0xAA, 0x02, 0x03, 0x04),
}

-- @return string
local function ctrl_msg_token()
	local msg = string.char(0x04, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0x05) .. teeworlds_client.client_token
	for _ = 1, 512, 1 do
		msg = msg .. string.char(0x00)
	end
	return msg
end

local function ctrl_connect()
	local msg = string.char(0x04, 0x00, 0x00)
	msg = msg .. teeworlds_client.server_token .. string.char(CTRL_CONNECT) .. teeworlds_client.client_token
	for _ = 1, 512, 1 do
		msg = msg .. string.char(0x00)
	end
	return msg
end

local function version_and_password()
	local header = string.char(0x00, 0x00, 0x01) .. teeworlds_client.server_token
	local msg = string.char(
		0x40, 0x28, 0x01, 0x03, 0x30, 0x2E, 0x37, 0x20, 0x38,
		0x30, 0x32, 0x66, 0x31, 0x62, 0x65, 0x36, 0x30, 0x61,
		0x30, 0x35, 0x36, 0x36, 0x35, 0x66, 0x00, 0x6D, 0x79,
		0x5F, 0x70, 0x61, 0x73, 0x73, 0x77, 0x6F, 0x72, 0x64,
		0x5F, 0x31, 0x32, 0x33, 0x00, 0x85, 0x1C, 0x00
	)
	return header .. msg
end

local function ready()
	local header = string.char(0x00, 0x01, 0x01) .. teeworlds_client.server_token
	local msg = string.char(
		0x40, 0x01, 0x02, 0x25
	)
	return header .. msg
end

local function start_info()
	local header = string.char(0x00, 0x04, 0x01) .. teeworlds_client.server_token
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
	return header .. msg
end

local function enter_game()
	local header = string.char(0x00, 0x06, 0x01) .. teeworlds_client.server_token
	local msg = string.char(
		0x40, 0x01, 0x04, 0x27
	)
	return header .. msg
end

local socket = require("socket")
local udp = assert(socket.udp())

udp:settimeout(1)
assert(udp:setsockname("*", 0))
assert(udp:setpeername("127.0.0.1", 8303))

assert(udp:send(ctrl_msg_token()))

local function on_data(data)
	print(STR_HEX(data))
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
			print("got token: " .. STR_HEX(teeworlds_client.server_token))
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
		local hack_chunk_header = payload:sub(2, 4)
		print("chunk headrer: " .. STR_HEX(hack_chunk_header))
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
