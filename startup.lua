-- Minux Bootloader
shell.run("clear")
if fs.exists("/os/version.txt") then
	temp = fs.open("/os/version.txt","r")
	_G.version = temp.read()
	temp.close()
else
	_G.version = "Unknown"
end
print("Starting Minux Version:".._G.version)
shell.run("/boot/init.sys")