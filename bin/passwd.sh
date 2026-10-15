-- passwd: change a user's password.
local args        = { ... }
local newusername = args[1]
local newpassword = args[2]

local function isHelpToken(token)
return token == "help" or token == "-h" or token == "--help" or token == "?"
end

local function withColor(color, callback)
if term.isColor() then term.setTextColor(color) end
callback()
if term.isColor() then term.setTextColor(colors.white) end
end

local function runUsermod(action, username, password, currentPassword)
local program, loadErr = loadfile("/bin/usermod.sh")
if program == nil then
withColor(colors.red, function()
print("passwd: cannot load user manager: " .. tostring(loadErr))
end)
return false
end
local ok, result = pcall(program, action, username, password, currentPassword)
if ok ~= true then
withColor(colors.red, function()
print("passwd: password change failed: " .. tostring(result))
end)
return false
end
return result == true
end

if newusername ~= nil and isHelpToken(newusername) then
print("Usage: passwd [username] [newpassword]")
print("       passwd help|-h|--help|?   show this message")
print("If no new password is given, passwd prompts for one (input is masked).")
return true
end

local authtype = minux.logintype()
if authtype == "disabled" then
withColor(colors.red, function()
print("passwd: no login system in use")
end)
print("Hint: enable one with 'config login local' or 'config login network'.")
return false
end

if newusername == nil or newusername == "" then
-- Default to the logged-in user, like Unix passwd.
newusername = _G.login
if newusername == nil or newusername == false or newusername == "" or newusername == "foo" then
withColor(colors.red, function()
print("passwd: missing username")
end)
print("Usage: passwd <username> [newpassword]")
return false
end
end

print("Changing password for " .. newusername)

local currentPassword = nil
if _G.admin ~= true then
if newusername ~= _G.login then
withColor(colors.red, function()
print("passwd: only an admin can change other users' passwords")
end)
return false
end
write("Current password: ")
currentPassword = read("*")
if currentPassword ~= _G.masterpass then
withColor(colors.red, function()
print("passwd: authentication failed")
end)
return false
end
end

if newpassword == nil or newpassword == "" then
write("New password: ")
newpassword = read("*")
if newpassword ~= nil and newpassword ~= "" then
write("Retype new password: ")
if read("*") ~= newpassword then
withColor(colors.red, function()
print("passwd: passwords do not match")
end)
return false
end
end
end

if newpassword == nil or newpassword == "" then
withColor(colors.red, function()
print("passwd: password must not be empty")
end)
return false
end

local ok
local printedByUsermod = false
if authtype == "network" then
if auth == nil or type(auth.setpass) ~= "function" then
withColor(colors.red, function()
print("passwd: network authentication tools are unavailable")
end)
print("Hint: 'apt -i auth-client' to install the network auth client.")
return false
end
ok = auth.setpass(newusername, newpassword) == true
elseif authtype == "local" then
ok = runUsermod("psw", newusername, newpassword, currentPassword)
printedByUsermod = true
else
withColor(colors.red, function()
print("passwd: login type unknown or broken (" .. tostring(authtype) .. ")")
end)
return false
end

if ok ~= true then
return false
end
if newusername == _G.login then
-- Keep the lock screen in sync with the new password.
_G.masterpass = newpassword
end
if printedByUsermod ~= true then
withColor(colors.lime, function()
print("passwd: password updated for '" .. newusername .. "'")
end)
end
return true
