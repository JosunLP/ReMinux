-- dirname: print the directory portion of a path.
local args = { ... }
if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: dirname <path>")
	print("Print the path's parent directory; '.' if no slash is present.")
	return 0
end
local path = args[1]
while #path > 1 and path:sub(-1) == "/" do path = path:sub(1, -2) end
local parent = path:match("^(.*)/[^/]+$")
if parent == nil then
	print(".")
elseif parent == "" then
	print("/")
else
	print(parent)
end
