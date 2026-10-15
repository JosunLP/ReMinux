-- sort: print the lines of files (or piped input) in sorted order.
local args = { ... }
if args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	print("Usage: sort [-r] [-n] [-u] [-f] [file...]")
	print("  -r  reverse order")
	print("  -n  numeric sort (non-numbers sort after numbers)")
	print("  -u  unique (drop duplicates)")
	print("  -f  ignore case")
	return 0
end

local reverse, numeric, unique, foldCase = false, false, false, false
local files = {}
for _, arg in ipairs(args) do
	if string.match(arg, "^%-[rnuf]+$") then
		for flag in string.gmatch(string.sub(arg, 2), ".") do
			if flag == "r" then reverse = true
			elseif flag == "n" then numeric = true
			elseif flag == "u" then unique = true
			elseif flag == "f" then foldCase = true end
		end
	else
		files[#files + 1] = arg
	end
end

local sources, failed = minux.collectInput("sort", files, shell.resolve)
if sources == nil then return false end

local lines = {}
for _, source in ipairs(sources) do
	for _, line in ipairs(source.lines) do lines[#lines + 1] = line end
end

local function key(line)
	return foldCase and string.lower(line) or line
end

-- A strict weak ordering is required by table.sort; mixing numeric and
-- string comparison without a fixed rank raises "invalid order function".
local function lessThan(a, b)
	if numeric then
		local na = tonumber(string.match(a, "^%s*(%-?[%d%.]+)"))
		local nb = tonumber(string.match(b, "^%s*(%-?[%d%.]+)"))
		if na ~= nil and nb ~= nil and na ~= nb then return na < nb end
		if na ~= nil and nb == nil then return true end
		if na == nil and nb ~= nil then return false end
	end
	local ka, kb = key(a), key(b)
	if ka ~= kb then return ka < kb end
	return a < b
end

table.sort(lines, function(a, b)
	if reverse then return lessThan(b, a) end
	return lessThan(a, b)
end)

local previous
for _, line in ipairs(lines) do
	if not unique or previous == nil or key(line) ~= key(previous) then
		print(line)
	end
	previous = line
end
return not failed
