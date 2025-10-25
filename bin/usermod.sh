args = {...}
action = args[1]
etc1 = args[2]
etc2 = args[3]
etc3 = args[4]

if _G.admin ~= true then 
	print("Access denied!")
	return 0 
end

if fs.exists("/usr/minux-main/settings.cfg") == false then
	print("configuration files missing, run 'login set local/network'")
else
	local authtype = minux.getconfig("login")
	if authtype == "local" then
		if action == "?" or action == "help" then
			print("/bin/usermod.sh")
			print("usage: 'usermod action arg1 arg2'")
			print("eg: usermod add testuser testpassword")
			print("eg2: usermod del testuser")
			print("eg3: usermod psw testuser testpass")
			print("options:")
			print("add, del, resetpass")
			return 0
		elseif action == "add" then
			if fs.exists("/usr/local/auth/"..etc1..".usr") then
				print("this user already exists")
				return 0
			else
				file = fs.open("/usr/local/auth/"..etc1..".usr" , "w")
				local encrypt = minux.getconfig("encrypt")
				if encrypt == true then
					local keyfile = fs.open("/usr/minux-main/config/encr.conf","r")
					local tempkey = keyfile.readLine()
					local key = tonumber(tempkey)
					keyfile.close()
					etc2 = minux.encrypt(etc2, key)
				end
				file.write(etc2)
				file.close()
				print("user added!")
			end
		elseif action == "del" then
			if fs.exists("/usr/local/auth/"..etc1..".usr") == false then
				print("this user does not exists")
				return 0
			elseif etc1 == "root" then
				print("you cannot delete root")
			else
				file = fs.delete("/usr/local/auth/"..etc1..".usr")
				print("user removed!")
			end
		elseif action == "psw" then
			if fs.exists("/usr/local/auth/"..etc1..".usr") == false then
				print("this user does not exists")
				return 0
			else 
				file = fs.open("/usr/local/auth/"..etc1..".usr" , "w")
				local encrypt = minux.getconfig("encrypt")
				if encrypt == true then
					local keyfile = fs.open("/usr/minux-main/config/encr.conf","r")
					local tempkey = keyfile.readLine()
					local key = tonumber(tempkey)
					keyfile.close()
					etc2 = minux.encrypt(etc2,key)
				end
				file.write(etc2)
				file.close()
				print("user modified")
			end
		else
			print("invalid data, use 'usermod ?'")
			return 0
		end
	else
	print("authentication type is not set to local")
	print("use 'auth-client' to manage networked users")
	print("use 'apt -i auth-client' to install said package")
	end
end
