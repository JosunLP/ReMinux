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
		local ok = minux.makeDirectory(parent, true)
		if ok ~= true then
			return false
		end
	end
	return true
end

local status = 0
for index = 1, #args do
	local target = shell.resolve(args[index])
	if fs.isDir(target) then
		print("Skipping directory: " .. target)
		status = 1
	elseif fs.exists(target) == false then
		local parentOk = ensureParent(target)
		if parentOk ~= true then
			print("touch: cannot create parent path for " .. target)
			status = 1
		else
			local ok, err = minux.touchPath(target)
			if ok ~= true then
				print("touch: " .. err)
				status = 1
			end
		end
	end
end
return status
