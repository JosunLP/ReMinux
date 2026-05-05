-- vix: launcher for the Vim-like ReMinux editor.
local args = { ... }
local filename = args[1]

if filename == "?" or filename == "help" then
	print("vix - Vim-like ReMinux editor")
	print("Usage: vix [file]")
	print("Inside the editor press F1 (or :help) for the cheatsheet.")
	return 0
end

if filename == nil or filename == "" then
	write("file: ")
	filename = read()
	if filename == nil or filename == "" then
		print("No file given.")
		return 0
	end
end

shell.run("/etc/minux-main/sys/vix.sys", filename)
