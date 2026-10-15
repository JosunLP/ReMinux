-- tail: print the last N lines (default 10) of files or piped input.
local args = { ... }

if args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: tail [-n <count>] [file...]")
	print("Print the last lines (default 10) of each file or of piped input.")
	return 0
end

local count = 10
local files = {}
local index = 1
while index <= #args do
	local arg = args[index]
	local inline = string.match(arg, "^%-n(%d+)$") or string.match(arg, "^%-(%d+)$")
	if arg == "-n" then
		local parsed = tonumber(args[index + 1])
		if parsed == nil or parsed < 0 then
			print("tail: invalid line count: " .. tostring(args[index + 1]))
			return false
		end
		count = math.floor(parsed)
		index = index + 2
	elseif inline ~= nil then
		count = tonumber(inline)
		index = index + 1
	else
		files[#files + 1] = arg
		index = index + 1
	end
end

local sources, failed = minux.collectInput("tail", files, shell.resolve)
if sources == nil then return false end

for sourceIndex, source in ipairs(sources) do
	if #sources > 1 then
		if sourceIndex > 1 then print("") end
		print("==> " .. source.label .. " <==")
	end
	local lines = source.lines
	for lineIndex = math.max(1, #lines - count + 1), #lines do
		print(lines[lineIndex])
	end
end
return not failed
