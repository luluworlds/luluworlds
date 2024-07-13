local bits = require("src/bits")
local base = require("src/base")

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

assert(pack_int(0) == string.char(0))
assert(pack_int(1) == string.char(1))
assert(pack_int(2) == string.char(2))
assert(pack_int(127) == string.char(0xBF, 0x01))
-- -- verified with teeworlds-go
assert(pack_int(-200) == string.char(0xC7, 0x03))

local packer = reset(string.char(0xFF, 0x01))
assert(get_int(packer) == -128)

packer = reset(string.char(0x01, 0x02, 0xFF, 0x01))
assert(get_int(packer) == 1)
assert(get_int(packer) == 2)
assert(get_int(packer) == -128)


return { reset = reset, get_int = get_int, pack_int = pack_int, byte = byte, pop_byte = pop_byte }

