--newtab script
print("Opening new tab")
if term.isColor then shell.openTab("/etc/minux-main/workspace/workspace.lua")
else print("Advanced computers only") end
