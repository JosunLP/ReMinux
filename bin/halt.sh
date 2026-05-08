-- halt: power the computer off via os.shutdown().
local args = { ... }

local function withColor(color, callback)
if term.isColor() then term.setTextColor(color) end
callback()
if term.isColor() then term.setTextColor(colors.white) end
end

local skipConfirm = false
for _, arg in ipairs(args) do
if arg == "help" or arg == "-h" or arg == "--help" or arg == "?" then
print("Usage: halt [-y]")
print("       halt help|-h|--help|?   show this message")
print("Asks for confirmation before powering off; -y / --yes skips it.")
print("See 'man halt' for details.")
return true
elseif arg == "-y" or arg == "--yes" then
skipConfirm = true
end
end

if skipConfirm ~= true then
withColor(colors.yellow, function()
print("This will power the computer off.")
end)
write("Continue? [y/N]: ")
local answer = read()
if answer == nil then answer = "" end
answer = string.lower(answer)
if answer ~= "y" and answer ~= "yes" then
print("halt: aborted")
return false
end
end

minux.halt()
return true
