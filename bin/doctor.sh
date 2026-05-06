-- doctor: audit and repair core ReMinux state.
local args = { ... }
local repair = false

if args[1] == "?" or args[1] == "help" or args[1] == "--help" then
print("doctor - system health audit")
print("Usage: doctor [--repair]")
print("  --repair  recreate missing core files and directories")
return true
elseif args[1] == "--repair" or args[1] == "repair" then
repair = true
elseif args[1] ~= nil then
print("Invalid input, try 'man doctor'")
return false
end

local findings = minux.doctor(repair)
local counts = {
ok = 0,
warning = 0,
error = 0,
fixed = 0,
}

local function printFinding(level, message)
local label = string.upper(level)
if term.isColor() then
if level == "error" then
term.setTextColor(colors.red)
elseif level == "warning" then
term.setTextColor(colors.yellow)
elseif level == "fixed" then
term.setTextColor(colors.lime)
else
term.setTextColor(colors.white)
end
end
print("[" .. label .. "] " .. message)
if term.isColor() then
term.setTextColor(colors.white)
end
end

for _, finding in ipairs(findings) do
counts[finding.level] = (counts[finding.level] or 0) + 1
printFinding(finding.level, finding.message)
end

print("")
print(string.format(
"Summary: %d fixed, %d errors, %d warnings, %d ok",
counts.fixed,
counts.error,
counts.warning,
counts.ok
))

if repair ~= true and counts.error > 0 then
print("Run 'doctor --repair' to recreate missing core files and directories.")
end
if counts.warning > 0 and minux.getconfig("login") == "local" and minux.getconfig("encrypt") ~= true then
print("Tip: local auth is safer with 'config encrypt enabled' or network login.")
end

return counts.error == 0
