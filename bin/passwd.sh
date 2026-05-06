-- passwd: change a user's password.
local args        = { ... }
local newusername = args[1]
local newpassword = args[2]

if newusername == nil or newusername == "" then
print("Usage: passwd <username> [newpassword]")
return false
end

print("Reset user password")
print("Username: " .. newusername)

if newpassword == nil or newpassword == "" then
write("New password: ")
newpassword = read("*")
end

if newpassword == nil or newpassword == "" then
print("Invalid input, aborting")
return false
end

local authtype = minux.logintype()
if authtype == "disabled" then
print("No login system in use")
return false
end

if authtype == "network" then
if auth == nil or type(auth.setpass) ~= "function" then
print("Network authentication tools are unavailable")
return false
end
local ok = auth.setpass(newusername, newpassword)
return ok ~= false
elseif authtype == "local" then
return os.run({}, "/bin/usermod.sh", "psw", newusername, newpassword)
else
print("Login type unknown or broken")
return false
end
