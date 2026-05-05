-- search: find files on the filesystem by name fragment.
local args     = { ... }
local filename = args[1]

if filename == nil or filename == "" then
print("Usage: search <name>")
return 0
end

local results = minux.findfile(filename)
if results == nil or results[1] == nil then
print("No results found")
return 0
end

if results[1] == "noresult" then
print("No results found")
return 0
end

for index = 1, #results do
local lineNumber = tonumber(results[index])
if lineNumber ~= nil then
local path = minux.printline("/temp/ls/files.ls", lineNumber)
if path ~= nil and path ~= false then
print(path)
end
end
end
