-- printf: print formatted output (Lua string.format under the hood).
local args = { ... }
if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: printf <format> [arg...]")
	print("Format specifiers follow Lua's string.format (e.g. %d, %s, %.2f).")
	print("Use \\n in <format> to insert a newline.")
	return 0
end

local format = args[1]:gsub("\\n", "\n"):gsub("\\t", "\t")

-- Coerce numeric arguments so %d / %f work without manual conversion.
local converted = {}
for index = 2, #args do
	local raw = args[index]
	local asNumber = tonumber(raw)
	converted[#converted + 1] = asNumber ~= nil and asNumber or raw
end

local ok, result = pcall(string.format, format, table.unpack(converted))
if ok == false then
	print("printf: " .. tostring(result))
	return 0
end
write(result)
