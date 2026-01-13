-- local t = require("src/table")

local function require_or_nil(module)
	local res = pcall(function ()
		require(module)
	end, module)
	if res then
		return require(module)
	end
	return nil
end

-- @param data string
-- @return string
local function str_hex(data)
	local hex_str = ""
	for i = 1, #data do
		local c = data:sub(i, i)
		hex_str = hex_str .. string.format("%02X ", string.byte(c))
	end
	return hex_str
end

-- @param str string
-- @param sep string
-- @return array
local function str_sep(str, sep)
	local res = {}

	local n = string.find(str, sep)
	if n == nil then
		res[#res+1] = str
		return res
	end
	if #str == 0 then
		return res
	end
	res[#res+1] = str:sub(1, n - 1)
	local remaining = str:sub(1)
	while true do
		remaining = remaining:sub(n + 1)
		n = string.find(remaining, sep)
		if n == nil then
			break
		end
		res[#res+1] = remaining:sub(1, n - 1)
	end
	res[#res+1] = remaining

	return res
end

assert(#str_sep("", "") == 0)
assert(#str_sep("foo", ":") == 1)
assert(#str_sep("foo:bar", ":") == 2)
assert(#str_sep("foo:", ":") == 2)
assert(#str_sep("foo:xaa:baa", ":") == 3)
assert(#str_sep("::", ":") == 3)
assert(str_sep("::", ":")[3] == "")
assert(str_sep("::a", ":")[3] == "a")
assert(str_sep("foo:xaa:baa", ":")[1] == "foo")
assert(str_sep("foo:xaa:baa", ":")[2] == "xaa")
assert(str_sep("foo:xaa:baa", ":")[3] == "baa")
assert(str_sep("connect 127.0.0.1:8303", " ")[2] == "127.0.0.1:8303")
assert(str_sep("127.0.0.1:8303", ":")[1] == "127.0.0.1")
assert(str_sep("127.0.0.1:8303", ":")[2] == "8303")
-- print(t.print(str_sep("foo:xaa:baa", ":")))

-- @param str string
-- @param prefix string
-- @return boolean
local function str_starts_with(str, prefix)
	local n = string.find(str, prefix)
	return n == 1
end
assert(str_starts_with("foo bar", "foo") == true)
assert(str_starts_with("foo bar", "bar") == false)

return {
	str_hex = str_hex,
	str_sep = str_sep,
	str_starts_with = str_starts_with,
	require_or_nil = require_or_nil
}

