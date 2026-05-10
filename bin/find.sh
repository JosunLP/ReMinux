local args = { ... }

local function withColor(color, callback)
	if term.isColor() then term.setTextColor(color) end
	callback()
	if term.isColor() then term.setTextColor(colors.white) end
end

local function isHelpToken(token)
	return token == "help" or token == "-h" or token == "--help" or token == "?"
end

local function printExamples()
	print("Examples:")
	print("  find")
	print("  find /etc -name *.db")
	print("  find /boot -type f")
end

local function printUsage()
	print("Usage: find [path] [-name <glob>] [-type f|d] [-maxdepth n]")
	print("       find help|-h|--help|?   show this message")
end

local function printError(message)
	withColor(colors.red, function()
		print("find: " .. message)
	end)
end

if isHelpToken(args[1]) then
	printUsage()
	printExamples()
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
			printError("missing value for -name")
			print("Hint: use -name <glob> to match file or directory names.")
			printUsage()
			return false
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
			printError("-type expects 'f' or 'd'")
			printUsage()
			return false
		end
		cursor = cursor + 2
	elseif arg == "-maxdepth" then
		local value = tonumber(args[cursor + 1])
		if value == nil or value < 0 then
			printError("-maxdepth expects a non-negative integer")
			printUsage()
			return false
		end
		options.maxDepth = value
		cursor = cursor + 2
	else
		printError("unknown option '" .. arg .. "'")
		printUsage()
		return false
	end
end

local resolved = shell.resolve(startPath)
if fs.exists(resolved) ~= true then
	printError("no such path: " .. resolved)
	print("Hint: use 'find .' to search from the current directory.")
	return false
end

local results = minux.findEntries(resolved, options)
if results == false then
	printError("no such path: " .. resolved)
	return false
end

for _, entry in ipairs(results) do
	minux.writeOutputLine(entry.path)
end
