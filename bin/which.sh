-- which: resolve a command name to the file it would run.
local args = { ... }

if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: which <command>")
	print("Show the alias target or program path for <command>.")
	return 0
end

local name = args[1]
local resolved
if shell.resolveProgram ~= nil then
	resolved = shell.resolveProgram(name)
end

local aliases = shell.aliases and shell.aliases() or {}
local aliasTarget = aliases[name]

if aliasTarget ~= nil then
	print(name .. " -> " .. aliasTarget .. " (alias)")
end

if resolved ~= nil then
	if aliasTarget == nil or resolved ~= aliasTarget then
		print(resolved)
	end
elseif aliasTarget == nil then
	print(name .. ": not found")
end
