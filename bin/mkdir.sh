-- mkdir: create one or more directories.
local args = { ... }

if args[1] == nil or args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: mkdir [-p] <dir> [dir...]")
	print("  -p  ignore existing directories")
	return 0
end

local allowExisting = false
local startIndex = 1
if args[1] == "-p" then
	allowExisting = true
	startIndex = 2
end

if args[startIndex] == nil then
	print("mkdir: missing operand")
	return 1
end

local status = 0
for index = startIndex, #args do
	local target = shell.resolve(args[index])
	local ok, err = minux.makeDirectory(target, allowExisting)
	if ok ~= true then
		print("mkdir: " .. err)
		status = 1
	end
end

return status
