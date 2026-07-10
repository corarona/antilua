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

		if trimmed:match("^```") then
			in_code_block = not in_code_block
			if in_code_block then
				table.insert(lines, "")
				table.insert(lines, "  ┌─ code ─────────────────────")
			else
				table.insert(lines, "  └────────────────────────────")
				table.insert(lines, "")
			end
		elseif in_code_block then
			table.insert(lines, "  │ " .. line)
		elseif trimmed:match("^<!%-%-") then
		elseif trimmed:match("^[-*_ ]+$") and #trimmed >= 3 then
			table.insert(lines, "  ────────────────────────────")
		elseif trimmed:match("^(#+)%s*(.-)%s*$") then
			local _, _, hashes, htext = trimmed:find("^(#+)%s*(.-)%s*$")
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
		elseif trimmed:match("^%s*[-*]%s+(.-)$") then
			local item = trimmed:match("^%s*[-*]%s+(.-)$")
			table.insert(lines, "  • " .. strip_markdown(item))
		elseif trimmed:match("^%s*%d+[%.%)]%s+(.-)$") then
			local oitem = trimmed:match("^%s*%d+[%.%)]%s+(.-)$")
			table.insert(lines, "    " .. strip_markdown(oitem))
		elseif trimmed:match("^|") then
			if not trimmed:match("|%s*[-]+%s*|") then
				local cells = {}
				for cell in trimmed:gmatch("|([^|]*)") do
					table.insert(cells, strip_markdown(cell:match("^%s*(.-)%s*$")))
				end
				table.insert(lines, "  " .. table.concat(cells, " │ "))
			end
		elseif trimmed == "" then
			table.insert(lines, "")
		else
			local text = strip_markdown(trimmed)
			if #text > 0 then
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
		end
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

		if trimmed:match("^##%s+Cheats") then
			in_cheats_section = true
		elseif in_cheats_section and trimmed:match("^##") then
			break
		elseif in_cheats_section and not trimmed:match("^|%s*[-]+%s*|") and trimmed:match("^|") then
			local cells = {}
			for cell in trimmed:gmatch("|([^|]*)") do
				table.insert(cells, cell:match("^%s*(.-)%s*$"))
			end
			if #cells >= 3 then
				local cheat = cells[1]
				local setting = cells[2]
				local desc = cells[3]
				if setting ~= "Setting" and setting ~= "" then
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

-- Build setting → mod lookup index
local setting_to_mod = {}
local setting_index_built = false

local function build_setting_index()
	if setting_index_built then return end
	setting_index_built = true
	local mods = M.list_mods()
	for _, modname in ipairs(mods) do
		local md = M.read_readme(modname)
		if md then
			local cheats = M.parse_cheats_table(md)
			for _, entry in ipairs(cheats) do
				if entry.setting then
					setting_to_mod[entry.setting] = modname
				end
			end
		end
	end
end

-- Find which mod and section a cheat setting belongs to
function M.find_cheat(setting)
	build_setting_index()
	local modname = setting_to_mod[setting]
	if not modname then return nil end
	return {mod = modname, section = "## Cheats"}
end

-- Search across all READMEs for mods and cheats matching query
function M.search(query)
	if not query or query == "" then return {} end
	local results = {}
	local q = query:lower()
	local mods = M.list_mods()
	for _, modname in ipairs(mods) do
		local md = M.read_readme(modname)
		if md then
			if modname:lower():find(q, 1, true) then
				table.insert(results, {type = "mod", name = modname})
			end
			local cheats = M.parse_cheats_table(md)
			for _, entry in ipairs(cheats) do
				if entry.cheat:lower():find(q, 1, true) or
				   (entry.description and entry.description:lower():find(q, 1, true)) then
					table.insert(results, {type = "cheat", mod = modname,
						name = entry.cheat, setting = entry.setting})
				end
			end
		end
	end
	table.sort(results, function(a, b)
		if a.type ~= b.type then return a.type < b.type end
		return a.name < b.name
	end)
	return results
end

return M
