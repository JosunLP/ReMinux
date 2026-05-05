-- ReMinux bootloader
shell.run("clear")

-- Determine the installed version from the package manifest.
local VERSION_DB = "/etc/apt/list/minux-main.db"
if fs.exists(VERSION_DB) then
local temp = fs.open(VERSION_DB, "r")
local line = temp.readLine()
while line ~= nil do
if string.find(line, "version=") == 1 then
_G.version = string.sub(line, 9)
break
end
line = temp.readLine()
end
temp.close()
end
if _G.version == nil then _G.version = "Unknown" end

print("Starting ReMinux version: " .. _G.version)
shell.run("/boot/init.sys")
