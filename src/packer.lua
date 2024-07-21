local bits = require("src/bits")

-- @param num integer
-- @return string
local function pack_int(num)
	local res = string.char(0x00)

	if num < 0 then
		res = string.char(0x40)
		num = bits.bit_not(num)
	end

	res = string.char(bits.bit_or(res:byte(1), bits.bit_and(num, 0x3F)))
	num = bits.rshift(num, 6)

	while num > 0
	do
		res = res:sub(1, -2) .. string.char(bits.bit_or(res:sub(-1):byte(1), 0x80))
		res = res .. string.char(bits.bit_and(num, 0x7F))
		num = bits.rshift(num, 7)
	end

	return res
end

return { pack_int = pack_int }

