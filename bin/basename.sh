-- basename: print the trailing name component of a path.
local args = { ... }
if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: basename <path> [suffix]")
	print("Strip directory and optional suffix from the path.")
	return 0
end
local path = args[1]
local suffix = args[2]
-- normalize trailing slashes
while #path > 1 and path:sub(-1) == "/" do path = path:sub(1, -2) end
local name = path:match("([^/]+)$") or path
if suffix ~= nil and suffix ~= "" and #name > #suffix
		and name:sub(- #suffix) == suffix then
	name = name:sub(1, #name - #suffix)
end
print(name)
