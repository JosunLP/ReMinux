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
auth.setpass(newusername, newpassword)
elseif authtype == "local" then
os.run({}, "/bin/usermod.sh", "psw", newusername, newpassword)
else
print("Login type unknown or broken")
end
