local twpacket = require("src/packet")
local chunks = require("src/chunks")

-- @param session TeeworldsClient or TeeworldsServer (table with fields peer_token and ack)
-- @param messages table of strings with fully packed messages (with chunk header)
-- @param control boolean indicating if it is a control packet or not
-- @return string
local function build_packet(session, messages, control)
	if control == nil then
		control = false
	end
	local packet = {
		header = {
			flags = {
				control = control,
				resend = false,
				compression = false,
				connless = false
			},
			num_chunks = 0,
			ack = 0,
			token = string.char(0xff, 0xff, 0xff, 0xff)
		},
		payload = ""
	}
	packet.header.num_chunks = #messages
	if packet.header.flags.control == true then
		packet.header.num_chunks = 0
	end
	packet.header.token = session.peer_token
	packet.header.ack = session.ack

	for _, msg in ipairs(messages) do
		packet.payload = packet.payload .. msg
	end

	return twpacket.pack_packet(packet)
end

-- @param session TeeworldsClient or TeeworldsServer (table with field sequence)
-- @param msg string containing packed msg id and system flag
-- @param payload string message payload without its msg id
-- @param header chunk header table can contain nil values will be auto filled
-- @return string
local function build_chunk(session, msg, payload, header)
	assert(type(session) == "table", "session has to be table")
	assert(type(msg) == "string", "msg has to be string")
	if payload == nil then
		payload = ""
	end
	assert(type(payload) == "string", "payload has to be string")
	local data = msg .. payload
	if header == nil then
		header = {}
	end
	if header.flags == nil then
		header.flags = {
			vital = true,
			resend = false
		}
	end
	if header.flags.vital == true then
		session.sequence = session.sequence + 1
	end
	if header.seq == nil then
		header.seq = session.sequence
	end
	if header.size == nil then
		header.size = #data
	end
	return chunks.pack({header = header, data = data})
end

return { build_packet = build_packet, build_chunk = build_chunk }

