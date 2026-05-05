-- userdel: remove a user from the current auth system.
local args        = { ... }
local newusername = args[1]

if newusername == nil or newusername == "" then
print("Usage: userdel <username>")
return 0
end

local authtype = minux.logintype()
if authtype == "disabled" then
print("No login system in use")
return 0
end

if authtype == "network" then
auth.userdel(newusername)
elseif authtype == "local" then
os.run({}, "/bin/usermod.sh", "del", newusername)
else
print("Login type unknown or broken")
end
