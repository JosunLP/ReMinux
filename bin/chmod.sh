local args = { ... }

if args[1] == nil or args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: chmod <mode> <path> [path...]")
	print("Modes use three octal digits, for example 644 or 755.")
	return 0
end

if #args < 2 then
	print("chmod: missing operand")
	return 1
end

local mode = args[1]
local status = 0
for index = 2, #args do
	local target = shell.resolve(args[index])
	local ok, err = minux.chmod(target, mode)
	if ok ~= true then
		print("chmod: " .. err)
		status = 1
	end
end

return status
