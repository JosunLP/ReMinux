-- mv: move or rename files and directories.
local args = { ... }

if args[1] == nil or args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: mv <source> [source...] <destination>")
	return 0
end

if #args < 2 then
	print("mv: missing operand")
	return 1
end

local destination = shell.resolve(args[#args])
local sources = {}
local status = 0

for index = 1, #args - 1 do
	local matches, err = minux.expandPathPattern(shell.resolve(args[index]))
	if matches == false then
		print("mv: " .. err)
		status = 1
	else
		for _, match in ipairs(matches) do
			sources[#sources + 1] = match
		end
	end
end

if #sources == 0 then
	return status
end

if #sources > 1 and fs.isDir(destination) ~= true then
	print("mv: destination must be an existing directory: " .. destination)
	return 1
end

for _, source in ipairs(sources) do
	local target = destination
	if fs.isDir(destination) == true then
		target = fs.combine(destination, fs.getName(source))
	end
	local ok, err = minux.movePath(source, target)
	if ok ~= true then
		print("mv: " .. err)
		status = 1
	end
end

return status
