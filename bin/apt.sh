-- apt controller script

local args = { ... }
local command = args[1]
local packageName = args[2]

local commandAliases = {
install = "-i",
remove = "-r",
update = "-u",
["update-forced"] = "-U",
setsource = "-s",
clearsource = "-c",
setupdate = "-a",
["list-installed"] = "-l",
["list-available"] = "-la",
["list-source"] = "-ls",
}

if commandAliases[command] ~= nil then
command = commandAliases[command]
end

local function printResult(success, successMessage, failureMessage)
if success == true then
print(successMessage)
else
print(failureMessage)
end
return success
end

local function runInstall(targetPackage)
if apt.checkinstall(targetPackage) == true then
print("Already installed: "..targetPackage)
return true
end

local result = apt.install(targetPackage)
if result == true then
print("Package installed: "..targetPackage)
return true
end

print("Install failed: "..targetPackage.." E:"..tostring(result))
return false
end

local function runUninstall(targetPackage)
if apt.checkinstall(targetPackage) ~= true then
print("Not installed: "..targetPackage)
return false
end

return printResult(
apt.uninstall(targetPackage),
"Package removed: "..targetPackage,
"Removal failed: "..targetPackage
)
end

local function runUpdate(targetPackage)
local result = apt.update(targetPackage)
return printResult(result == true, "Update complete", "Update failed")
end

if command == "-i" and packageName ~= nil and (_G.admin == true or packageName == "auth-client") then
runInstall(packageName)
elseif command == "-r" and packageName ~= nil and _G.admin == true then
runUninstall(packageName)
elseif command == "-u" and packageName == nil then
runUpdate()
elseif command == "-U" then
runUpdate("-f")
elseif command == "-u" then
runUpdate(packageName)
elseif command == "-s" and packageName ~= nil and _G.admin == true then
printResult(apt.addsource(packageName), "Source added", "Source not added")
elseif command == "-c" and packageName ~= nil and _G.admin == true then
printResult(apt.clearsource(packageName), "Source removed", "Source not removed")
elseif command == "-a" and packageName ~= nil and _G.admin == true then
minux.config("update", packageName)
elseif command == "-ls" then
shell.run("/bin/less.sh /usr/apt/source.ls")
elseif command == "-la" then
if packageName == "--update" or fs.exists("/temp/apt/programs.ls") ~= true then
apt.softlist()
end
shell.run("/bin/less.sh /temp/apt/programs.ls")
elseif command == "-l" then
shell.run("/bin/less.sh /etc/apt/list/installed.db")
elseif command == nil and apt.checkinstall("menu") == true then
shell.run("/etc/minux-main/menu/soft.sys")
else
print("Invalid input or access denied, use 'man apt'")
end

print("Apt: operation complete.")
