-- tr: translate or delete characters of files or piped input.
local args = { ... }
if args[1] == nil or args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: tr <set1> <set2> [file...]")
	print("       tr -d <set1> [file...]")
	print("Replace each char of <set1> with the matching char of <set2>,")
	print("or delete them with -d. Ranges like a-z are supported.")
	return 0
end

local deleteMode = args[1] == "-d"
local cursor = deleteMode and 2 or 1

-- Expand "a-z" style ranges into the full character list.
local function expand(set)
	local chars = {}
	local index = 1
	while index <= #set do
		local first = string.sub(set, index, index)
		local dash = string.sub(set, index + 1, index + 1)
		local last = string.sub(set, index + 2, index + 2)
		if dash == "-" and last ~= "" and string.byte(last) >= string.byte(first) then
			for code = string.byte(first), string.byte(last) do
				chars[#chars + 1] = string.char(code)
			end
			index = index + 3
		else
			chars[#chars + 1] = first
			index = index + 1
		end
	end
	return chars
end

local set1 = args[cursor]
local set2
if not deleteMode then
	set2 = args[cursor + 1]
	cursor = cursor + 2
else
	cursor = cursor + 1
end
if set1 == nil or set1 == "" or (not deleteMode and (set2 == nil or set2 == "")) then
	print("tr: missing character set")
	return false
end

local files = {}
for index = cursor, #args do files[#files + 1] = args[index] end

local from = expand(set1)
local mapping = {}
if deleteMode then
	for _, char in ipairs(from) do mapping[char] = "" end
else
	local to = expand(set2)
	for index, char in ipairs(from) do
		mapping[char] = to[math.min(index, #to)]
	end
end

local sources, failed = minux.collectInput("tr", files, shell.resolve)
if sources == nil then return false end

for _, source in ipairs(sources) do
	for _, line in ipairs(source.lines) do
		print((string.gsub(line, ".", function(char) return mapping[char] end)))
	end
end
return not failed
