-- whoami: print the name of the currently logged-in user.
local user = _G.login
if user == nil or user == false or user == "" or user == "foo" then
	print("nobody")
else
	print(user)
end
