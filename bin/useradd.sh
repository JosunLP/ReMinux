-- searches for user type and then tries to add users
args = {...}
local newusername = args[1]
local newpassword = args[2]
-- error catching
if newpassword == nil or newpassword == "" then print("useradd:invalid input") return 0 end

-- first find out what type of network we have and if we have auth-client
if fs.exists("/bin/auth-client.sh") then
	authexist = true
end
authtype = minux.logintype()
if authtype == "disabled" then print("no login system in use") return 0 end

-- now we can run the function
if authtype == "network" then
	auth.useradd(newusername , newpassword)
elseif authtype == "local" then
	os.run({} , "/bin/usermod.sh" , "add" , newusername , newpassword)
else
	print("login disabled or broken")
end