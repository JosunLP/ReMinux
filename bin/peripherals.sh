-- peripherals: list every connected peripheral, its side, type and methods.
local args = { ... }
if args[1] == "?" or args[1] == "help" then
	print("Usage: peripherals [side]")
	print("Without arguments, lists all attached peripherals and types.")
	print("With a side, prints the type and exposed methods of that peripheral.")
	return 0
end

if peripheral == nil then
	print("peripherals: peripheral API not available")
	return 0
end

if args[1] ~= nil and args[1] ~= "" then
	local side = args[1]
	if peripheral.isPresent(side) == false then
		print("peripherals: nothing attached on side '" .. side .. "'")
		return 0
	end
	print("Side    : " .. side)
	print("Type    : " .. tostring(peripheral.getType(side)))
	print("Methods :")
	local methods = peripheral.getMethods(side) or {}
	table.sort(methods)
	for _, name in ipairs(methods) do print("  " .. name) end
	return 0
end

local sides = peripheral.getNames()
if #sides == 0 then
	print("No peripherals attached.")
	return 0
end
table.sort(sides)
print(string.format("%-20s %s", "Side", "Type"))
print(string.rep("-", 40))
for _, side in ipairs(sides) do
	print(string.format("%-20s %s", side, tostring(peripheral.getType(side))))
end
