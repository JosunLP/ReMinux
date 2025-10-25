-- this makes a boot disk
if fs.exists("/disk/startup") then
	print("this disk already contains a startup system")
	print("clear the disk before making a boot disk")
	return false
end

shell.run("wget https://minux.cc/netinstall /disk/startup")
shell.run("label set ".._G.diskside.." Minuxinstall")
