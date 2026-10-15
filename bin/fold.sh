-- fold: wrap each input line at the requested column.
local args = { ... }
if args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: fold [-w <width>] [-s] [file...]")
	print("Wrap lines so they never exceed <width> columns")
	print("(default: the terminal width).")
	print("  -s  break at spaces where possible")
	return 0
end

local width = term.getSize()
local atSpaces = false
local files = {}
local index = 1
while index <= #args do
	local arg = args[index]
	if arg == "-w" then
		width = tonumber(args[index + 1])
		if width == nil then
			print("fold: invalid width: " .. tostring(args[index + 1]))
			return false
		end
		index = index + 2
	elseif arg == "-s" then
		atSpaces = true
		index = index + 1
	else
		files[#files + 1] = arg
		index = index + 1
	end
end
width = math.floor(width)
if width < 1 then
	print("fold: width must be >= 1")
	return false
end

local sources, failed = minux.collectInput("fold", files, shell.resolve)
if sources == nil then return false end

local function foldLine(line)
	if #line <= width then
		print(line)
		return
	end
	while #line > width do
		local cut = width
		if atSpaces then
			local lastSpace = nil
			for position = width, 1, -1 do
				if string.sub(line, position, position) == " " then
					lastSpace = position
					break
				end
			end
			if lastSpace ~= nil then cut = lastSpace end
		end
		print(string.sub(line, 1, cut))
		line = string.sub(line, cut + 1)
	end
	print(line)
end

for _, source in ipairs(sources) do
	for _, line in ipairs(source.lines) do foldLine(line) end
end
return not failed
