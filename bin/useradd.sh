-- useradd: add a user to the current auth system.
local args        = { ... }
local newusername = args[1]
local newpassword = args[2]

local function runUsermod(action, username, password)
local program, loadErr = loadfile("/bin/usermod.sh")
if program == nil then
print("Cannot load user manager: " .. tostring(loadErr))
return false
end
local ok, result = pcall(program, action, username, password)
if ok ~= true then
print("User creation failed: " .. tostring(result))
return false
end
return result == true
end

if newusername == nil or newusername == "" then
print("Usage: useradd <username> <password>")
return false
end
if newpassword == nil or newpassword == "" then
print("useradd: password required")
return false
end

local authtype = minux.logintype()
if authtype == "disabled" then
print("No login system in use")
return false
end

if authtype == "network" then
if auth == nil or type(auth.useradd) ~= "function" then
print("Network authentication tools are unavailable")
return false
end
local ok = auth.useradd(newusername, newpassword)
return ok ~= false
elseif authtype == "local" then
return runUsermod("add", newusername, newpassword)
else
print("Login type unknown or broken")
return false
end
