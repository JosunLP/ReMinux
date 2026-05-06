-- userdel: remove a user from the current auth system.
local args        = { ... }
local newusername = args[1]

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
return os.run({}, "/bin/usermod.sh", "del", newusername)
else
print("Login type unknown or broken")
return false
end
