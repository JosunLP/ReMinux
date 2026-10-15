-- minux autocomplete function script
do
local completion = require "cc.shell.completion"
local function manTopics(_, text)
  local topics = {}
  if fs.isDir("/etc/man") then
    for _, name in ipairs(fs.list("/etc/man")) do
      local topic = string.match(name, "^(.+)%.man$")
      if topic ~= nil and string.sub(topic, 1, #text) == text then
        topics[#topics + 1] = string.sub(topic, #text + 1)
      end
    end
  end
  table.sort(topics)
  return topics
end
local function serviceNames(_, text)
  local names = {}
  if minux ~= nil and type(minux.listServices) == "function" then
    local ok, services = pcall(minux.listServices)
    if ok and type(services) == "table" then
      for _, service in ipairs(services) do
        if string.sub(service.name, 1, #text) == text then
          names[#names + 1] = string.sub(service.name, #text + 1)
        end
      end
    end
  end
  return names
end
local files = completion.build({ completion.file, many = true })
local dirs = completion.build({ completion.dir, many = true })
local configKeys = { "clearlogin", "mapcleanup", "login", "update", "ui", "debug", "welcome", "network", "crashhandler", "encrypt" }
local configValues = {
  login = { "local", "network", "disabled" },
  ui = { "workspace", "prompt", "menu", "craftos" },
  menu = { "workspace", "prompt", "menu", "craftos" },
  update = { "enabled", "disabled", "always" },
  debug = { "enabled", "disabled", "logging", "full" },
}
local function configComplete(shellApi, index, text, previous)
  if index == 1 then
    return completion.choice(shellApi, text, previous, configKeys, true)
  elseif index == 2 then
    local values = configValues[previous[2]] or { "enabled", "disabled" }
    return completion.choice(shellApi, text, previous, values)
  end
  return nil
end
local aptComplete = completion.build({ completion.choice, { "install", "-i", "remove", "-r", "update", "-u", "forceupdate", "-U", "list-installed", "-l", "list-available", "-la", "list-source", "-ls", "setsource", "-s", "clearsource", "-c", "version", "-v", "help" } })
local serviceComplete = completion.build(
  { completion.choice, { "list", "status", "start", "stop", "restart", "enable", "disable", "help" }, true },
  serviceNames
)
local manComplete = completion.build(manTopics)
for _, program in ipairs({
  "cat", "edit", "less", "ls", "head", "tail", "wc", "sort", "uniq", "tac", "rev", "nl", "fold",
  "cut", "tr", "grep", "stat", "touch", "rm", "cp", "mv", "chmod", "chown", "xxd", "du", "tree",
  "find", "vix", "realpath", "basename", "dirname", "df", "pain",
}) do
  local path = "bin/" .. program .. ".sh"
  if fs.exists("/" .. path) then shell.setCompletionFunction(path, files) end
end
shell.setCompletionFunction("bin/mkdir.sh", dirs)
shell.setCompletionFunction("bin/config.sh", configComplete)
shell.setCompletionFunction("bin/apt.sh", aptComplete)
shell.setCompletionFunction("bin/service.sh", serviceComplete)
shell.setCompletionFunction("bin/man.sh", manComplete)
end
-- end minux addon
