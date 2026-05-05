-- touch: create an empty file, or do nothing if it already exists.
local args = { ... }

if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: touch <file> [file...]")
	print("Creates each file as empty if it does not yet exist.")
	return 0
end

local function ensureParent(filepath)
	local parent = fs.getDir(filepath)
	if parent ~= nil and parent ~= "" and fs.exists(parent) == false then
		fs.makeDir(parent)
	end
end

for index = 1, #args do
	local target = shell.resolve(args[index])
	if fs.isDir(target) then
		print("Skipping directory: " .. target)
	elseif fs.exists(target) == false then
		ensureParent(target)
		local handle = fs.open(target, "w")
		if handle ~= nil then handle.close() end
	end
end
