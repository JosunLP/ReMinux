-- rm: delete files and directories.
local args = { ... }

if args[1] == nil or args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: rm [-r] [-f] <path> [path...]")
	print("  -r  remove directories recursively")
	print("  -f  ignore missing paths")
	return 0
end

local recursive = false
local force = false
local cursor = 1

while args[cursor] ~= nil do
	local arg = args[cursor]
	if arg == "--" then
		cursor = cursor + 1
		break
	elseif arg == "-r" then
		recursive = true
	elseif arg == "-f" then
		force = true
	elseif arg == "-rf" or arg == "-fr" then
		recursive = true
		force = true
	else
		break
	end
	cursor = cursor + 1
end

if args[cursor] == nil then
	print("rm: missing operand")
	return 1
end

local status = 0
for index = cursor, #args do
	local matches, err = minux.expandPathPattern(shell.resolve(args[index]))
	if matches == false then
		if force ~= true then
			print("rm: " .. err)
			status = 1
		end
	else
		for _, path in ipairs(matches) do
			local ok, deleteErr = minux.deletePath(path, recursive)
			if ok ~= true then
				print("rm: " .. deleteErr)
				status = 1
			end
		end
	end
end

return status
