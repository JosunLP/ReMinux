-- stat: display metadata about a file or directory.
local args = { ... }
if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: stat <path>")
	print("Print size, type, attributes and (when supported) timestamps.")
	return 0
end

local target = shell.resolve(args[1])
if fs.exists(target) == false then
	print("stat: no such path: " .. target)
	return 0
end

local function fmt(bytes)
	if bytes == nil then return "?" end
	if bytes >= 1024 * 1024 then return string.format("%.1f MB", bytes / 1024 / 1024) end
	if bytes >= 1024 then return string.format("%.1f KB", bytes / 1024) end
	return tostring(bytes) .. " B"
end

local isDir = fs.isDir(target)
print("File   : " .. target)
print("Type   : " .. (isDir and "directory" or "regular file"))
if isDir == false then
	print("Size   : " .. fmt(fs.getSize(target)))
end
if fs.isReadOnly ~= nil then
	print("ReadOnly: " .. tostring(fs.isReadOnly(target)))
end
-- ComputerCraft 1.95+ exposes attributes via fs.attributes.
if fs.attributes ~= nil then
	local ok, attrs = pcall(fs.attributes, target)
	if ok and type(attrs) == "table" then
		if attrs.created  ~= nil then print("Created : " .. attrs.created)  end
		if attrs.modified ~= nil then print("Modified: " .. attrs.modified) end
	end
end
if fs.getDrive ~= nil then
	local ok, drive = pcall(fs.getDrive, target)
	if ok and drive ~= nil then print("Drive  : " .. tostring(drive)) end
end
