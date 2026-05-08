-- login script: prompts for credentials and calls minux.login()
local args = { ... }
local username = args[1]
local password = args[2]

local function isHelpToken(token)
return token == "help" or token == "-h" or token == "--help" or token == "?"
end

local function withColor(color, callback)
if term.isColor() then term.setTextColor(color) end
callback()
if term.isColor() then term.setTextColor(colors.white) end
end

if username ~= nil and isHelpToken(username) then
print("Usage: login [username] [password]")
print("       login                  prompt for both interactively")
print("       login <username>       prompt for the password")
print("       login <user> <pass>    non-interactive (password is visible)")
print("See 'man login' for AUTH backends and security notes.")
return true
end

if username == nil then
write("Username: ")
username = read()
end
if password == nil then
write("Password: ")
password = read("*")
end

if username == nil or username == "" or password == nil or password == "" then
withColor(colors.red, function()
print("login: username and password are both required")
end)
return false
end

local result, err = minux.login(username, password)
if result == true then
withColor(colors.green, function()
print("Access granted: " .. username)
end)
minux.testcolor()
return true
end

withColor(colors.red, function()
if err ~= nil and err ~= "" then
print("Access denied: " .. err)
else
print("Access denied for user '" .. username .. "'")
end
end)
return false
