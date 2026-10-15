-- wc: count lines, words and bytes of files or piped input.
local args = { ... }

if args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: wc [-l] [-w] [-c] [file...]")
	print("  -l  show line count")
	print("  -w  show word count")
	print("  -c  show byte count")
	print("Without flags all three counts are shown.")
	return 0
end

local show = { lines = false, words = false, bytes = false }
local files = {}
for _, arg in ipairs(args) do
	if string.match(arg, "^%-[lwc]+$") then
		for flag in string.gmatch(string.sub(arg, 2), ".") do
			if flag == "l" then show.lines = true
			elseif flag == "w" then show.words = true
			elseif flag == "c" then show.bytes = true end
		end
	else
		files[#files + 1] = arg
	end
end
if not show.lines and not show.words and not show.bytes then
	show.lines, show.words, show.bytes = true, true, true
end

local sources, failed = minux.collectInput("wc", files, shell.resolve)
if sources == nil then return false end

local function format(lines, words, bytes, label)
	local parts = {}
	if show.lines then parts[#parts + 1] = string.format("%7d", lines) end
	if show.words then parts[#parts + 1] = string.format("%7d", words) end
	if show.bytes then parts[#parts + 1] = string.format("%7d", bytes) end
	local text = table.concat(parts, " ")
	if label ~= nil then text = text .. " " .. label end
	return text
end

local total = { lines = 0, words = 0, bytes = 0 }
local fromStdin = #files == 0
for _, source in ipairs(sources) do
	local lines, words, bytes = #source.lines, 0, 0
	for _, line in ipairs(source.lines) do
		bytes = bytes + #line + 1 -- count the implicit newline
		for _ in string.gmatch(line, "%S+") do words = words + 1 end
	end
	total.lines = total.lines + lines
	total.words = total.words + words
	total.bytes = total.bytes + bytes
	print(format(lines, words, bytes, (not fromStdin) and source.label or nil))
end

if #sources > 1 then
	print(format(total.lines, total.words, total.bytes, "total"))
end
return not failed
