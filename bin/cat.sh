-- cat: concatenate files (or piped input) and print them.
local args = { ... }

local function isHelpToken(token)
	return token == "?" or token == "help" or token == "-h" or token == "--help"
end

if isHelpToken(args[1]) then
	print("Usage: cat [-n] [-p] [file...]")
	print("Print files (or piped input) to the screen.")
	print("  -n      number every output line")
	print("  -p, p   pause after each screen of output")
	print("Use '-' as a file name to read standard input.")
	return 0
end

local numberLines, paged = false, false
local files = {}
for index, arg in ipairs(args) do
	if arg == "-n" then
		numberLines = true
	elseif arg == "-p" or (arg == "p" and index > 1) then
		-- 'cat <file> p' is the historic ReMinux paging syntax.
		paged = true
	else
		files[#files + 1] = arg
	end
end

local sources, failed = minux.collectInput("cat", files, shell.resolve)
if sources == nil then
	return false
end

-- Paging only makes sense on the real screen, not inside a pipe/redirect.
if minux.getIoContext() ~= nil then paged = false end
local _, height = term.getSize()
local pageSize = math.max(1, height - 2)

local printed, lineNumber = 0, 0
for _, source in ipairs(sources) do
	for _, line in ipairs(source.lines) do
		lineNumber = lineNumber + 1
		if numberLines then
			print(string.format("%6d  %s", lineNumber, line))
		else
			print(line)
		end
		printed = printed + 1
		if paged and printed >= pageSize then
			if term.isColor() then term.setTextColor(colors.gray) end
			write("-- more -- [Enter] next page, [q] quit ")
			if term.isColor() then term.setTextColor(colors.white) end
			local input = read()
			if input == "q" or input == "Q" then
				return not failed
			end
			printed = 0
		end
	end
end
return not failed
