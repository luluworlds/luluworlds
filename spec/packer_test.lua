local p = require("luluworlds.packer")

assert(p.pack_int(0) == string.char(0))
assert(p.pack_int(1) == string.char(1))
assert(p.pack_int(2) == string.char(2))
assert(p.pack_int(127) == string.char(0xBF, 0x01))
-- -- verified with teeworlds-go
assert(p.pack_int(-200) == string.char(0xC7, 0x03))

