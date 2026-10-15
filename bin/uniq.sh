-- uniq: collapse runs of equal adjacent lines (sort the input first).
local args = { ... }
if args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: uniq [-c] [-d] [-u] [file]")
	print("  -c  prefix each line with its occurrence count")
	print("  -d  print only duplicated lines")
	print("  -u  print only lines that are not repeated")
	return 0
end

local showCount, onlyDup, onlyUnique = false, false, false
local files = {}
for _, arg in ipairs(args) do
	if arg == "-c" then showCount = true
	elseif arg == "-d" then onlyDup = true
	elseif arg == "-u" then onlyUnique = true
	else files[#files + 1] = arg end
end

local sources, failed = minux.collectInput("uniq", files, shell.resolve)
if sources == nil then return false end

local previous, count = nil, 0
local function emit()
	if previous == nil then return end
	if onlyDup and count < 2 then return end
	if onlyUnique and count > 1 then return end
	if showCount then
		print(string.format("%4d %s", count, previous))
	else
		print(previous)
	end
end

for _, source in ipairs(sources) do
	for _, line in ipairs(source.lines) do
		if line == previous then
			count = count + 1
		else
			emit()
			previous = line
			count = 1
		end
	end
end
emit()
return not failed
