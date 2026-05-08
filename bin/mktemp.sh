-- mktemp: create a unique temporary file under /tmp.
local args = { ... }
if args[1] == "?" or args[1] == "help" then
	print("Usage: mktemp [template]")
	print("Create an empty unique file under /tmp and print its path.")
	print("If [template] contains 'XXXXXX' it is replaced with random chars.")
	return 0
end

if fs.exists("/tmp") == false then fs.makeDir("/tmp") end

math.randomseed(os.epoch and os.epoch("utc") or os.clock() * 1000)

local function randomTag()
	local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	local pieces = {}
	for _ = 1, 6 do
		local index = math.random(1, #chars)
		pieces[#pieces + 1] = chars:sub(index, index)
	end
	return table.concat(pieces)
end

local template = args[1] or "tmp.XXXXXX"
local path
local tries = 0
repeat
	local name = template
	if name:find("XXXXXX") then
		name = name:gsub("XXXXXX", randomTag())
	else
		name = name .. "." .. randomTag()
	end
	path = "/tmp/" .. name
	tries = tries + 1
until fs.exists(path) == false or tries > 64

if fs.exists(path) then
	print("mktemp: failed to find unique name")
	return false
end

local handle = fs.open(path, "w")
if handle == nil then
	print("mktemp: cannot create file")
	return false
end
handle.close()
print(path)
