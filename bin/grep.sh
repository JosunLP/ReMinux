-- grep: print lines matching a Lua pattern from one or more files.
local args = { ... }

if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: grep [-i] [-n] [-v] <pattern> <file> [file...]")
	print("  -i  case-insensitive match")
	print("  -n  show line numbers")
	print("  -v  invert: show non-matching lines")
	print("Patterns use Lua pattern syntax; escape magic chars with %.")
	return 0
end

local caseInsensitive = false
local showLineNumbers = false
local invertMatch     = false
local cursor = 1
while args[cursor] == "-i" or args[cursor] == "-n" or args[cursor] == "-v" do
	if args[cursor] == "-i" then caseInsensitive = true
	elseif args[cursor] == "-n" then showLineNumbers = true
	elseif args[cursor] == "-v" then invertMatch = true end
	cursor = cursor + 1
end

local pattern = args[cursor]
if pattern == nil then
	print("No pattern given.")
	return 0
end
if caseInsensitive then pattern = string.lower(pattern) end

local files = {}
for i = cursor + 1, #args do files[#files + 1] = args[i] end
if #files == 0 then
	print("No files given.")
	return 0
end

local showFilename = #files > 1

local function searchFile(filepath)
	local target = shell.resolve(filepath)
	if fs.exists(target) == false or fs.isDir(target) then
		print("Not a file: " .. target)
		return
	end
	local handle = fs.open(target, "r")
	local lineNumber = 0
	local line = handle.readLine()
	while line ~= nil do
		lineNumber = lineNumber + 1
		local subject = caseInsensitive and string.lower(line) or line
		local matched = string.find(subject, pattern) ~= nil
		if invertMatch then matched = not matched end
		if matched then
			local prefix = ""
			if showFilename then prefix = target .. ":" end
			if showLineNumbers then prefix = prefix .. lineNumber .. ":" end
			print(prefix .. line)
		end
		line = handle.readLine()
	end
	handle.close()
end

for _, file in ipairs(files) do searchFile(file) end
