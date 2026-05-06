-- makeboot: write the ReMinux net-installer to a disk's startup slot.
if fs.exists("/disk/startup") then
	print("This disk already contains a startup system.")
	print("Clear the disk before making a boot disk.")
	return false
end

local NETINSTALL_URL =
	"https://raw.githubusercontent.com/JosunLP/ReMinux/main/tmp/minux_netinstall.lua"

if _G.diskside == nil or _G.diskside == "NONE" then
print("No disk drive found.")
return false
end

shell.run("wget", NETINSTALL_URL, "/disk/startup")
shell.run("label", "set", _G.diskside, "ReMinuxinstall")
