-- cal: print a simple monthly calendar.
local args = { ... }
if args[1] == "?" or args[1] == "help" then
	print("Usage: cal [month [year]]")
	print("Without arguments, prints the current month.")
	return 0
end

local now = os.date("*t")
local month = tonumber(args[1]) or now.month
local year  = tonumber(args[2]) or now.year

if month < 1 or month > 12 then
	print("cal: month must be 1..12")
	return 0
end

local function daysInMonth(m, y)
	if m == 2 then
		local leap = (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
		return leap and 29 or 28
	end
	if m == 4 or m == 6 or m == 9 or m == 11 then return 30 end
	return 31
end

local names = {
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
}

local title = string.format("%s %d", names[month], year)
local pad = math.floor((20 - #title) / 2)
print(string.rep(" ", pad) .. title)
print("Mo Tu We Th Fr Sa Su")

local total = daysInMonth(month, year)
-- weekday of the 1st (Mon=1..Sun=7) using time at 12:00 UTC of that day.
local first = os.time({ year = year, month = month, day = 1, hour = 12 })
local wday = tonumber(os.date("%w", first)) -- 0=Sun..6=Sat
local mondayBased = (wday + 6) % 7 -- 0=Mon..6=Sun

local row = string.rep("   ", mondayBased)
local column = mondayBased
for day = 1, total do
	row = row .. string.format("%2d ", day)
	column = column + 1
	if column == 7 then
		print(row)
		row = ""
		column = 0
	end
end
if row ~= "" then print(row) end
