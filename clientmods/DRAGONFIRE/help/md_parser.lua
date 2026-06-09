-- md_parser: minimal markdown to text converter for formspec display
-- Converts markdown to plain text suitable for display in a textarea.

local M = {}

local function strip_markdown(line)
	-- Remove bold/italic markers
	line = line:gsub("%*%*(.-)%*%*", "%1")
	line = line:gsub("%*(.-)%*", "%1")
	line = line:gsub("__(.-)__", "%1")
	-- Remove inline code backticks
	line = line:gsub("`(.-)`", "%1")
	-- Remove links: [text](url) → text
	line = line:gsub("%[(.-)%]%([^%)]+%)", "%1")
	return line
end

local function count_leading(s, char)
	local count = 0
	for i = 1, #s do
		if s:sub(i, i) == char then
			count = count + 1
		else
			break
		end
	end
	return count
end

function M.to_plaintext(md_text)
	local lines = {}
	local in_code_block = false
	local in_table = false

	for line in md_text:gmatch("[^\n]+") do
		local trimmed = line:match("^%s*(.-)%s*$")

		-- Code blocks
		if trimmed:match("^```") then
			in_code_block = not in_code_block
			if in_code_block then
				table.insert(lines, "")
				table.insert(lines, "  ┌─ code ─────────────────────")
			else
				table.insert(lines, "  └────────────────────────────")
				table.insert(lines, "")
			end
			goto continue
		end
		if in_code_block then
			table.insert(lines, "  │ " .. line)
			goto continue
		end

		-- Skip HTML comments
		if trimmed:match("^<!%-%-") then
			goto continue
		end

		-- Horizontal rule
		if trimmed:match("^[-*_ ]+$") and #trimmed >= 3 then
			table.insert(lines, "  ────────────────────────────")
			goto continue
		end

		-- Headings
		local _, _, hashes, htext = trimmed:find("^(#+)%s*(.-)%s*$")
		if hashes then
			local level = #hashes
			local text = strip_markdown(htext:match("^%s*(.-)%s*$"))
			if level == 1 then
				table.insert(lines, "")
				table.insert(lines, "  " .. string.upper(text))
				table.insert(lines, "  " .. string.rep("═", #text + 2))
				table.insert(lines, "")
			elseif level == 2 then
				table.insert(lines, "")
				table.insert(lines, "  " .. text)
				table.insert(lines, "  " .. string.rep("─", #text + 2))
				table.insert(lines, "")
			else
				table.insert(lines, "    " .. text)
				table.insert(lines, "")
			end
			goto continue
		end

		-- Unordered list items
		local item = trimmed:match("^%s*[-*]%s+(.-)$")
		if item then
			table.insert(lines, "  • " .. strip_markdown(item))
			goto continue
		end

		-- Ordered list items
		local oitem = trimmed:match("^%s*%d+[%.%)]%s+(.-)$")
		if oitem then
			table.insert(lines, "    " .. strip_markdown(oitem))
			goto continue
		end

		-- Table (| ... |)
		if trimmed:match("^|") then
			-- Skip separator rows (| --- | --- |)
			if not trimmed:match("|%s*[-]+%s*|") then
				local cells = {}
				for cell in trimmed:gmatch("|([^|]*)") do
					table.insert(cells, strip_markdown(cell:match("^%s*(.-)%s*$")))
				end
				local row_text = "  " .. table.concat(cells, " │ ")
				table.insert(lines, row_text)
			end
			goto continue
		end

		-- Blank line
		if trimmed == "" then
			table.insert(lines, "")
			goto continue
		end

		-- Regular paragraph text
		local text = strip_markdown(trimmed)
		if #text > 0 then
			-- Word-wrap at ~72 chars
			while #text > 72 do
				local break_at = text:sub(1, 72):match("^.*%s")
				if not break_at then
					break_at = text:sub(1, 72)
				end
				table.insert(lines, "  " .. break_at:match("^%s*(.-)%s*$"))
				text = text:sub(#break_at + 1)
			end
			if #text > 0 then
				table.insert(lines, "  " .. text)
			end
		end

		::continue::
	end

	return table.concat(lines, "\n")
end

-- Parse the ## Cheats table from a markdown text
-- Returns list of {cheat, setting, description}
function M.parse_cheats_table(md_text)
	local results = {}
	local in_cheats_section = false
	local in_table = false

	for line in md_text:gmatch("[^\n]+") do
		local trimmed = line:match("^%s*(.-)%s*$")

		-- Section detection
		if trimmed:match("^##%s+Cheats") then
			in_cheats_section = true
			goto continue
		end
		if in_cheats_section and trimmed:match("^##") then
			-- Next section, stop looking
			break
		end
		if not in_cheats_section then
			goto continue
		end

		-- Skip table header separator (| --- | --- |)
		if trimmed:match("^|%s*[-]+%s*|") then
			goto continue
		end

		-- Parse table row: | Cheat | Setting | Description |
		if trimmed:match("^|") then
			local cells = {}
			for cell in trimmed:gmatch("|([^|]*)") do
				table.insert(cells, cell:match("^%s*(.-)%s*$"))
			end
			if #cells >= 3 then
				local cheat = cells[1]
				local setting = cells[2]
				local desc = cells[3]
				if setting ~= "Setting" and setting ~= "" then
					-- (func) means one-shot cheat without a setting
					if setting == "(func)" then
						setting = nil
					end
					table.insert(results, {
						cheat = cheat,
						setting = setting,
						description = desc,
					})
				end
			end
		end

		::continue::
	end

	return results
end

-- Load embedded README content
local readme_data = dofile(core.get_modpath(core.get_current_modname()) .. "/readmes.lua")

function M.read_readme(modname)
	return readme_data[modname]
end

function M.list_mods()
	local mods = {}
	for modname in pairs(readme_data) do
		table.insert(mods, modname)
	end
	table.sort(mods)
	return mods
end

return M
