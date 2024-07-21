local bits = require("luluworlds.bits")

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
		num_chunks = num_chunks + 1

		data = data:sub(chunk_size + 1)
	end
	return chunks
end

return { unpack_header = unpack_header, pack = pack, get_all_chunks = get_all_chunks }

