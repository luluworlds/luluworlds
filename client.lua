--!strict

local signal = require("posix.signal")
local getch = require("lua-getch")

local base = require("luluworlds.base")
local connection = require("luluworlds.connection")
local TeeworldsClient = require("luluworlds.teeworlds_client")
local network = require("luluworlds.network")

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

local client = TeeworldsClient.new()
client:connect(server_ip, server_port)

local function on_shutdown()
	io.write("Quitting. Sending disconect ...\n")

	-- swallow errors
	-- we never want to crash on shutdown that would abort quitting the client
	xpcall(
		function ()
			client.socket:send(connection.build_packet(client, {string.char(network.CTRL_CLOSE)}, true))
		end,
		function (err)
			print("failed to disconnect: ", err)
		end
	)

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
	local data = client.socket:receive()
	if data ~= nil then
		client:on_data(data)
	end

	local char = getch.get_char(io.stdin)

	-- quit on q key
	if (char==("q"):byte()) or (char==("Q"):byte()) then
		on_shutdown()
		break
	end

	client.input.hook = 1
	client.input.jump = 0
	client.input.fire = 0
	client.input.direction = 0

	if char == KEY_LEFT then
		print("left")
		client.input.direction = -1
	end
	if char == KEY_RIGHT then
		print("right")
		client.input.direction = 1
	end
	if char == KEY_SPACE then
		print("jump")
		client.input.jump = 1
	end
	if char == KEY_W then
		print("hook")
		client.input.hook = 0
	end
	if char == KEY_S then
		print("fire")
		client.input.fire = client.input.fire + 1
	end
end
