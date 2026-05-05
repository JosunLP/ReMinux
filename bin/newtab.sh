-- newtab: open a new workspace tab (advanced computers only).
if term.isColor() then
print("Opening new tab")
shell.openTab("/etc/minux-main/workspace/workspace.lua")
else
print("Advanced computers only")
end
