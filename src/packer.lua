local bits = require("src/bits")

-- @param data string
-- @return packer table { data, index }
local function reset(data)
	return {
		data = data,
		index = 1
	}
end

-- @param packer table { data, index }
-- @return int
local function byte(packer)
	return packer.data:byte(packer.index)
end

-- @param packer table { data, index }
-- @return int
local function pop_byte(packer)
	local b = packer.data:byte(packer.index)
	packer.index = packer.index + 1
	return b
end

-- @param packer table { data, index }
-- @return int
local function get_int(packer)
	local sign = bits.bit_and(bits.rshift(byte(packer), 6), 1)
	local res = bits.bit_and(byte(packer), 0x3F)

	while true do
		if bits.bit_and(byte(packer), 0x80) == 0 then
			break
		end
		packer.index = packer.index + 1
		res = bits.bit_or(res, bits.lshift(bits.bit_and(byte(packer), 0x7F), 6))

		if bits.bit_and(byte(packer), 0x80) == 0 then
			break
		end
		packer.index = packer.index + 1
		res = bits.bit_or(res, bits.lshift(bits.bit_and(byte(packer), 0x7F), (6 + 7)))

		if bits.bit_and(byte(packer), 0x80) == 0 then
			break
		end
		packer.index = packer.index + 1
		res = bits.bit_or(res, bits.lshift(bits.bit_and(byte(packer), 0x7F), (6 + 7 + 7)))

		if bits.bit_and(byte(packer), 0x80) == 0 then
			break
		end
		packer.index = packer.index + 1
		res = bits.bit_or(res, bits.lshift(bits.bit_and(byte(packer), 0x7F), (6 + 7 + 7 + 7)))
		break
	end

	packer.index = packer.index + 1

	res = bits.bit_xor(res, -sign)
	return res
end

local packer = reset(string.char(0x01, 0x02, 0xff, 0x01))
assert(get_int(packer) == 1)
assert(get_int(packer) == 2)
assert(get_int(packer) == 127)


return { reset = reset, get_int = get_int, byte = byte, pop_byte = pop_byte }

