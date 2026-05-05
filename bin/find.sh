local args = { ... }

local function printUsage()
	print("Usage: find [path] [-name <glob>] [-type f|d] [-maxdepth n]")
end

if args[1] == "?" or args[1] == "help" then
	printUsage()
	return 0
end

local cursor = 1
local startPath = "."
if args[cursor] ~= nil and string.sub(args[cursor], 1, 1) ~= "-" then
	startPath = args[cursor]
	cursor = cursor + 1
end

local options = {
	recursive = true,
	includeHidden = true,
	includeRoot = true,
}

while cursor <= #args do
	local arg = args[cursor]
	if arg == "-name" then
		local value = args[cursor + 1]
		if value == nil or value == "" then
			print("find: missing value for -name")
			return 0
		end
		options.namePattern = value
		cursor = cursor + 2
	elseif arg == "-type" then
		local value = args[cursor + 1]
		if value == "f" then
			options.type = "file"
		elseif value == "d" then
			options.type = "directory"
		else
			print("find: -type expects 'f' or 'd'")
			return 0
		end
		cursor = cursor + 2
	elseif arg == "-maxdepth" then
		local value = tonumber(args[cursor + 1])
		if value == nil or value < 0 then
			print("find: -maxdepth expects a non-negative integer")
			return 0
		end
		options.maxDepth = value
		cursor = cursor + 2
	else
		print("find: unknown option " .. arg)
		printUsage()
		return 0
	end
end

local resolved = shell.resolve(startPath)
if fs.exists(resolved) ~= true then
	print("find: no such path: " .. resolved)
	return 0
end

local results = minux.findEntries(resolved, options)
if results == false then
	print("find: no such path: " .. resolved)
	return 0
end

for _, entry in ipairs(results) do
	minux.writeOutputLine(entry.path)
end
