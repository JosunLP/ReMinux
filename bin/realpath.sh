-- realpath: print the absolute path of the given file or directory.
local args = { ... }
if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: realpath <path>")
	print("Print the absolute (canonical) path of <path>.")
	return 0
end
local resolved = shell.resolve(args[1])
if resolved:sub(1, 1) ~= "/" then resolved = "/" .. resolved end
print(resolved)
