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
version = "-v",
status = "-v",
help = "help",
["-h"] = "help",
["--help"] = "help",
["?"] = "help",
}

if commandAliases[command] ~= nil then
command = commandAliases[command]
end

local function withColor(color, callback)
if term.isColor() then term.setTextColor(color) end
callback()
if term.isColor() then term.setTextColor(colors.white) end
end

local function err(message)
withColor(colors.red, function()
print("apt: " .. message)
end)
end

local function ok(message)
withColor(colors.green, function()
print(message)
end)
end

local function printHelp()
print("Usage: apt <command> [package]")
print("")
print("Package commands:")
print("  -i, install        install a package (admin)")
print("  -r, remove         remove a package (admin)")
print("  -u, update [pkg]   update one package, or all if omitted")
print("  -U, update-forced  force-update everything (admin)")
print("  -v, version [pkg]  show version info for a package")
print("")
print("Sources & lists:")
print("  -s, setsource      add an apt source (admin)")
print("  -c, clearsource    remove an apt source (admin)")
print("  -ls, list-source   show active sources")
print("  -la, list-available [--update]  list packages")
print("  -l, list-installed list installed packages")
print("  -a, setupdate      configure auto-update (admin)")
print("")
print("See 'man apt' for details and locations.")
end

local function requireAdmin(commandLabel)
if _G.admin == true then return true end
err("'" .. commandLabel .. "' requires admin privileges")
print("Hint: log in as an admin/owner with 'login'.")
return false
end

local function requirePackage(commandLabel)
if packageName ~= nil and packageName ~= "" then return true end
err("'" .. commandLabel .. "' needs a package name")
print("Usage: apt " .. commandLabel .. " <package>")
return false
end

local function printResult(success, successMessage, failureMessage)
if success == true then
ok(successMessage)
return true
end
err(failureMessage)
return false
end

local function runInstall(targetPackage)
if apt.checkinstall(targetPackage) == true then
print("Already installed: " .. targetPackage)
return true
end

local result = apt.install(targetPackage)
if result == true then
ok("Package installed: " .. targetPackage)
return true
end

err("install failed for '" .. targetPackage .. "' (E:" .. tostring(result) .. ")")
return false
end

local function runUninstall(targetPackage)
if apt.checkinstall(targetPackage) ~= true then
err("not installed: " .. targetPackage)
return false
end
local result, errorCode = apt.uninstall(targetPackage)
if result == true then
ok("Package removed: " .. targetPackage)
return true
end
if errorCode ~= nil then
err("removal failed for '" .. targetPackage .. "' (E:" .. tostring(errorCode) .. ")")
else
err("removal failed for '" .. targetPackage .. "'")
end
return false
end

local function runUpdate(targetPackage)
local result = apt.update(targetPackage)
if result == true then
ok("Update complete")
return true
end
err("update failed (E:" .. tostring(result) .. ")")
return false
end

local function describeLookupError(errorCode)
if errorCode == 102 then
return "no package sources configured"
elseif errorCode == 105 then
return "package not found"
elseif errorCode == 111 then
return "source unavailable"
end
return tostring(errorCode)
end

local function runVersion(targetPackage)
local info = apt.packageinfo(targetPackage)
if type(info) ~= "table" then
err("version lookup failed")
return false
end

print("Package: " .. tostring(info.package))
print("Installed: " .. tostring(info.installed))
print("Installed version: " .. tostring(info.installedVersion or "unknown"))
print("Available version: " .. tostring(info.availableVersion or "unknown"))
if info.releaseTracking == true then
if info.releaseStatus == "ok" then
print("Latest GitHub release: " .. tostring(info.releaseTag))
elseif info.releaseStatus == "none" then
print("Latest GitHub release: none")
elseif info.releaseStatus == "error" then
print("Latest GitHub release: unavailable")
end
end
if info.source ~= nil then
print("Source: " .. info.source)
end
if info.error ~= nil then
err("lookup error: " .. describeLookupError(info.error))
return false
end
return true
end

-- Dispatch.
local success = false

if command == "help" then
printHelp()
return true

elseif command == nil then
if apt.checkinstall("menu") == true then
shell.run("/etc/minux-main/menu/soft.sys")
return true
end
err("missing command")
printHelp()
return false

elseif command == "-i" then
if requirePackage("-i") ~= true then return false end
-- auth-client is the bootstrap exception (allows non-admin install).
if packageName ~= "auth-client" and requireAdmin("-i") ~= true then return false end
success = runInstall(packageName)

elseif command == "-r" then
if requirePackage("-r") ~= true then return false end
if requireAdmin("-r") ~= true then return false end
success = runUninstall(packageName)

elseif command == "-u" then
success = runUpdate(packageName)

elseif command == "-U" then
success = runUpdate("-f")

elseif command == "-s" then
if requirePackage("-s") ~= true then return false end
if requireAdmin("-s") ~= true then return false end
success = printResult(apt.addsource(packageName), "Source added", "source not added")

elseif command == "-c" then
if requirePackage("-c") ~= true then return false end
if requireAdmin("-c") ~= true then return false end
success = printResult(apt.clearsource(packageName), "Source removed", "source not removed")

elseif command == "-a" then
if requirePackage("-a") ~= true then return false end
if requireAdmin("-a") ~= true then return false end
minux.config("update", packageName)
success = true

elseif command == "-ls" then
shell.run("/bin/less.sh /usr/apt/source.ls")
return true

elseif command == "-la" then
if packageName == "--update" or fs.exists("/temp/apt/programs.ls") ~= true then
local result = apt.softlist()
if result ~= true and fs.exists("/temp/apt/programs.ls") ~= true then
err("list failed (E:" .. tostring(result) .. ")")
return false
end
end
shell.run("/bin/less.sh /temp/apt/programs.ls")
return true

elseif command == "-l" then
shell.run("/bin/less.sh /etc/apt/list/installed.db")
return true

elseif command == "-v" then
success = runVersion(packageName)

else
err("unknown command '" .. tostring(command) .. "'")
print("Try 'apt help' or 'man apt'.")
return false
end

return success
