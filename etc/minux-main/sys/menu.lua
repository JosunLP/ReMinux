-- menuOptions function by ComputerCrafter
-- Uses ">" as pointer instead of "->", indents options.
function menuOptions(title, tChoices, tActions, nSelection, description, tDescriptions)
	local colortable = {
	colors.white,
	colors.black,
	colors.gray
	}
	if minux then
		expect(1,title,"string")
		expect(2,tChoices,"table")
		expect(3,tActions,"table")
		expect(4,nSelection,"number","nil")
		expect(5,description,"string","nil")
		expect(6,tDescriptions,"table","nil")
		if _G.login ~= nil then colortable = minux.getbashcolor() end
	end
	local ogTerm = term.current()
	local termX, termY = term.getSize()
	local bufferWindow = window.create(ogTerm, 1, 1, termX, termY, true)
	local check = true
	term.redirect(bufferWindow)
	term.setTextColor(colortable[3])
	paintutils.drawLine(1, 1, termX, 1, colortable[2])
	term.setCursorPos(1, 1)
	term.setBackgroundColor(colortable[2])
	if not nSelection then nSelection = 1 end
	print(title)
	term.setBackgroundColor(colortable[2])
	term.setTextColor(colortable[1])
	if description then 
		print(" "..description)
		bufferWindow.reposition(2, 3, termX-1, termY - 2)
	else
		print(string.rep(" ", termX))
		bufferWindow.reposition(2, 2, termX-1, termY - 1)
	end
	while check == true do
		bufferWindow.setVisible(false)
		term.setBackgroundColor(colortable[2])
		term.clear()
		term.setCursorPos(1,1)
		local baseDraw = 1
		if #tChoices > termY - 1 then 
		baseDraw = nSelection
		end
		for nLine = baseDraw, #tChoices do 
			local sLine = ""
			local mX, mY = term.getCursorPos()
			local pLine = (nSelection == nLine)
			if pLine then
				sLine = ">"
			end
			sLine = sLine .." "..tChoices[nLine] 
			if pLine == true and mY < termY - 2 then
				term.setTextColor(colortable[3])
				print(sLine)
				if tDescriptions and tDescriptions[nLine] and pLine == true then print("   "..tDescriptions[nLine]) end
				term.setTextColor(colortable[1])
			elseif mY < termY - 2 then
				print(sLine)
			end
		end
		bufferWindow.setVisible(true)
		local sEvent, nKey = os.pullEvent("key")
		if nKey == keys.up or nKey == keys.w then
			if tChoices[nSelection - 1] then
				nSelection = nSelection - 1
			else
				nSelection = #tChoices
			end
		elseif nKey == keys.down or nKey == keys.s  then
			if tChoices[nSelection + 1] then 
				nSelection = nSelection + 1
			else
				nSelection = 1
			end
		elseif nKey == keys.home then
			nSelection = 1
		elseif nKey == keys['end'] then 
			nSelection = #tChoices
		elseif nKey == keys.enter then 
			if tActions[nSelection] then
				tActions[nSelection](nSelection)
				check = false
			else
				print("Error: Selection out of bounds: ", nSelection)
				print("Press Enter to continue...")
				read() 
			end
		end
	end
	term.redirect(ogTerm)
end

-- Additional functions by Missooni
function buttonOptions(tChoices, tActions, orientation)
	if not orientation then orientation = "h" end
	local colortable = {
	colors.white,
	colors.black,
	colors.gray
	}
	if minux then
		expect(1,tChoices,"table")
		expect(2,tActions,"table")
		expect(3,orientation,"string","nil")
		colortable = minux.getbashcolor()
	end
	local gridX, gridY
	local ogTerm = term.current()
	local termX, termY = term.getSize()
	local bufferWindow = window.create(ogTerm, 1, 1, termX, termY, true)
	term.redirect(bufferWindow)
	if orientation == "v" and (#tChoices % 2 == 0) then
		gridX, gridY = #tChoices/2, 2
	elseif orientation == "v" then
		gridX, gridY = 1, #tChoices
	elseif orientation == "h" and (#tChoices % 2 == 0) then
		gridX, gridY = 2, #tChoices/2
	elseif orientation == "h" then
		gridX, gridY = #tChoices, 1
	end
	if not string.find(math.sqrt(#tChoices),"%D") then
		gridX = math.sqrt(#tChoices)
		gridY = math.sqrt(#tChoices)
	end
	term.setBackgroundColor(colortable[2])
	term.setTextColor(colortable[1])
	term.clear()
	local ogTable = saveOGs()
	local regions = {}
	local moveGridX = 0
	local moveGridY = 0
	for i = 1, gridX do
		for i = 1, gridY do
		table.insert(regions, {
		1+(moveGridX*(termX/gridX)),
		1+(moveGridY*(termY/gridY)),
		termX/gridX+(moveGridX*termX/gridX),
		termY/gridY+(moveGridY*termY/gridY),
		})
		moveGridY = moveGridY+1
		end
		moveGridY = 0
		moveGridX = moveGridX+1
	end
	for i, v in pairs(regions) do
		if tChoices[i] then
		paintutils.drawBox(regions[i][1], regions[i][2], regions[i][3], regions[i][4], colors.gray)
		term.setBackgroundColor(colortable[2])
		term.setCursorPos(regions[i][1]+termX/gridX/2-#tChoices[i]/2, regions[i][2]+termY/gridY/2)
		write(tChoices[i])
		end
	end
	term.redirect(ogTerm)
	restoreOGs(ogTable)
	local check = true
	while check == true do
		local sEvent, nKey, nX, nY = os.pullEvent("mouse_click")
		for i = 1, #regions do
			if (nX >= regions[i][1] and nX <= regions[i][3]) and (nY >= regions[i][2] and nY <= regions[i][4]) then
			check = false
			tActions[i](i)
			end
		end
	end
end

function saveOGs()
	local ogTable = {
	term.getBackgroundColor(),
	term.getTextColor(),
	term.getCursorPos(),
	}
	return ogTable
end

function restoreOGs(ogTable)
	term.setBackgroundColor(ogTable[1])
	term.setTextColor(ogTable[2])
	term.setCursorPos(ogTable[3], ogTable[4])
end

function drawLabel(x, y, text, width, color1, color2)
	local ogTable = saveOGs()
	paintutils.drawLine(x, y, x+width, y, color2)
	local mX, mY = term.getCursorPos()
	term.setCursorPos(mX-(math.floor(width/2+0.5))-(math.floor(#text/2+0.5)), mY)
	term.setTextColor(color1)
	write(text)
	restoreOGs(ogTable)
end

function safeFormLabel(x, y, width, color1, color2, default, color3)
	return formLabel(x, y, width, color1, color2, default, color3, true)
end

function formLabel(x, y, width, color1, color2, default, color3, protected)
	local regionTable = {
	["x"] = x,
	["y"] = y,
	["xw"] = x+width,
	["colortable"] = {
	color1,
	color2,
	color3,
	},
	["input"] = "",
	["default"] = default,
	["protected"] = protected,
    ["label"] = function()
                drawLabel(x, y, " ", width, color1, color2) 
	            end,
	}
	return regionTable
end

function buildForm(formTable, submitFunc, x, y, width, color1, color2, text)
	if not text then text = " " end
	drawLabel(x, y, text, width, color1, color2)
	local ogTable = saveOGs()
	local form = {
		["selected"] = 1,
		["total"] = 0,
		["x"] = x,
		["y"] = y,
		["xw"] = x+width,
		}
	for key, value in pairs(formTable) do
		form.total = form.total + 1
		value.label()
		updateForm(formTable, {["selected"] = key})
	end
	updateForm(formTable, {["selected"] = 1})
	os.sleep(0.2)
	handleForm(formTable, form)
	restoreOGs(ogTable)
    submitFunc(formTable)
end

function handleForm(formTable, form)
	local pause = false
	local active = true
	local event, button, mX, mY = os.pullEvent()
	for key, value in pairs(formTable) do
		if event == "mouse_click" and mX >= value.x and mX <= value.xw and mY == value.y and form.selected ~= key then
			form.selected = key 
        elseif event == "char" and key == form.selected then
			value.input = value.input..button
		elseif button == keys.backspace and key == form.selected then
			value.input = string.sub(value.input, 1, #value.input-1)
			os.sleep(0.15)
		elseif not pause and button == keys.tab then
			if form.total ~= form.selected then
			form.selected = form.selected+1
			else
			form.selected = 1
			end
			os.sleep(0.15)
			pause = true
		elseif not pause and button == keys.leftCtrl and form.selected ~= 1 then
			form.selected = form.selected-1
			os.sleep(0.15)
			pause = true
		elseif button == keys.enter and form.total == form.selected then
			active = false
		elseif event == "mouse_click" and mX >= form.x and mX <= form.xw and mY == form.y then
			active = false
		end
	updateForm(formTable, form)
	end
	if active then
	handleForm(formTable, form)
	else
	term.setCursorBlink(false)
	end
end

function updateForm(formTable, form)
	local value = formTable[form.selected]
	formTable[form.selected].label()
	term.setCursorBlink(false)
	term.setCursorPos(value.x, value.y)
	term.setBackgroundColor(value.colortable[2])
	if value.default and value.input == "" then
	term.setTextColor(value.colortable[3])
	write(value.default)
	term.setCursorBlink(true)
	elseif value.input then
	term.setTextColor(value.colortable[1])
	local width = value.xw-value.x
		if #value.input > width then
			if not value.protected then
			write(string.sub(value.input, -width-1))
			else
			write(string.sub(string.rep("*", #value.input), -width-1))
			end
		else
			if not value.protected then
			write(value.input)
			else
			write(string.rep("*", #value.input))
			end
		end
		term.setCursorBlink(true)
	end	
end

function clickButton(x, y, width, color1, color2, text, duration)
	local ogTable = saveOGs()
	if not duration then duration = 0.5 end
	drawLabel(x, y+1, text, width, color1, color2)
	drawLabel(x, y, " ", width, ogTable[1], ogTable[1])
	if duration > 0 then
	os.sleep(duration)
	drawLabel(x, y, text, width, color1, color2)
	drawLabel(x, y+1, " ", width, ogTable[1], ogTable[1])
	end
	restoreOGs(ogTable)
end
