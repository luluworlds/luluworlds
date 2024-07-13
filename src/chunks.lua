local bits = require("src/bits")
local t = require("src/table")
local base = require("src/base")

CHUNKFLAG_VITAL = 1
CHUNKFLAG_RESEND = 2

-- @param chunk table { header, data }
-- @return string
local function pack(chunk)
	assert(chunk.header, "missing chunk header")
	assert(chunk.data, "missing chunk data")

	-- @type integer[]
	local bytes = {}

	local flags_int = 0
	if chunk.header.flags.vital then
		flags_int = bits.bit_or(flags_int, CHUNKFLAG_VITAL)
	end
	if chunk.header.flags.resend then
		flags_int = bits.bit_or(flags_int, CHUNKFLAG_RESEND)
	end
	local b1 = bits.lshift(bits.bit_and(flags_int, 0x03), 6)
	local b2 = bits.bit_and(bits.rshift(chunk.header.size, 6), 0x3F)
	bytes[#bytes+1] = bits.bit_or(b1, b2)
	bytes[#bytes+1] = bits.bit_and(chunk.header.size, 0x03F)

	if chunk.header.flags.vital == true then
		bytes[#bytes] = bits.bit_or(
			bytes[#bytes],
			bits.bit_and(bits.rshift(chunk.header.seq, 2), 0xC0)
		)
		bytes[#bytes+1] = bits.bit_and(chunk.header.seq, 0xff)
	end

	local res = ""
	for _, byte in ipairs(bytes) do
		res = res .. string.char(byte)
	end
	return res .. chunk.data
end

-- TODO: move tests to spec/ directory
local c1 = {
	header = {
		flags = {
			vital = true,
			resend = false
		},
		size = 2,
		seq = 1
	},
	data = string.char(0xff, 0xff)
}
assert(pack(c1) == string.char(0x40, 0x02, 0x01, 0xFF, 0xFF))

-- @param data string
-- @return table
local function unpack_header(data)
	local header = {
		flags = {
			vital = false,
			resend = false
		},
		size = 0,
		seq = -1
	}

	local flags = bits.bit_and(bits.rshift(data:byte(1), 6), 0x03)
	header.flags.vital = bits.bit_and(flags, CHUNKFLAG_VITAL) ~= 0
	header.flags.resend = bits.bit_and(flags, CHUNKFLAG_RESEND) ~= 0

	local size1 = bits.lshift(bits.bit_and(data:byte(1), 0x3F), 6)
	local size2 = bits.bit_and(data:byte(2), 0x3F)
	header.size = bits.bit_or(size1, size2)

	if header.flags.vital then
		local seq1 = bits.lshift(bits.bit_and(data:byte(2), 0xC0), 2)
		local seq2 = data:byte(3)
		header.seq = bits.bit_or(seq1, seq2)
	end

	return header
end

-- given a teeworlds packet payload it returns
-- a table with all the chunks in it
-- a chunk being represented as { header, data }
--
-- @param data string
-- @return table
local function get_all_chunks(data)
	local chunks = {}
	local num_chunks = 1

	while true
	do
		if #data < 2 then
			break
		end

		local header = unpack_header(data)
		local chunk_size = header.size + 2
		local header_size = 2
		if header.flags.vital then
			chunk_size = chunk_size + 1
			header_size = 3
		end

		chunks[num_chunks] = {
			header = header,
			data = data:sub(header_size + 1, chunk_size)
		}
		-- print("chunk=" .. num_chunks .. "  data=" .. base.str_hex(chunks[num_chunks].data))
		num_chunks = num_chunks + 1

		data = data:sub(chunk_size + 1)
	end

	-- chunks[1] = 2
	-- chunks[2] = 2
	-- chunks[3] = 2


	return chunks
end

assert(#get_all_chunks(string.char(0x00)) == 0)

assert(unpack_header(string.char(0x40, 0x01, 0x01)).flags.vital == true)
assert(unpack_header(string.char(0x40, 0x01, 0x01)).flags.resend == false)
assert(unpack_header(string.char(0x40, 0x01, 0x01)).size == 1)
assert(unpack_header(string.char(0x40, 0x01, 0x01)).seq == 1)

assert(unpack_header(string.char(0x40, 0x03, 0x01)).size == 3)

-- game.sv_vote_clear_options, game.sv_tune_params, game.sv_ready_to_enter
local msg = string.char(
	0x40, 0x01, 0x05, 0x16, 0x41, 0x05, 0x06, 0x0c, 0xa8, 0x0f, 0x88, 0x03, 0x32, 0xa8, 0x14,
	0xb0, 0x12, 0xb4, 0x07, 0x96, 0x02, 0x9f, 0x01, 0xb0, 0xd1, 0x04, 0x80, 0x7d, 0xac, 0x04, 0x9c,
	0x17, 0x32, 0x98, 0xdb, 0x06, 0x80, 0xb5, 0x18, 0x8c, 0x02, 0xbd, 0x01, 0xa0, 0xed, 0x1a, 0x88,
	0x03, 0xbd, 0x01, 0xb8, 0xc8, 0x21, 0x90, 0x01, 0x14, 0xbc, 0x0a, 0xa0, 0x9a, 0x0c, 0x88, 0x03,
	0x80, 0xe2, 0x09, 0x98, 0xea, 0x01, 0xa4, 0x01, 0x00, 0xa4, 0x01, 0xa4, 0x01, 0x40, 0x01, 0x07,
	0x10
)
-- local chunk = get_all_chunks(msg)[1]
-- print(t.print(chunk))
assert(#get_all_chunks(msg) == 3)

return { unpack_header = unpack_header, pack = pack, get_all_chunks = get_all_chunks }

