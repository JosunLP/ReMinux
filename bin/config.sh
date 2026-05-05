-- config command tool
local args = { ... }
local config  = args[1]
local setting = args[2]

-- Valid settings for each configurable key.
local validSettings = {
login        = { ["local"] = true, network = true, disabled = true },
encrypt      = { enabled = true, disabled = true },
clearlogin   = { enabled = true, disabled = true },
mapcleanup   = { enabled = true, disabled = true },
crashhandler = { enabled = true, disabled = true },
network      = { enabled = true, disabled = true },
welcome      = { enabled = true, disabled = true },
update       = { always = true, enabled = true, disabled = true },
debug        = { enabled = true, disabled = true, logging = true, full = true },
ui           = { menu = true, prompt = true, workspace = true, craftos = true },
menu         = { menu = true, prompt = true, workspace = true, craftos = true },
}

if config ~= nil and validSettings[config] ~= nil then
if validSettings[config][setting] == true then
minux.setconfig(config, setting)
else
print("Invalid setting for '" .. config .. "', try 'man config'")
end
elseif config == nil and apt.checkinstall("menu") == true then
shell.run("/etc/minux-main/menu/config.sys")
else
print("Invalid input, try 'man config'")
end
