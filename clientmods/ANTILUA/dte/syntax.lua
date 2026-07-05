-- Lua 5.1 syntax highlighter for DTE
-- Returns arrays of display lines with color tags

local keywords = {
	["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
	["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
	["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true,
	["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true,
	["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,
	["while"] = true,
}
local builtins = {
	["print"] = true, ["pcall"] = true, ["loadstring"] = true, ["load"] = true,
	["dofile"] = true, ["loadfile"] = true, ["require"] = true, ["module"] = true,
	["type"] = true, ["pairs"] = true, ["ipairs"] = true, ["next"] = true,
	["tostring"] = true, ["tonumber"] = true, ["unpack"] = true, ["select"] = true,
	["setmetatable"] = true, ["getmetatable"] = true, ["rawget"] = true,
	["rawset"] = true, ["rawequal"] = true, ["error"] = true, ["assert"] = true,
	["collectgarbage"] = true, ["xpcall"] = true, ["self"] = true,
}

local COLORS = {
	keyword = "#569cd6",
	string = "#ce9178",
	comment = "#6a9955",
	number = "#b5cea8",
	builtin = "#c586c0",
	operator = "#d4d4d4",
	identifier = "#dcdcaa",
	punctuation = "#d4d4d4",
	-- Fallback for the line
	keyword_line = "#569cd6",
	comment_line = "#6a9955",
}

-- Determine the primary color for a source line
local function classify_line(line)
	local trimmed = line:match("^%s*(.-)%s*$")
	if not trimmed or trimmed == "" then
		return nil -- empty line, no display
	end

	-- Comment line
	if trimmed:match("^%-%-") then
		return COLORS.comment_line
	end

	-- Keyword-started line
	if trimmed:match("^function ") or trimmed:match("^if ") or trimmed:match("^for ")
		or trimmed:match("^while ") or trimmed:match("^repeat ") or trimmed:match("^do ")
		or trimmed:match("^then$") or trimmed:match("^else$") or trimmed:match("^elseif ")
		or trimmed:match("^end$") or trimmed:match("^end ") or trimmed:match("^local ") or trimmed:match("^return ")
		or trimmed:match("^break$") or trimmed:match("^until ") then
		return COLORS.keyword_line
	end

	return "#d4d4d4" -- default light gray for code
end

-- Extract primary token for a single line
local function tokenize_line(line)
	local tokens = {}
	local i = 1
	while i <= #line do
		local c = line:sub(i, i)
		-- Whitespace
		if c:match("%s") then
			i = i + 1
		-- Short comment
		elseif line:sub(i, i + 1) == "--" and line:sub(i + 2, i + 2) ~= "[" then
			table.insert(tokens, { type = "comment", text = line:sub(i) })
			break
		-- String (double quote)
		elseif c == '"' or c == "'" then
			local quote = c
			local j = i + 1
			local s = quote
			while j <= #line do
				local qc = line:sub(j, j)
				s = s .. qc
				if qc == "\\" then
					j = j + 1
					if j <= #line then
						s = s .. line:sub(j, j)
						j = j + 1
					end
				elseif qc == quote then
					j = j + 1
					break
				else
					j = j + 1
				end
			end
			table.insert(tokens, { type = "string", text = s })
			i = j
		-- Number
		elseif c:match("%d") then
			local j = i
			if line:sub(j, j + 1) == "0" and (line:sub(j + 2, j + 2) == "x" or line:sub(j + 2, j + 2) == "X") then
				j = j + 2
				while line:sub(j, j):match("[0-9a-fA-F]") do j = j + 1 end
			else
				while line:sub(j, j):match("[0-9]") do j = j + 1 end
			end
			if line:sub(j, j) == "." then
				j = j + 1
				while line:sub(j, j):match("[0-9]") do j = j + 1 end
			end
			if line:sub(j, j) == "e" or line:sub(j, j) == "E" then
				j = j + 1
				if line:sub(j, j) == "+" or line:sub(j, j) == "-" then j = j + 1 end
				while line:sub(j, j):match("[0-9]") do j = j + 1 end
			end
			table.insert(tokens, { type = "number", text = line:sub(i, j - 1) })
			i = j
		-- Identifier or keyword
		elseif c:match("[_%a]") then
			local j = i
			while line:sub(j, j):match("[_%w]") do j = j + 1 end
			local word = line:sub(i, j - 1)
			if keywords[word] then
				table.insert(tokens, { type = "keyword", text = word })
			elseif builtins[word] then
				table.insert(tokens, { type = "builtin", text = word })
			else
				table.insert(tokens, { type = "identifier", text = word })
			end
			i = j
		-- Multi-char operators
		elseif line:sub(i, i + 1) == ".." or line:sub(i, i + 1) == "=="
			or line:sub(i, i + 1) == "~=" or line:sub(i, i + 1) == "<="
			or line:sub(i, i + 1) == ">=" then
			table.insert(tokens, { type = "operator", text = line:sub(i, i + 1) })
			i = i + 2
		-- Single-char operators/punctuation
		elseif c:match("[%+%-%*/%^%%#=<>,;:%.%(%)%{%}%[%]]") then
			table.insert(tokens, { type = "punctuation", text = c })
			i = i + 1
		else
			i = i + 1
		end
	end
	return tokens
end

-- Main entry point: colorize Lua source code
-- Returns array of { line = "...", color = "hex" } or nil for empty lines
function colorize(code)
	if not code or code == "" then return {} end

	local lines = {}
	local in_block_comment = false
	local in_long_string = false

	for source_line in code:gmatch("([^\n]*)\n?") do
		if in_block_comment then
			local close = source_line:find("%]%]")
			if close then
				in_block_comment = false
				local rest = source_line:sub(close + 2)
				if rest ~= "" then
					table.insert(lines, { line = rest, color = COLORS.comment })
				end
			end
		elseif in_long_string then
			local close = source_line:find("%]%]")
			if close then
				in_long_string = false
				local rest = source_line:sub(close + 2)
				if rest ~= "" then
					local tokens = tokenize_line(rest)
					local color = classify_line(rest)
					if color then
						table.insert(lines, { line = rest, color = color })
					end
				end
			end
		else
			-- Check for block comment start
			if source_line:find("%-%-%[%[") then
				local before = source_line:match("^(.-)%-%-%[%[")
				if before and before ~= "" then
					table.insert(lines, { line = before, color = classify_line(before) })
				end
				local rest = source_line:match("%-%-%[%[(.*)$")
				if rest:find("%]%]") then
					local comment_text = source_line:match("%-%-%[%[(.-)%]%]")
					if comment_text then
						table.insert(lines, { line = "--[[" .. comment_text .. "]]", color = COLORS.comment })
					end
					local after = source_line:match("%]%](.*)$")
					if after and after ~= "" then
						table.insert(lines, { line = after, color = classify_line(after) })
					end
				else
					table.insert(lines, { line = source_line:match("^(.-)%-%-%[%[") .. "--[[", color = COLORS.comment })
					in_block_comment = true
				end
			elseif source_line:find("%[%[") and not source_line:find('"') and not source_line:find("'") then
				local before = source_line:match("^(.-)%[%[")
				if before and before ~= "" then
					table.insert(lines, { line = before, color = classify_line(before) })
				end
				local rest = source_line:match("%[%[(.*)$")
				if rest:find("%]%]") then
					local str_text = source_line:match("%[%[(.-)%]%]")
					if str_text then
						table.insert(lines, { line = "[[" .. str_text .. "]]", color = COLORS.string })
					end
				else
					in_long_string = true
				end
			else
				local color = classify_line(source_line)
				if color then
					table.insert(lines, { line = source_line, color = color })
				end
			end
		end
	end

	-- Flatten trailing whitespace lines
	local result = {}
	for _, entry in ipairs(lines) do
		if entry.color then
			table.insert(result, { line = entry.line, color = entry.color })
		end
	end

	return result
end
