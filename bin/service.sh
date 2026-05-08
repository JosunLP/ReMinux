local args = { ... }
local action = args[1] or "list"
local name = args[2]

local function printUsage()
print("Usage: service [list|status|start|stop|restart|enable|disable] [name]")
end

if action == "?" or action == "help" then
printUsage()
return 0
end

if action == "list" then
local services = minux.listServices()
for _, service in ipairs(services) do
local state = service.state or "inactive"
local enabled = service.enabled == true and "enabled" or "disabled"
print(string.format("%-12s %-8s %-8s %s", service.name, service.trigger or "manual", enabled, state))
end
return 0
end

if name == nil or name == "" then
printUsage()
return false
end

if action == "status" then
local service = minux.getService(name)
if service == nil then
print("service: unknown service: " .. name)
return false
end
print("Name    : " .. service.name)
print("Trigger : " .. (service.trigger or "manual"))
print("Enabled : " .. (service.enabled == true and "yes" or "no"))
print("State   : " .. (service.state or "inactive"))
if service.description ~= nil and service.description ~= "" then
print("About   : " .. service.description)
end
if service.detail ~= nil and service.detail ~= "" then
print("Detail  : " .. service.detail)
end
return 0
end

local actions = {
start = minux.startService,
stop = minux.stopService,
restart = minux.restartService,
enable = function(serviceName)
return minux.setServiceEnabled(serviceName, true)
end,
disable = function(serviceName)
return minux.setServiceEnabled(serviceName, false)
end,
}

local handler = actions[action]
if handler == nil then
print("service: unknown action: " .. action)
printUsage()
return false
end

local ok, err = handler(name)
if ok ~= true then
print("service: " .. (err or "operation failed"))
return false
end

print("service: " .. action .. " ok: " .. name)
