-- man: display a manual page using the less viewer.
local args = { ... }
local MAN_DIR = "/etc/man"

local function withColor(color, fn)
	if term.isColor() then term.setTextColor(color) end
	fn()
	if term.isColor() then term.setTextColor(colors.white) end
end

local function topics()
	local names = {}
	if fs.isDir(MAN_DIR) then
		for _, file in ipairs(fs.list(MAN_DIR)) do
			local name = string.match(file, "^(.+)%.man$")
			if name ~= nil then names[#names + 1] = name end
		end
	end
	table.sort(names)
	return names
end

local function printTopics(names)
	if minux.getIoContext() ~= nil then
		for _, name in ipairs(names) do print(name) end
	else
		textutils.pagedTabulate(names)
	end
end

local topic = args[1]

if topic == "?" or topic == "help" or topic == "-h" or topic == "--help" then
	print("Usage: man <topic>      show the manual for <topic>")
	print("       man list         list all manual pages")
	print("       man -k <word>    search manual pages for <word>")
	return 0
end

if topic == nil or topic == "" then
	withColor(colors.red, function() print("man: which manual page do you want?") end)
	print("Try 'man list' for all topics or 'man man' for help.")
	return false
end

if topic == "list" or topic == "-l" then
	printTopics(topics())
	return true
end

if topic == "-k" then
	local needle = args[2]
	if needle == nil or needle == "" then
		print("Usage: man -k <word>")
		return false
	end
	needle = string.lower(needle)
	local found = 0
	for _, name in ipairs(topics()) do
		local lines = minux.readFileLines(fs.combine(MAN_DIR, name .. ".man")) or {}
		for _, line in ipairs(lines) do
			if string.find(string.lower(line), needle, 1, true) then
				print(string.format("%-12s %s", name, (string.gsub(line, "^%s+", ""))))
				found = found + 1
				break
			end
		end
	end
	if found == 0 then
		print("man: nothing appropriate for '" .. args[2] .. "'")
		return false
	end
	return true
end

local manpath = fs.combine(MAN_DIR, topic .. ".man")
if not fs.exists(manpath) then
	withColor(colors.red, function() print("man: no manual entry for '" .. topic .. "'") end)
	local similar = {}
	for _, name in ipairs(topics()) do
		if string.find(name, topic, 1, true) or string.find(topic, name, 1, true) then
			similar[#similar + 1] = name
		end
	end
	if #similar > 0 then
		withColor(colors.lightGray, function()
			print("Did you mean: " .. table.concat(similar, ", ", 1, math.min(#similar, 5)) .. "?")
		end)
	else
		print("Try 'man list' or 'man -k " .. topic .. "'.")
	end
	return false
end

return shell.run("/bin/less.sh", "/" .. manpath)
