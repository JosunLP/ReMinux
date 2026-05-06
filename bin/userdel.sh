-- userdel: remove a user from the current auth system.
local args        = { ... }
local newusername = args[1]

local function runUsermod(action, username)
local program, loadErr = loadfile("/bin/usermod.sh")
if program == nil then
print("Cannot load user manager: " .. tostring(loadErr))
return false
end
local ok, result = pcall(program, action, username)
if ok ~= true then
print("User deletion failed: " .. tostring(result))
return false
end
return result == true
end

if newusername == nil or newusername == "" then
print("Usage: userdel <username>")
return false
end

local authtype = minux.logintype()
if authtype == "disabled" then
print("No login system in use")
return false
end

if authtype == "network" then
if auth == nil or type(auth.userdel) ~= "function" then
print("Network authentication tools are unavailable")
return false
end
local ok = auth.userdel(newusername)
return ok ~= false
elseif authtype == "local" then
return runUsermod("del", newusername)
else
print("Login type unknown or broken")
return false
end
