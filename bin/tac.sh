-- tac: print lines of files (or piped input) in reverse order.
local args = { ... }
if args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: tac [file...]")
	print("Print the input with its lines in reverse order.")
	return 0
end

local sources, failed = minux.collectInput("tac", args, shell.resolve)
if sources == nil then return false end

for _, source in ipairs(sources) do
	for index = #source.lines, 1, -1 do print(source.lines[index]) end
end
return not failed
