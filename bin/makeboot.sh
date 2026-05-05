-- makeboot: write the Minux net-installer to a disk's startup slot.
if fs.exists("/disk/startup") then
	print("This disk already contains a startup system.")
	print("Clear the disk before making a boot disk.")
	return false
end

local NETINSTALL_URL =
	"https://raw.githubusercontent.com/JosunLP/Minux/main/tmp/minux_netinstall.lua"

shell.run("wget " .. NETINSTALL_URL .. " /disk/startup")
shell.run("label set " .. _G.diskside .. " Minuxinstall")
