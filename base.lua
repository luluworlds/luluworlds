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

return { str_hex = str_hex }
