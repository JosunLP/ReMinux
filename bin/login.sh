-- login script: prompts for credentials and calls minux.login()
local args = { ... }
local username = args[1]
local password = args[2]

if username == "?" or username == "help" then
print("Use 'man login' for the manual")
return false
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
print("Invalid input, aborting")
read()
return false
end

local result, err = minux.login(username, password)
if result == true then
	print("Access granted")
	minux.testcolor()
else
	print("Access denied" .. (err ~= nil and err ~= "" and ": " .. err or ""))
end
