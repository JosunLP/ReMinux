-- echo: print the given arguments to standard output, separated by spaces.
local args = { ... }

if args[1] == "?" or args[1] == "help" then
	print("Usage: echo [-n] [text...]")
	print("  -n  do not append a trailing newline")
	return 0
end

local writeNewline = true
local startIndex = 1
if args[1] == "-n" then
	writeNewline = false
	startIndex = 2
end

local pieces = {}
for index = startIndex, #args do
	pieces[#pieces + 1] = tostring(args[index])
end

local out = table.concat(pieces, " ")
if writeNewline then
	print(out)
else
	write(out)
end
