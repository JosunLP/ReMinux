-- config command tool.
args = {...}
local config = args[1]
local setting = args[2]

-- select the functions
if config == "login" then
	if setting == "local" or setting == "network" or setting == "disabled" then
		minux.setconfig(config , setting)
	else
		print("Invalid input, try 'man config'")
	end
elseif config == "encrypt" then
	if setting == "enabled" or setting == "disabled" then
		minux.setconfig(config, setting)
	else
		print("invalid input, try man config")
	end
elseif config == "clearlogin" then
	if setting == "enabled" or setting == "disabled" then
		minux.setconfig(config, setting)
	else
		print("invalid input, try man config")
	end
elseif config == "mapcleanup" then
	if setting == "enabled" or setting == "disabled" then
		minux.setconfig(config, setting)
	else
		print("invalid input, try man config")
	end
elseif config == "mapcleanup" then
	if setting == "enabled" or setting == "disabled" then
		minux.setconfig(config, setting)
	else
		print("invalid input, try man config")
	end
elseif config == "update" then 
	if setting == "always" or setting == "enabled" or setting == "disabled" then
		minux.setconfig(config , setting)
	else
		print("Invalid input, try 'man config'")
	end
elseif config == "menu"  or config == "ui" then
	if setting == "menu" or setting == "prompt" or setting == "workspace" or setting == "craftos" then
		minux.setconfig(config,setting)
	else
		print("Invalid input, try 'man config'")
	end
elseif config == "welcome" then
	if setting == "disabled" or setting == "enabled" then
		minux.setconfig(config,setting)
	else
		print("Invalid input, try 'man config'")
	end
elseif config == "crashhandler" then
	if setting == "disabled" or setting == "enabled" then
		minux.setconfig(config,setting)
	else
		print("Invalid input, try 'man config'")
	end
elseif config == "debug" then
	if setting == "disabled" or setting == "enabled" or setting == "logging" or setting == "full" then
		minux.setconfig(config,setting)
	else
		print("Invalid input, try 'man config'")
	end
elseif config == "network" then
	if setting == "disabled" or setting == "enabled" then
		minux.setconfig(config, setting)
	else
		print("Invalid input, try 'man config'")
	end
elseif config == nil and apt.checkinstall("menu") == true then
	shell.run("/etc/minux-main/menu/config.sys")
else
	print("Invalid input, try 'man config'")
end
