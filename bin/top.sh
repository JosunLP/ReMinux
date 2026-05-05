-- top: dashboard-style summary of the local computer.
local args = { ... }
if args[1] == "?" or args[1] == "help" then
	print("Usage: top")
	print("Print computer id, label, uptime, free disk space, peripherals.")
	return 0
end

local id    = os.getComputerID()
local label = os.getComputerLabel() or ("computer-" .. id)
local up    = math.floor(os.clock())
local hours = math.floor(up / 3600)
local mins  = math.floor((up % 3600) / 60)
local secs  = up % 60

term.clear()
term.setCursorPos(1, 1)
if term.isColor() then term.setTextColor(colors.yellow) end
print("ReMinux top - " .. os.date("%H:%M:%S"))
if term.isColor() then term.setTextColor(colors.white) end
print(string.rep("-", math.min(40, term.getSize())))
print(string.format("computer  : %s (id %d)", label, id))
print(string.format("uptime    : %02d:%02d:%02d", hours, mins, secs))
print(string.format("in-game   : day %d, time %.2f", os.day(), os.time()))
if _HOST ~= nil then print("host      : " .. _HOST) end

local free = fs.getFreeSpace and fs.getFreeSpace("/") or nil
if free ~= nil then
	if free >= 1024 * 1024 then
		print(string.format("free disk : %.1f MB", free / 1024 / 1024))
	elseif free >= 1024 then
		print(string.format("free disk : %.1f KB", free / 1024))
	else
		print(string.format("free disk : %d B", free))
	end
end

print("")
if term.isColor() then term.setTextColor(colors.lime) end
print("peripherals")
if term.isColor() then term.setTextColor(colors.white) end
if peripheral == nil then
	print("  (peripheral API not available)")
else
	local sides = peripheral.getNames()
	if #sides == 0 then
		print("  (none attached)")
	else
		table.sort(sides)
		for _, side in ipairs(sides) do
			print(string.format("  %-18s %s", side,
				tostring(peripheral.getType(side))))
		end
	end
end

if rednet ~= nil and rednet.isOpen ~= nil then
	print("")
	if term.isColor() then term.setTextColor(colors.lime) end
	print("rednet")
	if term.isColor() then term.setTextColor(colors.white) end
	local found = false
	for _, side in ipairs({ "top", "bottom", "left", "right", "front", "back" }) do
		if rednet.isOpen(side) then
			print("  open on " .. side)
			found = true
		end
	end
	if found == false then print("  (no modems open)") end
end
