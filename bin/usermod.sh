-- user management tool (local auth only)
local args = { ... }
local action   = args[1]
local username = args[2]
local newpass  = args[3]

if _G.admin ~= true then
print("Access denied!")
return 0
end

if fs.exists("/usr/minux-main/settings.cfg") == false then
print("Configuration files missing, run 'config login local'")
return 0
end

local authtype = minux.getconfig("login")
if authtype ~= "local" then
print("Authentication type is not set to local")
print("Use 'auth-client' to manage networked users")
print("Use 'apt -i auth-client' to install said package")
return 0
end

-- Read the encryption key from disk; returns nil when encryption is off.
local function readEncryptKey()
local keyPath = "/usr/minux-main/config/encr.conf"
if fs.exists(keyPath) then
local keyfile = fs.open(keyPath, "r")
local key = tonumber(keyfile.readLine())
keyfile.close()
return key
end
return nil
end

-- Write a password to a user file, encrypting it when applicable.
local function writeUserFile(path, password)
local key = readEncryptKey()
if key ~= nil then
password = minux.encrypt(password, key)
end
if fs.exists("/usr/local/auth/") == false then
fs.makeDir("/usr/local/auth/")
end
local file = fs.open(path, "w")
file.write(password)
file.close()
end

local userPath = "/usr/local/auth/" .. (username or "") .. ".usr"

if action == "?" or action == "help" then
print("usermod - local user management")
print("Usage: usermod <action> <username> [password]")
print("  add  <username> <password>  - create a new user")
print("  del  <username>             - delete a user")
print("  psw  <username> <password>  - reset a user's password")

elseif action == "add" then
if username == nil or newpass == nil then
print("Usage: usermod add <username> <password>")
return 0
end
local validUser, userError = minux.validateUsername(username)
if validUser ~= true then
print("Invalid username: " .. userError)
return 0
end
if newpass == "" then
print("Password must not be empty")
return 0
end
if fs.exists(userPath) then
print("This user already exists")
return 0
end
writeUserFile(userPath, newpass)
print("User added!")

elseif action == "del" then
if username == nil then
print("Usage: usermod del <username>")
return 0
end
local validUser, userError = minux.validateUsername(username)
if validUser ~= true then
print("Invalid username: " .. userError)
return 0
end
if fs.exists(userPath) == false then
print("This user does not exist")
return 0
end
if username == "root" then
print("You cannot delete the root user")
return 0
end
fs.delete(userPath)
print("User removed!")

elseif action == "psw" then
if username == nil or newpass == nil then
print("Usage: usermod psw <username> <password>")
return 0
end
local validUser, userError = minux.validateUsername(username)
if validUser ~= true then
print("Invalid username: " .. userError)
return 0
end
if newpass == "" then
print("Password must not be empty")
return 0
end
if fs.exists(userPath) == false then
print("This user does not exist")
return 0
end
writeUserFile(userPath, newpass)
print("User modified")

else
print("Unknown action, use 'usermod ?'")
end
