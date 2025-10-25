-- replaces CC programs and allows a full list of allows
-- ls the folders and build the list
-- list bin
newprogramfile = fs.open("/temp/ls/programs.ls" , "w")
listdata = fs.list("/bin/")
filelist = fs.open("/temp/ls/files.ls" , "w")
count = 1
while listdata[count] ~= nil do
	if fs.isDir(listdata[count]) == false then
		filelist.writeLine(listdata[count])
	end
	count = count +1
end
filelist.close()
filelist = fs.open("/temp/ls/files.ls" , "r")
listdata = filelist.readAll()
newprogramfile.write(listdata)
filelist.close()

-- list programs
listdata = fs.list("/rom/programs/")
filelist = fs.open("/temp/ls/files.ls" , "w")
count = 1
while listdata[count] ~= nil do
	if fs.isDir(listdata[count]) == false then
		filelist.writeLine(listdata[count])
	end
	count = count +1
end
filelist.close()
filelist = fs.open("/temp/ls/files.ls" , "r")
listdata = filelist.readAll()
newprogramfile.write(listdata)
filelist.close()

-- list CC games
listdata = fs.list("/rom/programs/fun/")
filelist = fs.open("/temp/ls/files.ls" , "w")
count = 1
while listdata[count] ~= nil do
	if fs.isDir(listdata[count]) == false then
		filelist.writeLine(listdata[count])
	end
	count = count +1
end
filelist.close()
filelist = fs.open("/temp/ls/files.ls" , "r")
listdata = filelist.readAll()
newprogramfile.write(listdata)
filelist.close()

newprogramfile.close()

--now we print to the screen
local readline = "start"
local filelist = fs.open("/temp/ls/programs.ls" , "r")
while readline ~= nil do 
	readline = filelist.readLine()
	if readline ~= nil then write(readline) write(" ")end
end
-- old backup method using less
-- shell.run("less /temp/ls/programs.ls")