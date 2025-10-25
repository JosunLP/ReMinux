-- launcher for edit
args = {...}
local filename = args[1]

if filename == nil then
	write("file:")
	filename = read()
end

shell.run("/etc/minux-main/sys/shedit.sys "..filename)