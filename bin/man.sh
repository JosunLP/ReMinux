-- manual loader

args = {...}
appname = args[1]


-- we catch invalid data
if appname == "list" then
	shell.run("ls /etc/man/")
	return 0
elseif appname == "" or appname == nil then
	print("no app given, try 'man list'")
	return 0
elseif fs.exists("/etc/man/"..appname..".man") == false then
	print("I have no manuals on this topic, this is what i have:")
	shell.run("ls /etc/man/")
	return 0
end

-- we open and display the manual

shell.run("edit /etc/man/"..appname..".man")
