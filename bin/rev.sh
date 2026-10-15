-- rev: reverse the characters of every line of files or piped input.
local args = { ... }
if args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: rev [file...]")
	print("Print each line with its characters reversed.")
	return 0
end

local sources, failed = minux.collectInput("rev", args, shell.resolve)
if sources == nil then return false end

for _, source in ipairs(sources) do
	for _, line in ipairs(source.lines) do print(string.reverse(line)) end
end
return not failed
