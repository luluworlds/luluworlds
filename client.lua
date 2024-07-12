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

local socket = require("socket")
local udp = assert(socket.udp())
local data

udp:settimeout(1)
assert(udp:setsockname("*", 0))
assert(udp:setpeername("127.0.0.1", 8303))

assert(udp:send(ctrl_msg_token()))

while true do
	data = udp:receive()
	print(STR_HEX(data))
	-- control message
	if data:byte(1) == 0x04 then
		local ctrl = data:byte(8)
		if ctrl == CTRL_TOKEN then
			teeworlds_client.server_token = data:sub(9, 12)
			print("got token: " .. STR_HEX(teeworlds_client.server_token))
			assert(udp:send(ctrl_connect()))
		elseif ctrl == CTRL_ACCEPT then
			print("got accept")
			assert(udp:send(version_and_password()))
		end
	end
	break
	-- 04 00 00 01 02 03 04 05 0E 8A 02 01
end
