-- env: print shell aliases, computer environment and important globals.
local args = { ... }
if args[1] == "?" or args[1] == "help" then
	print("Usage: env")
	print("Print Minux/CC environment information and shell aliases.")
	return 0
end

print("# Computer")
print("computer-id=" .. tostring(os.getComputerID()))
print("computer-label=" .. tostring(os.getComputerLabel() or "(unset)"))
if _HOST ~= nil then print("host=" .. _HOST) end
print("lua=" .. (_VERSION or "?"))
local user = _G.login
if user == nil or user == false or user == "" or user == "foo" then
	user = "nobody"
end
print("user=" .. user)
if _G.version ~= nil then print("minux=" .. _G.version) end

print("")
print("# Shell")
print("shell.dir=/" .. shell.dir())
if shell.path ~= nil then print("shell.path=" .. shell.path()) end

print("")
print("# Aliases")
local aliases = shell.aliases()
local names = {}
for name in pairs(aliases) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do
	print(name .. "=" .. aliases[name])
end
