-- apt controller script, this script makes it easy for users to run the apt system

args = {...}
local command = args[1]
local pkn = args[2]
local rebuild = false

-- we translate aliases
if command == "install" then command = "-i" end
if command == "remove" then command = "-r" end
if command == "update" then command = "-u" end
if command == "update-forced" then command = "-U" end
if command == "setsource" then command = "-s" end
if command == "clearsource" then command = "-c" end
if command == "setupdate" then command = "-a" end
if command == "list-installed" then command = "-l" end
if command == "list-available" then command = "-la" end
if command == "list-source" then command = "-ls" end


-- now we translate to the correct subprogram
if command == "-i" and _G.admin == true and pkn ~= nil then
	if apt.checkinstall(pkn) == true then
		print("Already installed:"..pkn)
		return true
	end
	local temp = apt.install(pkn)
	if temp == true then
		print("package installed:"..pkn)
		rebuild = true
	else
		print("install failed:"..pkn.."E:"..temp)
	end
elseif command == "-i" and pkn == "auth-client" then
	if apt.checkinstall(pkn) == true then
		print("Already installed:"..pkn)
		return 0
	end
	local temp = apt.install(pkn)
	if temp == true then
		rebuild = true
		print("package installed:"..pkn)
	else
		print("install failed:"..pkn)
	end
elseif command == "-r" and _G.admin == true and pkn ~= nil then
	if apt.checkinstall(pkn) == true then
		local temp = apt.uninstall(pkn)
		if temp == false then
			print("removal failed:"..pkn)
		else
			print("package removed:"..pkn)
			rebuild = true
		end
	else
		print("not installed:"..pkn)
	end
elseif command == "-u" and pkn == nil then
	local temp = apt.update()
	rebuild = true
	if temp == true then
		print("update complete")
	else
		print("update failed")
	end
elseif command == "-U" then
	local temp = apt.update("-f")
	rebuild = true
	if temp == true then
		print("update complete")
	else
		print("update failed")
	end
elseif command == "-u" then
	local temp = apt.update(pkn)
	rebuild = true
	if temp == true then
		print("update complete")
	else
		print("update failed")
	end
elseif command == "-s" and _G.admin == true and pkn ~= nil then
	minux.debug("apt:addsource:"..pkn)
	local temp = apt.addsource(pkn)
	if temp == false then
		print("source not added")
	else
		print("source added")
	end
elseif command == "-c" and _G.admin == true and pkn ~= nil then
	temp = apt.clearsource(pkn)
	if temp == true then
		print("source removed")
	else
		print("source not removed")
	end
elseif command == "-a" and _G.admin == true and pkn ~= nil then
	minux.config("update",pkn)
elseif command == "-ls" then
	shell.run("/bin/less.sh /usr/apt/source.ls")
elseif command == "-la" then
	if pkn == "--update" then apt.softlist() end
	if fs.exists("/temp/apt/programs.ls") ~= true then apt.softlist() end
	shell.run("/bin/less.sh /temp/apt/programs.ls")
elseif command == "-l" then
	shell.run("/bin/less.sh /etc/apt/list/installed.db")
elseif command == nil and apt.checkinstall("menu") == true then
	shell.run("/etc/minux-main/menu/soft.sys")
else
	print("Invalid input or access denied, use 'man apt'")
end

if rebuild == true then
	minux.debug("apt:init:reloadAPI","minux")
	print("rebuilding boot addon")
	apt.bootbuild()
	print("rebuilding boot alias")
	apt.aliasbuild()
	print("re-loading alias")
	shell.run("/boot/alias.ls")
	print("re-loading bootaddon")
	shell.run("/boot/addon.d")
end
print("Apt:Operation complete.")
