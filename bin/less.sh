-- less: full-screen pager for files or piped input.
local args = { ... }

local function isHelpToken(token)
	return token == "?" or token == "help" or token == "-h" or token == "--help"
end

if isHelpToken(args[1]) then
	print("Usage: less [file...]")
	print("Scrollable viewer for files or piped input.")
	print("  Up/Down, W/S, J/K   scroll one line")
	print("  PgUp/PgDn, B/Space  scroll one page")
	print("  Home/End, g/G       jump to start / end")
	print("  /text  n  N         search, next, previous match")
	print("  q, Ctrl or Ctrl+T   quit")
	return 0
end

local sources, failed = minux.collectInput("less", args, shell.resolve)
if sources == nil then
	return false
end

local lines = {}
for _, source in ipairs(sources) do
	for _, line in ipairs(source.lines) do
		lines[#lines + 1] = (string.gsub(line, "\t", "    "))
	end
end
local title = #args == 0 and "(standard input)" or sources[1] and sources[1].label or "less"
if #sources > 1 then
	title = title .. " (+" .. (#sources - 1) .. ")"
end

-- Inside a pipe or redirect there is no screen to page on: pass through.
if minux.getIoContext() ~= nil then
	for _, line in ipairs(lines) do print(line) end
	return not failed
end

local width, height = term.getSize()
local view = {}
local top = 1
local searchText = nil
local message = nil

local function buildView()
	view = {}
	width, height = term.getSize()
	for index, line in ipairs(lines) do
		if #line == 0 then
			view[#view + 1] = { text = "", source = index }
		else
			for start = 1, #line, width do
				view[#view + 1] = { text = string.sub(line, start, start + width - 1), source = index }
			end
		end
	end
end

local function pageHeight()
	return math.max(1, height - 1)
end

local function maxTop()
	return math.max(1, #view - pageHeight() + 1)
end

local function clampTop()
	top = math.max(1, math.min(top, maxTop()))
end

local function draw()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()
	for row = 1, pageHeight() do
		local entry = view[top + row - 1]
		if entry == nil then
			if term.isColor() then term.setTextColor(colors.gray) end
			term.setCursorPos(1, row)
			term.write("~")
			term.setTextColor(colors.white)
		else
			term.setCursorPos(1, row)
			if searchText ~= nil and string.find(string.lower(entry.text), searchText, 1, true) then
				if term.isColor() then term.setTextColor(colors.yellow) end
			end
			term.write(entry.text)
			term.setTextColor(colors.white)
		end
	end
	-- Status bar
	local last = math.min(#view, top + pageHeight() - 1)
	local percent = #view == 0 and 100 or math.floor(last / #view * 100)
	local status = message or (" " .. title .. "  " .. percent .. "%  q:quit /:search")
	if #status > width then status = string.sub(status, 1, width) end
	term.setCursorPos(1, height)
	if term.isColor() then
		term.setBackgroundColor(colors.cyan)
		term.setTextColor(colors.black)
	else
		term.setBackgroundColor(colors.white)
		term.setTextColor(colors.black)
	end
	term.clearLine()
	term.write(status)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	message = nil
end

local function findMatch(direction)
	if searchText == nil or #view == 0 then return end
	local index = top + direction
	while index >= 1 and index <= #view do
		if string.find(string.lower(view[index].text), searchText, 1, true) then
			top = index
			clampTop()
			return
		end
		index = index + direction
	end
	message = " Pattern not found: " .. searchText
end

local function promptSearch()
	term.setCursorPos(1, height)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clearLine()
	term.write("/")
	local ok, text = pcall(read)
	if ok and type(text) == "string" and text ~= "" then
		searchText = string.lower(text)
		top = top - 1
		findMatch(1)
	end
end

buildView()
-- Short content fits on screen: just print it like cat would.
if #view <= pageHeight() then
	for _, line in ipairs(lines) do print(line) end
	return not failed
end

local running = true
while running do
	clampTop()
	draw()
	local event, value = os.pullEventRaw()
	if event == "terminate" then
		running = false
	elseif event == "term_resize" then
		buildView()
	elseif event == "mouse_scroll" then
		top = top + value * 2
	elseif event == "key" then
		if value == keys.up then top = top - 1
		elseif value == keys.down or value == keys.enter then top = top + 1
		elseif value == keys.pageUp then top = top - pageHeight()
		elseif value == keys.pageDown then top = top + pageHeight()
		elseif value == keys.home then top = 1
		elseif value == keys["end"] then top = maxTop()
		elseif value == keys.leftCtrl or value == keys.rightCtrl then running = false
		end
	elseif event == "char" then
		if value == "q" or value == "Q" then running = false
		elseif value == "w" or value == "k" then top = top - 1
		elseif value == "s" or value == "j" then top = top + 1
		elseif value == " " or value == "f" then top = top + pageHeight()
		elseif value == "b" then top = top - pageHeight()
		elseif value == "g" then top = 1
		elseif value == "G" then top = maxTop()
		elseif value == "/" then promptSearch()
		elseif value == "n" then findMatch(1)
		elseif value == "N" then findMatch(-1)
		end
	end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
return not failed
