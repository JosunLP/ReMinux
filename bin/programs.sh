-- programs: list all available programs from /bin and ROM directories.
local OUTPUT_FILE = "/temp/ls/programs.ls"
local TEMP_FILE   = "/temp/ls/files.ls"

local PROGRAM_DIRS = {
"/bin/",
"/rom/programs/",
"/rom/programs/fun/",
}

local function ensureDir(path)
local parent = fs.getDir(path)
if parent ~= nil and parent ~= "" and fs.exists(parent) == false then
fs.makeDir(parent)
end
end

-- Collect all non-directory filenames from a directory into a table.
local function listFiles(dir)
local out = {}
if fs.exists(dir) == false then return out end
local entries = fs.list(dir)
for i = 1, #entries do
if fs.isDir(dir .. entries[i]) == false then
table.insert(out, entries[i])
end
end
return out
end

ensureDir(OUTPUT_FILE)
ensureDir(TEMP_FILE)

local outputFile = fs.open(OUTPUT_FILE, "w")
for _, dir in ipairs(PROGRAM_DIRS) do
local names = listFiles(dir)
for _, name in ipairs(names) do
outputFile.writeLine(name)
end
end
outputFile.close()

-- Print all collected program names.
local readFile = fs.open(OUTPUT_FILE, "r")
local line = readFile.readLine()
while line ~= nil do
write(line .. " ")
line = readFile.readLine()
end
readFile.close()
write("\n")
