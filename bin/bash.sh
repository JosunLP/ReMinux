-- bash shell launcher
args = {...}
local command = args[1]
local txtcolor = args[2]
local bgcolor = args[3]
local prmcolor = args[4]

if args[1] == "setcolor" then
	minux.bashcolor(txtcolor, bgcolor, prmcolor)
else
	shell.run("/etc/minux-main/workspace/shell.lua", command)
end
