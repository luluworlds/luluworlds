local p = require("src/packer")

local packer = p.reset(string.char(0x01, 0x02, 0xFF, 0x01, ("a"):byte(1), 0x00, ("a"):byte(1), ("b"):byte(1), ("c"):byte(1), 0x00))
assert(p.get_int(packer) == 1)
assert(p.get_int(packer) == 2)
assert(p.get_int(packer) == -128)
assert(p.get_str(packer) == "a")
assert(p.get_str(packer) == "abc")

assert(p.pack_int(0) == string.char(0))
assert(p.pack_int(1) == string.char(1))
assert(p.pack_int(2) == string.char(2))
assert(p.pack_int(127) == string.char(0xBF, 0x01))
-- -- verified with teeworlds-go
assert(p.pack_int(-200) == string.char(0xC7, 0x03))

packer = p.reset(string.char(0xFF, 0x01))
assert(p.get_int(packer) == -128)

packer = p.reset(string.char(0x01, 0x02, 0xFF, 0x01))
assert(p.get_int(packer) == 1)
assert(p.get_int(packer) == 2)
assert(p.get_int(packer) == -128)

packer = Packer.new(string.char(0x01, 0x02, 0xFF, 0x01, ("a"):byte(1), 0x00, ("a"):byte(1), ("b"):byte(1), ("c"):byte(1), 0x00))
assert(packer:get_int() == 1)
assert(packer:get_int() == 2)
assert(packer:get_int() == -128)
assert(packer:get_str() == "a")
assert(packer:get_str() == "abc")
