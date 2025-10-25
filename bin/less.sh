-- this app reads and prints a file plain and simple.
args = {...}
local userinput = args[1]
local filename = shell.resolve( userinput )

local termX, termY = term.getSize()
local lines = {}
buffer = 0

local function scroll(direction)
-- Checks if user has reached the top or bottom of the file.
if (buffer == 0 and direction == -1) or (buffer == #lines - termY and direction == 1) then return end
term.scroll(direction)

if direction == 1 then
term.setCursorPos(1,termY)
write(lines[#lines-(#lines-termY-(buffer+1))])
buffer = buffer + 1
else
term.setCursorPos(1,1)
write(lines[buffer])
buffer = buffer - 1
end
end

-- catch invalid inputs
if filename == nil or filename == "" then
	print("invalid filename")
	print("use 'man less' for the manual")
	return 0
elseif fs.exists(filename) == false then
	print("file not found")
	return 0
end

-- we process the help command

if filename == "?" or filename == "help" then
	print("less, /bin/less.sh")
	print("prints a text file to the screen")
	print("usage: 'less filename'")
	
-- otherwise we open the file	
else
	fileread = true
	file = fs.open(filename, "r")
	linecounter = 0
-- we read and print the lines	
	while fileread  ~= false do
		temp = file.readLine()
		linecounter = linecounter + 1
-- if we hit nil we stop		
		if temp == nil then fileread = false 
		else table.insert(lines, temp) 
		print(temp)
		end
	end
	file.close()

-- Optional flavor text
table.insert(lines, "viewing: '"..filename.."'")
print(lines[#lines])
--
-- Enables mouse and keyboard input if output is larger than the terminal screen.
if #lines > termY then
	-- Optional flavor text
	table.insert(lines, "scroll or press leftCtrl to exit")
	write(lines[#lines])
	--
	buffer = #lines - termY

repeat event, value = os.pullEvent()
	if event == "mouse_scroll" or value == keys.down or value == keys.up or value == keys.w or value == keys.s then 
		if value == keys.up or value == keys.w then value = -1
		elseif value == keys.down  or value == keys.s then value = 1 end
		scroll(value)
	end
until value == keys.leftCtrl
-- Takes you back down to the bottom of the file when enter is pressed.
if buffer >= 0 and buffer < #lines then
	repeat scroll(1) until buffer == #lines - termY
end 
write("\n")
end
end