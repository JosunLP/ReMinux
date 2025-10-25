-- minux computercraft OS netinstaller - https://minux.cc/
-- Menu API by ComputerCrafter
-- buffer added by Missooni
-- change this line to point the installer's private option to another url
customsource = "https://127.0.0.1/apt/"

local ogTerm = term.current()
local termX, termY = term.getSize()
local bufferWindow = window.create(ogTerm, 1, 1, termX, termY)
-- Uses ">" as pointer instead of "->"
function menuOptions(title, tChoices, tActions)
local check = true
local nSelection = 1
repeat
bufferWindow.setVisible(false)
term.redirect(bufferWindow)
term.clear()
local width, height = term.getSize()
paintutils.drawLine(1, 1, width, 1, colors.gray)
term.setCursorPos(1, 1)
term.setBackgroundColor(colors.gray)
print(title)
term.setBackgroundColor(colors.black)
print("")
    for nLine = 1, #tChoices do 
        local sLine = " "
        if nSelection == nLine then
            sLine = ">"
            pLine = true
        else
            pLine = false
        end
        sLine = sLine .." "..tChoices[nLine] 
        if pLine == true then
            term.setTextColor(colors.lightGray)
            print(sLine)
            term.setTextColor(colors.white)
        else
            print(sLine)
        end
    end
    bufferWindow.setVisible(true)
    local sEvent, nKey = os.pullEvent("key")
    if nKey == keys.up or nKey == keys.w then
        if tChoices[nSelection - 1] then
            nSelection = nSelection - 1
        end
    elseif nKey == keys.down or nKey == keys.s  then
        if tChoices[nSelection + 1] then 
            nSelection = nSelection + 1
        end
    elseif nKey == keys.enter then 
        if tActions[nSelection] then
            tActions[nSelection]() 
            check = false
        else
            print("Error: Selection out of bounds: ", nSelection)
            print("Press Enter to continue...")
            read() 
        end
    end
until check == false 
end
local dumpWindow = window.create(term.current(), 1, 1, 1, 1, false);
function disableoutput()
  ogTerm = term.current();
  term.redirect(dumpWindow);
  return ogTerm
end
-- needs a monitor to return to
function enableoutput(ogTerm)
  term.redirect(ogTerm);
end
expectfile = "/rom/modules/main/cc/expect.lua"
_G.expect = dofile(expectfile)
term.clear()
term.setCursorPos(1,1)
	local title = "Minux Installer"
	local choices = {"install minux", "reset existing installation", "repair minux - keep settings", "start an empty CraftOS shell","start computer"}
	local actions = {}
	actions[1] = function()
	print("installation selected")
	input = "install"
	end
	actions[2] = function()
	print("reinstall selected")
	input = "reinstall"
	end
	actions[3] = function()
	print("repair selected")
	input = "repair"
	end
	actions[4] = function()
	print("shell selected")
	input = "shell"
	end	
	actions[5] = function()
	print("starting computer")
	input = "start"
	end
menuOptions(title, choices, actions)
if input == "repair" then
	if fs.exists("/etc/api/minux") then
		print("attempting to load api's")
		os.loadAPI("/etc/api/minux")
		os.loadAPI("/etc/api/apt")
		print("attempting to force-update software")
		apt.update("-f")
		print("done, reboot the system or run /boot/init.sys")
		print("launching shell")
		shell.run("/rom/programs/shell.lua")
	else
		print("Can't find instructions file, aborting")
		print("launching shell")
		shell.run("/rom/programs/shell.lua")
	end	
elseif input == "shell" then return 0 
elseif input == "start" then
	if fs.exists("/startup") then shell.run("/startup")
	elseif fs.exists("/startup.lua") then shell.run("/startup.lua")
	else
		print("no installation detected, dropping into shell")
		return 0
	end
elseif input == "install" or "reinstall" then
	if input == "install" then 
		if fs.exists("/startup") then
			print("This system already has software installed")
			print("are you sure you want to overwrite this?")
			print("")
			print("type yes to proceed")
			print("anything else to abort")
			input = read()
			if input == "yes" or input == "Yes" or input == "YES" then
				return 0
			end
		end
	end

-- selecting installation source
	local title = "Minux Installation source"
	local choices = {"latest - Default","latest - desktop","latest - minimal","test - beta - unstable", "private server","manually enter"}
	local iactions = {}

	iactions[1] = function()
	print("default selected")
	input = "default"
	end
	iactions[2] = function()
	print("desktop selected")
	input = "desktop"
	end
	iactions[3] = function()
	print("minimal selected")
	input = "minimal"
	end
	iactions[4] = function()
	print("beta selected")
	input = "beta"
	end
	iactions[5] = function()
	print("private")
	input = "private"
	end
	iactions[6] = function()
	print("custom")
	input = "custom"
	end	
menuOptions(title, choices, iactions)

if input == "default" or input == "minimal" or input == "desktop" then aptsource = "https://minux.cc/apt/2.0/os/"
elseif input == "beta" then aptsource = "https://minux.cc/beta/"
elseif input == "private" then aptsource = customsource
elseif input == "custom" then
	print("what is the server's url?")
	print("give full path including https://")
	ainput = read()
	if ainput == nil or ainput == "" then print("invalid input, aborting") return 0
	else aptsource = ainput end
end

-- we check if the provided source is valid/live
print("Retrieving files from:"..aptsource)
if fs.exists("/etc/apt/manifest/minux-main.db") then fs.delete("/etc/apt/manifest/minux-main.db") end
shell.run("wget "..aptsource.."/manifest/minux-main.db /etc/apt/manifest/minux-main.db")

-- now we open the manifest file and check if it is actually a manifest file at all (invalid url catcher)
file = "start"
if fs.exists("/etc/apt/manifest/minux-main.db") == false then
	print("Invalid installation source or server offline.")
	return false
end
local temp = fs.open("/etc/apt/manifest/minux-main.db", "r")
-- 404 error catcher
file = temp.readLine()
if file ~= "AIF=true" then
	print("Error 404, Pack data missing or corrupt, aborting.")
	print("AIF verification failed, the downloaded file is not a manifest file")
	print("This means the provided source URL is invalid")
	return 0
end

-- we download the files for "minux-main" as described in the manifest
print("manifest retrieved, downloading package")
local oldterm = disableoutput()
shell.run("wget run "..aptsource.."/repository/minux-main.map /")
enableoutput(oldterm)
print("Download Finished")

-- now we write the files down
if fs.exists("/etc/apt/list/installed.db") == false then
	print("Generating installed.db")
	file = fs.open("/etc/apt/list/installed.db" , "w")
	file.writeLine("minux-main")
	if input == "desktop" then
		file.writeLine("devlib")
		file.writeLine("auth-client")
		file.writeLine("sword")
		file.writeLine("minex")
		file.writeLine("ldris")
		file.writeLine("minesweeper")
		file.writeLine("solitaire")
		file.writeLine("sonata")
		file.writeLine("pain")
		file.writeLine("menu")
		file.writeLine("musicstream")
	elseif input == "default" then
		file.writeLine("menu")
		file.writeLine("minex")
		file.writeLine("netlib")
		file.writeLine("auth-client")
	end
	file.close()
end

print("Generating source file")
sourcefile = fs.open("/usr/apt/source.ls" , "w")
sourcefile.writeLine(aptsource)
if input == "default" or input == "minimal" or input == "desktop" then
	sourcefile.writeLine("https://minux.cc/apt/2.0/soft/")
end
sourcefile.close()
print("Building boot configuration")
shell.run("/etc/apt/sys/rebuildalias.sys")
-- we wait for an enter, then reboot
term.clear()
term.setCursorPos(1,1)
print("Minux base installed.")
print("you can host your own download server! see our wiki for more info.")
print("Special thanks to LDDestroier for making progdor, patron saint of the slow connections.")
print(" ")
print("hit enter to continue the installation process.")
input = read()
os.reboot()
end
