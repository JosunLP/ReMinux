-- config command tool
local args = { ... }
local config  = args[1]
local setting = args[2]

-- Valid settings for each configurable key. Order is preserved so help and
-- listings show options in a stable, human-friendly sequence.
local validSettings = {
login        = { "local", "network", "disabled" },
encrypt      = { "enabled", "disabled" },
clearlogin   = { "enabled", "disabled" },
mapcleanup   = { "enabled", "disabled" },
crashhandler = { "enabled", "disabled" },
network      = { "enabled", "disabled" },
welcome      = { "enabled", "disabled" },
update       = { "always", "enabled", "disabled" },
debug        = { "enabled", "disabled", "logging", "full" },
ui           = { "menu", "prompt", "workspace", "craftos" },
menu         = { "menu", "prompt", "workspace", "craftos" },
}

-- Keys shown in `config` (no args) listings. `menu` is an alias of `ui`,
-- so it is intentionally omitted to avoid duplicate output.
local listedKeys = {
"login", "ui", "welcome", "update", "network", "debug",
"crashhandler", "clearlogin", "encrypt", "mapcleanup",
}

local function isValidValue(key, value)
if validSettings[key] == nil or value == nil then return false end
for _, candidate in ipairs(validSettings[key]) do
if candidate == value then return true end
end
return false
end

local function joinOptions(key)
return table.concat(validSettings[key], ", ")
end

local function formatBool(value)
if value == true then return "enabled"
elseif value == false then return "disabled"
else return tostring(value) end
end

local function readCurrent(key)
local value = minux.getconfig(key)
return formatBool(value)
end

local function withColor(color, callback)
if term.isColor() then term.setTextColor(color) end
callback()
if term.isColor() then term.setTextColor(colors.white) end
end

local function printUsage()
print("Usage: config                       list current settings")
print("       config <key>                 show current value and options")
print("       config <key> <value>         change the setting")
print("       config help|-h|--help|?      show this message")
print("")
print("Available keys:")
for _, key in ipairs(listedKeys) do
print(string.format("  %-13s %s", key, joinOptions(key)))
end
print("See 'man config' for details on individual options.")
end

local function printSettingsList()
withColor(colors.lime, function() print("Current ReMinux configuration:") end)
for _, key in ipairs(listedKeys) do
print(string.format("  %-13s %s", key, readCurrent(key)))
end
print("")
print("Use 'config <key>' for valid options, or 'config help' for usage.")
end

local function printKeyHelp(key)
print(string.format("config: %s", key))
print(string.format("  current : %s", readCurrent(key)))
print(string.format("  options : %s", joinOptions(key)))
print(string.format("Set with: config %s <value>", key))
end

local function isHelpToken(token)
return token == "help" or token == "-h" or token == "--help" or token == "?"
end

if config ~= nil and isHelpToken(config) then
printUsage()
return true
end

if config == nil then
if apt and apt.checkinstall and apt.checkinstall("menu") == true then
shell.run("/etc/minux-main/menu/config.sys")
return true
end
printSettingsList()
return true
end

if validSettings[config] == nil then
withColor(colors.red, function()
print("config: unknown setting '" .. tostring(config) .. "'")
end)
print("")
printUsage()
return false
end

if setting == nil then
printKeyHelp(config)
return true
end

if isHelpToken(setting) then
printKeyHelp(config)
return true
end

if not isValidValue(config, setting) then
withColor(colors.red, function()
print("config: invalid value '" .. tostring(setting) .. "' for '" .. config .. "'")
end)
print("Valid options: " .. joinOptions(config))
return false
end

local ok = minux.setconfig(config, setting)
if ok ~= true then
withColor(colors.red, function()
print("config: failed to apply '" .. config .. "=" .. setting .. "'")
end)
print("This may require admin or owner privileges. See 'man config'.")
return false
end
withColor(colors.green, function()
print("config: " .. config .. " = " .. setting)
end)
return true
