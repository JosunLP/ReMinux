-- nl: number the lines of files or piped input.
local args = { ... }
if args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: nl [-ba] [file...]")
	print("  (default) number only non-empty lines")
	print("  -ba       number all lines, including empty ones")
	return 0
end

local numberAll = false
local files = {}
for _, arg in ipairs(args) do
	if arg == "-ba" then numberAll = true else files[#files + 1] = arg end
end

local sources, failed = minux.collectInput("nl", files, shell.resolve)
if sources == nil then return false end

local lineNumber = 0
for _, source in ipairs(sources) do
	for _, line in ipairs(source.lines) do
		if numberAll or string.match(line, "%S") then
			lineNumber = lineNumber + 1
			print(string.format("%6d  %s", lineNumber, line))
		else
			print("        " .. line)
		end
	end
end
return not failed
