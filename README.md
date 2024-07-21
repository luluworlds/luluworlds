# luluworlds

A teeworlds 0.7 client written in lua.

```
sudo apt-get install luarocks
luarocks install luluworlds-scm-0.rockspec
```

```
lua client.lua "connect localhost:8303"
```

## Example usage

```lua
local signal = require("posix.signal")

local client = require("luluworlds.teeworlds_client")
local connection = require("luluworlds.connection")
local network = require("luluworlds.network")

client:connect("127.0.0.1", 8303)

local function on_shutdown()
	io.write("Quitting. Sending disconect ...\n")
	xpcall(
		function ()
			client.socket:send(connection.build_packet(client, {string.char(network.CTRL_CLOSE)}, true))
		end,
		function (err)
			print("failed to disconnect: ", err)
		end
	)
end

signal.signal(signal.SIGINT, function(signum)
	on_shutdown()
	os.exit(128 + signum)
end)

while true do
	local data = client.socket:receive()
	if data ~= nil then
		client:on_data(data)
	end
end
```

## Tests

```
lua spec/*.lua
```

