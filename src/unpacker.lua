local bits = require("src/bits")

local Unpacker = {
	data = "",
	index = 1
}
Unpacker.__index = Unpacker

function Unpacker.new(data)
	local self = setmetatable({}, Unpacker)
	self.data = data
	self.index = 1
	return self
end

-- @param data string
-- @return Unpacker
function Unpacker:reset(o, data)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	data = data or ""
	self.data = data
	return o
end

-- @return int
function Unpacker:byte()
	return self.data:byte(self.index)
end

-- @return int
function Unpacker:pop_byte()
	local b = self.data:byte(self.index)
	self.index = self.index + 1
	return b
end

-- @return string
function Unpacker:remaining_data()
	return self.data:sub(self.index)
end

-- @return int
function Unpacker:get_int()
	local sign = bits.bit_and(bits.rshift(self:byte(), 6), 1)
	local res = bits.bit_and(self:byte(), 0x3F)

	while true do
		if bits.bit_and(self:byte(), 0x80) == 0 then
			break
		end
		self.index = self.index + 1
		res = bits.bit_or(res, bits.lshift(bits.bit_and(self:byte(), 0x7F), 6))

		if bits.bit_and(self:byte(), 0x80) == 0 then
			break
		end
		self.index = self.index + 1
		res = bits.bit_or(res, bits.lshift(bits.bit_and(self:byte(), 0x7F), (6 + 7)))

		if bits.bit_and(self:byte(), 0x80) == 0 then
			break
		end
		self.index = self.index + 1
		res = bits.bit_or(res, bits.lshift(bits.bit_and(self:byte(), 0x7F), (6 + 7 + 7)))

		if bits.bit_and(self:byte(), 0x80) == 0 then
			break
		end
		self.index = self.index + 1
		res = bits.bit_or(res, bits.lshift(bits.bit_and(self:byte(), 0x7F), (6 + 7 + 7 + 7)))
		break
	end

	self.index = self.index + 1

	res = bits.bit_xor(res, -sign)
	return res
end

-- @return string
function Unpacker:get_str()
	local e = string.find(self:remaining_data(), string.char(0x00)) + self.index
	local len = e - self.index
	local str = self.data:sub(self.index, self.index + len - 2)
	self.index = self.index + len
	return str
end

return Unpacker

