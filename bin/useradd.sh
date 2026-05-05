-- useradd: add a user to the current auth system.
local args        = { ... }
local newusername = args[1]
local newpassword = args[2]

if newusername == nil or newusername == "" then
print("Usage: useradd <username> <password>")
return 0
end
if newpassword == nil or newpassword == "" then
print("useradd: password required")
return 0
end

local authtype = minux.logintype()
if authtype == "disabled" then
print("No login system in use")
return 0
end

if authtype == "network" then
auth.useradd(newusername, newpassword)
elseif authtype == "local" then
os.run({}, "/bin/usermod.sh", "add", newusername, newpassword)
else
print("Login type unknown or broken")
end
