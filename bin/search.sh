-- search the disk
args = {...}
filename = args[1]

-- first call findfile, this will give us a table with results
temp = minux.findfile(filename)
if temp[1] == nil then print("api responds nil") return 0 end

-- now read the results file and print the table with matching lines
counter = 1
if temp[counter] == "noresult" then print("no search results found") end
while temp[counter] ~= nil  and temp[counter] ~= "noresult" do
	minux.debug("line:"..temp[counter], "minux")
	local line = temp[counter]
	minux.debug("line:"..line, "minux")
	local printline = tonumber(line)
	minux.debug("line:"..printline, "minux")
	local result = minux.printline("/temp/ls/files.ls",printline)
	minux.debug("result:"..result, "minux")
	print(result)
	counter = counter + 1
end
