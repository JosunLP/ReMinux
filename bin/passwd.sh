-- searches for user type and then tries to change pass
args = {...}
local newusername = args[1]
local newpassword = args[2]
-- error catching
print("Reset user password")
if newusername == nil or newusername == "" then print("useradd:invalid input") return false end
authtype = minux.logintype()
print("Username:"..newusername)
if newpassword == nil then
	write("Password:")
	newpassword = read("*")
end
if authtype == "disabled" then print("no login system in use") return false end

-- now we can run the function
if authtype == "network" then
	auth.setpass(newusername , newpassword)
elseif authtype == "local" then
	os.run({} , "/bin/usermod.sh" , "psw" ,  newusername , newpassword)
else
	print("login disabled or broken")
end
