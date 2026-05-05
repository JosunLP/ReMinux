-- id: print user, host, and computer identification.
local user = _G.login
if user == nil or user == false or user == "" or user == "foo" then
	user = "nobody"
end
local label = os.getComputerLabel() or ("computer-" .. tostring(os.getComputerID()))
print(string.format("user=%s  host=%s  computer-id=%d",
	user, label, os.getComputerID()))
