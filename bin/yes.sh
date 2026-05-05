-- yes: print a string repeatedly. To prevent infinite-loop crashes inside
-- ComputerCraft, an explicit count is required; the GNU 'yes' default of
-- "infinite" is intentionally not supported here.
local args = { ... }
if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: yes <count> [string]")
	print("Print <string> (default 'y') <count> times.")
	print("Note: a count is required to avoid hanging the computer.")
	return 0
end

local count = tonumber(args[1])
if count == nil or count < 0 then
	print("Invalid count: " .. tostring(args[1]))
	return 0
end

local message = "y"
if args[2] ~= nil then
	local pieces = {}
	for index = 2, #args do pieces[#pieces + 1] = args[index] end
	message = table.concat(pieces, " ")
end

for _ = 1, math.floor(count) do
	print(message)
	-- yield once in a while so the event loop stays responsive
	if (_ % 64) == 0 then os.queueEvent("yes_yield") os.pullEvent("yes_yield") end
end
