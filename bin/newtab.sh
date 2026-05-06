-- newtab: open a new workspace tab (advanced computers only).
if minux.canOpenTabs() then
print("Opening new tab")
minux.safeOpenTab("/etc/minux-main/workspace/workspace.lua")
else
print("This CC: Tweaked shell does not support tabs here.")
print("Use an advanced computer/workspace shell with shell.openTab().")
end
