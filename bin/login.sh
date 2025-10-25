-- this script asks users for their login data and forwards it to login.sys
-- first reset previous data
login = nil
password = nil
-- the user can just provide the information in the command, of course
args = {...}
login = args[1]
password = args[2]

-- if login is "?" we shound print the help data
if login == "?" or login == "help" then
	print("use 'man login' for the manual")
	return false
end
--if they did not provide the credentials in the command we must ask for them
if args[1] == nil then
	write("Username:")
	login = read()
end
if args[2] == nil then
	write("Password:")
	password = read("*")
end
-- if they still did not provide valid credentials, we give up
if login == nil or login == "" or password == nil or password == "" then
	print("invalid data, aborting")
	read()
	return false
else
-- if they did, we forward the data
	local loginreturn = minux.login(login, password)
	if loginreturn == true then
		print("Access Granted")
		minux.testcolor()
	elseif loginreturn == false then
		print("Access denied")
	end
end
