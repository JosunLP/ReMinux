-- 3rd party addon launcher
-- minux autocomplete function script
completion = require "cc.shell.completion"
complete = completion.build( { completion.file, many = true })
completecfg = completion.build({ completion.choice, { "clearlogin","mapcleanup","login", "update", "menu", "debug", "ui","welcome", "network", "crashhandler", "encrypt" } })
completeapt = completion.build({ completion.choice, { "install", "-i", "remove","-r", "update","-u", "forceupdate","-U", "list-installed","-l","list-available","-la","list-source","-ls","setsource","-s", "clearsource","-c" } })
shell.setCompletionFunction("bin/cat.sh", complete)
shell.setCompletionFunction("bin/edit.sh", complete)
if fs.exists("/bin/pain.sh") then shell.setCompletionFunction("bin/pain.sh", complete) end
shell.setCompletionFunction("bin/lsr.sh", complete)
shell.setCompletionFunction("bin/ls.sh", complete)
shell.setCompletionFunction("bin/less.sh", complete)
shell.setCompletionFunction("bin/config.sh", completecfg)
shell.setCompletionFunction("bin/apt.sh", completeapt)
-- end minux addon
