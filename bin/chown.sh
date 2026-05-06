local args = { ... }

if args[1] == nil or args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: chown <owner>[:group] <path> [path...]")
	return 0
end

if #args < 2 then
	print("chown: missing operand")
	return 1
end

local ownerSpec = args[1]
local owner, group = string.match(ownerSpec, "^([^:]+):?(.*)$")
if group == "" then
	group = nil
end

local status = 0
for index = 2, #args do
	local target = shell.resolve(args[index])
	local ok, err = minux.chown(target, owner, group)
	if ok ~= true then
		print("chown: " .. err)
		status = 1
	end
end

return status
