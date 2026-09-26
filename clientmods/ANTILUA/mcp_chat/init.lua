-- In-memory chat ring buffer for the MCP server.
-- The MCP server reads the buffer through the Lua pipe via the global
-- mcp_chat table: mcp_chat.recent(n) / mcp_chat.since(i).

local MAX_LINES = 100

local buffer = {}
local counter = 0

local function clean(message)
	-- core.strip_colors removes colour codes but leaves the emphasis
	-- (\x1bF/\x1bE) and translation (\x1b(T@key)) escapes in place; strip
	-- those too so the buffer holds readable text.
	local text = core.strip_colors(message)
	text = text:gsub("\27%((%a+)@[^)]*%)([^%s]*)", "%2")
	text = text:gsub("\27.", "")
	return text
end

local function push(message)
	counter = counter + 1
	buffer[#buffer + 1] = {
		id = counter,
		ts = os.date("%H:%M:%S"),
		text = clean(message),
	}
	if #buffer > MAX_LINES then
		table.remove(buffer, 1)
	end
end

core.register_on_receiving_chat_message(push)

mcp_chat = {
	recent = function(n)
		local out = {}
		local from = math.max(1, #buffer - (n or 20) + 1)
		for i = from, #buffer do
			out[#out + 1] = buffer[i]
		end
		return out
	end,
	since = function(id)
		local out = {}
		for _, line in ipairs(buffer) do
			if line.id > (id or 0) then
				out[#out + 1] = line
			end
		end
		return out
	end,
}
