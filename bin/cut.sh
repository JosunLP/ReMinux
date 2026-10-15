-- cut: extract sections from each line of files or piped input.
local args = { ... }
if args[1] == nil or args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage:")
	print("  cut -c <ranges> [file...]           by character position")
	print("  cut -d <delim> -f <ranges> [file...] by delimited field")
	print("Ranges are comma-separated: N, N-M, -M or N-.")
	print("The default field delimiter is a tab.")
	return 0
end

local mode, spec, delim
local files = {}
local index = 1
while index <= #args do
	local token = args[index]
	local flag, inline = string.match(token, "^%-([cfd])(.+)$")
	if token == "-c" or token == "-f" or token == "-d" then
		flag, inline = string.sub(token, 2), args[index + 1]
		index = index + 2
	elseif flag ~= nil then
		index = index + 1
	else
		files[#files + 1] = token
		index = index + 1
	end
	if flag == "c" then mode, spec = "char", inline
	elseif flag == "f" then mode, spec = "field", inline
	elseif flag == "d" then delim = inline end
end

if mode == nil or spec == nil or spec == "" then
	print("cut: you must specify -c or -f with a list of ranges")
	return false
end
if delim == nil or delim == "" then delim = "\t" end
delim = string.sub(delim, 1, 1)

local ranges = {}
for piece in string.gmatch(spec, "[^,]+") do
	local from, to = string.match(piece, "^(%d*)%-(%d*)$")
	if from ~= nil then
		ranges[#ranges + 1] = { from = tonumber(from) or 1, to = tonumber(to) }
	elseif tonumber(piece) ~= nil then
		ranges[#ranges + 1] = { from = tonumber(piece), to = tonumber(piece) }
	else
		print("cut: invalid range: " .. piece)
		return false
	end
end

local function selected(position)
	for _, range in ipairs(ranges) do
		if position >= range.from and (range.to == nil or position <= range.to) then
			return true
		end
	end
	return false
end

-- Plain split that keeps empty fields ("a,,b" has three fields).
local function split(line)
	local fields = {}
	local start = 1
	while true do
		local found = string.find(line, delim, start, true)
		if found == nil then
			fields[#fields + 1] = string.sub(line, start)
			return fields
		end
		fields[#fields + 1] = string.sub(line, start, found - 1)
		start = found + 1
	end
end

local sources, failed = minux.collectInput("cut", files, shell.resolve)
if sources == nil then return false end

for _, source in ipairs(sources) do
	for _, line in ipairs(source.lines) do
		local pieces = {}
		if mode == "char" then
			for position = 1, #line do
				if selected(position) then pieces[#pieces + 1] = string.sub(line, position, position) end
			end
			print(table.concat(pieces))
		else
			local fields = split(line)
			if #fields == 1 then
				-- Lines without a delimiter are printed unchanged, like GNU cut.
				print(line)
			else
				for position, field in ipairs(fields) do
					if selected(position) then pieces[#pieces + 1] = field end
				end
				print(table.concat(pieces, delim))
			end
		end
	end
end
return not failed
