local Unpacker = require("luluworlds.unpacker")

local u = Unpacker.new(string.char(0x01, 0x02, 0xFF, 0x01, ("a"):byte(1), 0x00, ("a"):byte(1), ("b"):byte(1), ("c"):byte(1), 0x00))
assert(u:get_int() == 1)
assert(u:get_int() == 2)
assert(u:get_int() == -128)
assert(u:get_str() == "a")
assert(u:get_str() == "abc")

