--[[
Workspace v2
  by LDDestroier

  TODO:
	* find out how to access each currently running shell program via debug API
	* add a file picker

--]]

local _CONFIG_DIR = "/etc/minux-main/workspace"
local _CONFIG_PATH = "workspace.cfg"
local _WS_STARTUP_PATH = "start.lua"
local _BASE_SHELL = shell

local first_run = true
local tArg = {...}

local __G

-- instructs on using the program
local function showHelp()
	print("CTRL+SHIFT+Arrow to change space.")
	print("CTRL+SHIFT+[WASD] to add a space.")
	print("CTRL+SHIFT+TAB+Arrow to swap spaces.")
	print("CTRL+SHIFT+Q to delete the space.")
	print("CTRL+SHIFT+P to pause the space.")
	print("Terminate on an inactive space to quit.")
	print("Run Workspace with --config to edit config.")
end

local config = {

	-- speed at which viewport scrolls by. range is between 0.001 and 1
	scroll_speed = 0.35,
	scroll_delay = 0.05,

	-- delay between redrawing windows
	redraw_tick_delay = 0.05,

	-- when opening a new workspace, open the file picker by default
	-- WIP
	use_program_picker = false,

	-- whether or not adding workspaces with CTRL+SHIFT+WASD will be remembered for later
	update_space_grid = true,

	-- default program when opening a new workspace
	default_program = "rom/programs/shell.lua",

	-- whether or not pausing is permitted
	allow_pausing = true,

	-- whether or not to draw the void static pattern
	-- on higher resolution displays, this can have a performance hit
	do_draw_void = true,

	-- if true, then os.queueEvent will not send events to other workspaces
	private_queued_events = false,

	-- amount of time the workspace grid display is shown when it pops up
	osd_duration = 0.6,

	-- given names for specific programs to be written alongside the grid display
	program_titles = {
		["rom/programs/edit.lua"] = "Edit",
		["rom/programs/monitor.lua"] = "Monitor",
		["rom/programs/lua.lua"] = "Lua Interpreter",
		["rom/programs/gps.lua"] = "GPS",
		["rom/programs/fun/adventure.lua"] = "Adventure",
		["rom/programs/fun/dj.lua"] = "DJ",
		["rom/programs/fun/hello.lua"] = "Hello world!",
		["rom/programs/fun/speaker.lua"] = "Speaker",
		["rom/programs/fun/worm.lua"] = "Worm",
		["rom/programs/fun/advanced/gfxpaint.lua"] = "GFXPaint",
		["rom/programs/fun/advanced/raycast.lua"] = "Raycast Demo",
		["rom/programs/fun/advanced/redirection.lua"] = "Redirection",
		["rom/programs/fun/advanced/pngview.lua"] = "PNGView",
		["rom/programs/pocket/falling.lua"] = "Falling",
		["rom/programs/rednet/chat.lua"] = "Chat",

		["shell.lua"] = "Shell",
		["cash.lua"] = "Cash",
		["enchat3.lua"] = "Enchat 3",
		["ldris.lua"] = "LDris",
		["workspace.lua"] = "Workspace",
		["pain.lua"] = "PAIN",
		["stdgui.lua"] = "STD-GUI",
		["tron.lua"] = "Tron",
	},
	space_grid = {
		["1,1"] = true
	}
}

-- serializes and organizes by value type
local function niceSerialize(tbl)
	local output = "{"

	local stuff = {}
	local priority = {
		"boolean",
		"number",
		"string",
		"table",
	}

	for k, v in pairs(tbl) do
		stuff[type(v)] = stuff[type(v)] or {}
		stuff[type(v)][k] = v
	end

	for i = 1, #priority do
		for k,v in pairs(stuff[priority[i]]) do
			if (type(k) == "string") then
				output = output .. "\n\t" .. k

			elseif (type(k) == "number") then
				output = output .. "\n\t[" .. k .. "]"

			elseif (type(k) == "table") then
				output = output .. "\n\t[ " .. textutils.serialize(k) .. " ]"
			end

			output = output .. " = " .. textutils.serialize(v):gsub("\n", "\n ") .. ","
		end
		if (i ~= #priority) then
			output = output .. "\n"
		end
	end
	output = output:sub(1, -2) .. "\n}"

	return output

end

local function setConfig(path)
	local contents = niceSerialize(config)
	local file = fs.open(path or fs.combine(_CONFIG_DIR, _CONFIG_PATH), "w")
	if (file) then
		file.write(contents)
		file.close()
	else
		error("Unable to write config to '" .. path .. "'")
	end
end

local function getConfig(path)
	local contents, _config
	local file = fs.open(path or fs.combine(_CONFIG_DIR, _CONFIG_PATH), "r")
	if (file) then
		contents = file.readAll()
		_config = textutils.unserialize(contents)
		file.close()
		if (_config) then
			for k,v in pairs(_config) do
				config[k] = v
			end

			-- set bounds
			config.scroll_speed = math.min(math.max(config.scroll_speed, 0.001), 1)

			return true
		else
			return false
		end

	else
		return false
	end

end

-- allow changing config from commandline argument
if (tArg[1] == "--config") then
	shell.run("edit", fs.combine(_CONFIG_DIR, _CONFIG_PATH))
	if (_G.__WORKSPACE_RUNNING) then
		os.queueEvent("workspace_refresh_config")
	end
	return true

elseif (tArg[1] == "--help") then
	showHelp()
	return true
end

--[[
if (_G.__WORKSPACE_RUNNING) then
	if (shell.getRunningProgram() ~= "startup.lua") then
		print("Workspace is already running.\n")
		showHelp()
	end
	return true
end
--]]

-- keyDown key for either option key
keys.ctrl = 500
keys.alt = 501
keys.shift = 502

-- events that require focus
local focus_events = {
	["key"] = true,
	["char"] = true,
	["key_up"] = true,
	["mouse_click"] = true,
	["mouse_drag"] = true,
	["mouse_up"] = true,
	["mouse_scroll"] = true,
	["paste"] = true,
	["terminate"] = true,
	["file_transfer"] = true,
}

-- native versions of certian functions that are modified for each workspace
local _base = {os = {}, term = {}, fs = {}, shell = shell}

-- global state
-- ideally, workspaces should not have access to this
local state = {
	-- list of every workspace object, as generated by Workspace.Generate
	workspaces = {},
	count = 0,

	-- terminal size
	term_width = 1,
	term_height = 1,
	term = term.current(),

	-- used whenever the viewport is scrolled off a workspace at all
	-- such that a void can be drawn without crazy flickering
	alt_term = window.create(term.current(), 1, 1, 1, 1, false),
	use_alt_term = false,

	-- timer variables
	timer = {
		osd = 0,	-- for overlay
		scroll = 0,	-- for scrolling
		tick = 0,	-- for forcing events through
		redraw = 0,	-- for redrawing
	},

	-- currently selected workspace in the grid
	x = 1,
	y = 1,

	-- scrolling across workspaces as a factor of terminal width/height
	-- 1 = no scroll, 2 = entire screen, 3 = two screen distances, etc.
	scroll_x = 1,
	scroll_y = 1,

	-- ensures that timer IDs are sequentially generated
	new_timer_id = os.startTimer(0),

	-- set this to true every time the layout of workspaces changes
	do_refresh = true,

	-- set this to true if you want to reload from the config file
	do_refresh_config = false,

	-- if true, redraw all visible windows
	do_redraw = true,

	-- if true, then the user is currently clicking and dragging to move between workspaces
	is_dragging = false,

	-- window object for notifications (defined in main)
	win_overlay = nil,
	is_overlay_visible = false,

	-- if the void between windows is visible
	is_void_visible = false,

	drag_spots = {{}, {}},
	drag_scroll = {0, 0},

	-- sentinal for entire program
	active = true
}

state.term_width, state.term_height = term.getSize()
state.alt_term.reposition(1, 1, state.term_width, state.term_height)
state.alt_term.getGraphicsMode = term.current().getGraphicsMode
state.alt_term.setGraphicsMode = term.current().setGraphicsMode

local keysDown = {}
for i = 1, 256 do
	keysDown[i] = false
end

local function XYtoIndex(x, y)
	return tostring(x) .. "," .. tostring(y)
end

local function IndexToXY(key)
	local x = tonumber(key:match("%d*"))
	local y = tonumber(key:match(",%d*"):sub(2))
	if (x and y) then
		return x, y
	end
end

function table.copy(tbl)
	local output = {}
	for k,v in pairs(tbl) do
		if (type(v) == "table") and (v ~= tbl) then
			output[k] = table.copy(v)
		else
			output[k] = v
		end
	end
	return output
end

-- round to nearest integer
local function round(num)
	return math.floor(num + 0.5)
end

local function roundp(num, places)
	return math.floor(num * (10^places)) / (10^places)
end

-- aligned write
local function awrite(text, y, mode, win)
	win = win or term.current()
	local w_width, w_height = win.getSize()
	local cx, cy = win.getCursorPos()
	if (mode == "left") then
		win.setCursorPos(1, y or cy)

	elseif (mode == "right") then
		win.setCursorPos( w_width - text:len() + 1, y or cy)

	elseif (mode == "center") then
		win.setCursorPos( math.floor(w_width / 2) - math.floor(text:len() / 2) + 1, y or cy )
	end
	win.write(text)
end

-- centered write
local function cwrite(text, y, win)
	return awrite(text, y, "center", win)
end

-- reposition windows without needing all arguments populated
local function wreposition(win, x, y, width, height, parent)
	local _x, _y = win.getPosition()
	local _width, _height = win.getSize()
	return win.reposition(
		x or _x,
		y or _y,
		width or _width,
		height or _height,
		parent
	)
end

-- centered window reposition
local function creposition(win, width, height, parent)
	wreposition(
		win,
		math.floor((state.term_width / 2) - (width / 2)) + 1,
		math.floor((state.term_height / 2) - (height / 2)) + 1,
		width,
		height,
		parent
	)
end

-- waits for specified keypress, or returns when a specified event is queued
local function waitForKey(key, break_events)
	os.pullEvent()
	local evt, _key, _repeat
	while true do
		evt, _key, _repeat = os.pullEvent()
		if (evt == "key") then
			if (not key) or (key == _key) then
				return _key
			end

		elseif (break_events) then
			if(break_events[evt]) then
				return false, evt, _key, _repeat
			end
		end
	end
end

-- all workspace-related functions
local Workspace = {}

first_run = not getConfig()
setConfig()

-- unmodified functions
_base.os.clock = os.clock
_base.os.startTimer = os.startTimer
_base.os.cancelTimer = os.cancelTimer
_base.os.setAlarm = os.setAlarm
_base.os.cancelAlarm = os.cancelAlarm
_base.os.clock = os.clock
_base.os.time = os.time
_base.os.epoch = os.epoch
_base.os.queueEvent = os.queueEvent
_base.term.redirect = term.redirect
_base.term.setPaletteColor = term.setPaletteColor
_base.term.setPaletteColour = term.setPaletteColour
_base.term.native = term.native
_base.fs.open = fs.open

Workspace.Get = function(x, y)
	if (not x) then
		return __G.__WS_SPACE
	else
		assert(type(x) == "number", "x must be number")
		assert(type(y) == "number", "y must be number")
		return state.workspaces[XYtoIndex(x, y)]
	end
end

Workspace.Select = function(x, y, instant_scroll)
	local key = XYtoIndex(x, y)
	if (state.workspaces[key]) then
		state.x = x
		state.y = y
		if (instant_scroll) then
			state.scroll_x = x
			state.scroll_y = y
		end
		state.do_redraw = true
		state.do_refresh = true
		state.timer.scroll = os.startTimer(0)
		return true
	else
		return false
	end
end

-- clears entire workspace grid
-- should only be used if you immediately
Workspace.Clear = function()
	state.workspaces = {}
	state.count = 0
	state.do_redraw = true
	state.do_refresh = true
end

-- checks if absolute x, y overlaps with the space's window
-- assumes that the window's height and width are equal to state.term_width and state.term_height
Workspace.CheckBounds = function(space, x, y)
	local space_absX = round(1 + (space.x - state.scroll_x + (state.drag_scroll[1] or 0)) * state.term_width)
	local space_absY = round(1 + (space.y - state.scroll_y + (state.drag_scroll[2] or 0)) * state.term_height)
	return (
		x >= space_absX and
		x <= space_absX + (state.term_width - 1) and
		y >= space_absY and
		y <= space_absY + (state.term_height - 1)
	)
end

-- ran at the beginning of every workspace coroutine resume
Workspace.SetCustomFunctions = function(space)
	assert(type(space) == "table", "space must be a table")
	assert(type(space.env) == "table", "space.env isn't a table?")

	space.env.fs.open = function(path, mode)
		if (space.resumes == 0) and (path == "rom/startup.lua") and (mode == "r") then
			real_file = _base.fs.open(path, "r")
			return {
				close = function(...)
					return real_file.close(...)
				end,
				readLine = function(...)
					return real_file.readLine(...)
				end,
				read = function(...)
					return real_file.read(...)
				end,
				seek = function(...)
					return real_file.seek(...)
				end,
				readAll = function(...)
					local output = real_file.readAll(...)
					output = output:gsub("shell.run%(v%)", "")
					output = output .. [[
						_G.__WS_SPACE.shell = shell
					]]
					return output
				end
			}

		else
			return _base.fs.open(path, mode)
		end

	end

	space.env.os.startTimer = function(duration)
		if type(duration) == "number" then
			state.new_timer_id = state.new_timer_id + 1
			space.timers[state.new_timer_id] = _base.os.clock() + space.clock_mod + duration
			return state.new_timer_id

		else
			error("bad argument #1 (number expected, got " .. type(duration) .. ")", 2)
		end
	end

	space.env.os.cancelTimer = function(id)
		if type(id) == "number" then
			space.timers[id] = nil

		else
			error("bad argument #1 (number expected, got " .. type(id) .. ")", 2)
		end
	end

	space.env.os.sleep = function(duration)
		local tID = space.env.os.startTimer(duration)
		local evt, _tID
		repeat
			evt, _tID = os.pullEvent()
		until (evt == "timer") and (_tID == tID)
	end

	__G.sleep = space.env.os.sleep

	space.env.os.clock = function()
		return _base.os.clock() + space.clock_mod
	end

	space.env.os.time = function(...)
		return (_base.os.time(...) + space.time_mod) % 24
	end

	space.env.os.epoch = function(...)
		return (_base.os.epoch(...) + space.epoch_mod)
	end

	space.env.os.setAlarm = function(time)
		if (type(time) == "number") then
			state.new_timer_id = state.new_timer_id + 1
			space.alarms[state.new_timer_id] = roundp(time % 24, 3)
			return state.new_timer_id

		else
			error("bad argument #1 (number expected, got " .. type(time) .. ")", 2)
		end
	end

	space.env.os.cancelAlarm = function(id)
		if type(id) == "number" then
			space.alarms[id] = nil

		else
			error("bad argument #1 (number expected, got " .. type(id) .. ")", 2)
		end
	end

	space.env.os.queueEvent = function(evt, ...)
		if type(evt) == "string" then
			if (focus_events[evt]) or (config.private_queued_events) then
				table.insert(space.queued_events, {evt, ...})

			else
				for k,v in pairs(state.workspaces) do
					table.insert(v.queued_events, {evt, ...})
				end
			end

		else
			error("bad argument #1 (number expected, got " .. type(evt) .. ")", 2)
		end
	end

	space.env.term.native = function(...)
		return space.og_window
	end

	space.env.term.setPaletteColor = function(key, r, g, b)
		assert(type(key) == "number", "bad argument #1 (expected number, got " .. type(key) .. ")")
		key = math.floor(key)
		if not (g or b) then
			r, g, b = colors.unpackRGB(r)
		end
		for i = 15, 0, -1 do
			if (key == 2^i) then
				break
			elseif (key > 2^i) then
				key = 2^i
				break
			end
		end
		assert(key >= 0 and key < 2^16, "Colour out of range")
		assert(type(r) == "number", "bad argument #2 (expected number, got " .. type(r) .. ")")
		assert(type(g) == "number", "bad argument #3 (expected number, got " .. type(g) .. ")")
		assert(type(b) == "number", "bad argument #4 (expected number, got " .. type(b) .. ")") 

		space.palette[key][1] = r
		space.palette[key][2] = g
		space.palette[key][3] = b

		if (space.x == state.x and space.y == state.y) then
			_base.term.setPaletteColor(key, r, g, b)
		end
	end

	space.env.term.setPaletteColour = space.env.term.setPaletteColor

	space.env.term.getPaletteColor = function(key)
		assert(type(key) == "number", "bad argument #1 (expected number, got " .. type(key) .. ")")
		return table.unpack(space.palette[key])
	end

	space.env.term.getPaletteColour = space.env.term.getPaletteColor

	space.env.term.redirect = function(target)
		assert(type(target) == "table", "redirect target must be a table")

		if (target == space.og_window) then
			space.redirect_target = nil

		else
			space.redirect_target = target
		end

		return _base.term.redirect(target)
	end

	__G.__WS_SPACE = space
end

-- ran at the end of every workspace coroutine resume
Workspace.ResetCustomFunctions = function()
	os.startTimer = _base.os.startTimer
	os.cancelTimer = _base.os.cancelTimer
	os.setAlarm = _base.os.setAlarm
	os.cancelAlarm = _base.os.cancelAlarm
	os.clock = _base.os.clock
	os.time = _base.os.time
	os.epoch = _base.os.epoch
	os.queueEvent = _base.os.queueEvent
	term.native = _base.term.native
	term.setPaletteColor = _base.term.setPaletteColor
	term.setPaletteColor = _base.term.setPaletteColor
	term.getPaletteColour = _base.term.getPaletteColor
	term.getPaletteColour = _base.term.getPaletteColor
	term.redirect = _base.term.redirect
	fs.open = _base.fs.open
end

Workspace.DrawInactiveScreen = function(space)
	term.clear()
	term.setCursorBlink(false)
	local base_y = math.ceil(state.term_height / 2) - 2

	if (space.last_error) then
		base_y = base_y - 1
	end

	local ccolor = ((space.x + space.y) % 2 == 0) and colors.gray or colors.lightGray
	local cchar = "\127"

	term.setTextColor(ccolor)
	awrite(cchar:rep(5), 1, "left")
	awrite(cchar:rep(5), 1, "right")
	awrite(cchar:rep(5), state.term_height, "left")
	awrite(cchar:rep(5), state.term_height, "right")
	for y = 2, 4 do
		awrite(cchar, y, "left")
		awrite(cchar, y, "right")
	end
	for y = state.term_height - 3, state.term_height - 1 do
		awrite(cchar, y, "left")
		awrite(cchar, y, "right")
	end

	term.setTextColor(colors.white)

--	cwrite("This workspace is inactive.", base_y)
	term.setTextColor(colors.yellow)
	cwrite(space.path .. " " .. table.concat(space.args, " "), base_y - 1)
	term.setTextColor(colors.white)
	cwrite("Press Space to start workspace.", base_y + 1)
	cwrite("(" .. space.x .. ", " .. space.y .. ")", base_y + 3)

	if (space.last_error) then
		cwrite("Last program's error:", base_y + 5)
		term.setTextColor(colors.red)
		cwrite(space.last_error:sub(1, state.term_width), base_y + 6)
		cwrite(space.last_error:sub(state.term_width + 1, state.term_width * 2), base_y + 7)
		cwrite(space.last_error:sub(state.term_width * 2 + 1), base_y + 8)
	end
end

-- makes a new workspace object
Workspace.Generate = function(path, x, y, active, ...)
	assert(type(x) == "number", "x must be number")
	assert(type(y) == "number", "y must be number")

	if (not fs.exists(path)) then
		error("invalid path '" .. path .. "'")
	end

	local ws_args = {...}

	local space = {
		path = path,
		args = ws_args,
		title = config.program_titles[path] or config.program_titles[fs.getName(path)] or fs.getName(path),
		x = x,
		y = y,
		env = {},
		paused = false,
		active = false,			-- false when waiting to start, true when running program
		allow_input = true,		-- when paused or unfocused, input is disallowed anyway
		start_on_program = active,	-- on creation, whether or not to launch the program immediately
		niceness = 0,			-- probably won't implement - influences how often the coroutine is resumed
		resumes = 0,

		time_mod = 0,
		time_last = 0,
		clock_mod = 0,
		clock_last = 0,
		epoch_mod = 0,
		epoch_last = 0,

		timers = {},
		alarms = {},
		yield_return = {},
		queued_events = {},

		window = window.create(
			state.term,
			1 + ((x - 1) * state.term_width),
			1 + ((y - 1) * state.term_height),
			state.term_width,
			state.term_height,
			false
		),
		palette = {},
		redirect_target = nil
	}
	space.og_window = space.window
	for i = 0, 15 do
		space.palette[2^i] = {term.nativePaletteColor(2^i)}
	end
	local runProgram

	local loaded_file = loadfile(path)

	local callable = function(space, ws_args)
		local status, err

		runProgram = function(...)
			term.redirect(space.window)
			space.active = true
			term.setTextColor(colors.white)
			term.setBackgroundColor(colors.black)
			term.clear()
			term.setCursorPos(1, 1)
			term.setCursorBlink(true)
			os.pullEvent()
			space.resumes = 0
			status, err = pcall(loaded_file, ...)
			if (status) then
				space.last_error = nil
			else
				space.last_error = err
			end
			-- reset state
			space.queued_events = {}
			space.time_mod = 0
			space.time_last = 0
			space.clock_mod = 0
			space.clock_last = 0
			space.epoch_mod = 0
			space.epoch_last = 0
			space.timers = {}
			space.resumes = 0
		end

		if (space.start_on_program) then
			os.queueEvent("timer", 0)
			runProgram(table.unpack(ws_args))
		end
		while true do
			space.active = false
			Workspace.DrawInactiveScreen(space)
			if ( waitForKey(keys.space, {["term_resize"] = true, ["workspace_swap"] = true}) ) then
				runProgram(table.unpack(ws_args))
			end
		end
	end

	if (space.path == "rom/programs/shell.lua") then
		_ENV.shell = nil
	else
		_ENV.shell = _base.shell
	end
	
	setmetatable(space.env, { __index = __G })
	space.env.multishell = _ENV.multishell
	setfenv(callable, space.env)
	setfenv(loaded_file, space.env)

	space.coroutine = coroutine.create(function()
		return callable(space, ws_args)
	end)
	space.callable = callable
	return space
end

-- makes a workspace and adds it to the grid
Workspace.Add = function(path, x, y, active, ...)
	-- try to convert "x,y" to numbers
	if (type(x) == "string") then
		x, y = IndexToXY(x)
	end

	path = path or config.default_program
	assert(type(x) == "number", "X must be number")
	assert(type(y) == "number", "Y must be number")

	local key = XYtoIndex(x, y)
	if (not state.workspaces[key]) then
		state.workspaces[key] = Workspace.Generate(path, x, y, active, ...)
		state.do_refresh = true
		state.count = state.count + 1

		state.do_refresh = true
		state.do_redraw = true
	end
	return state[key]
end

Workspace.Swap = function(x1, y1, x2, y2)
	assert(type(x1) == "number", "x1 must be number")
	assert(type(y1) == "number", "y1 must be number")
	assert(type(x2) == "number", "x2 must be number")
	assert(type(y2) == "number", "y2 must be number")

	local key1, key2 = XYtoIndex(x1, y1), XYtoIndex(x2, y2)
	if not (state.workspaces[key1] and state.workspaces[key2]) then
		return false
	else
		state.workspaces[key1], state.workspaces[key2] = state.workspaces[key2], state.workspaces[key1]
		state.workspaces[key1].x = x1
		state.workspaces[key1].y = y1
		state.workspaces[key2].x = x2
		state.workspaces[key2].y = y2
		state.x = x2
		state.y = y2
		state.do_refresh = true
		state.timer.scroll = os.startTimer(0)
		if (not state.workspaces[key1].active) then
			table.insert(state.workspaces[key1].queued_events, {"workspace_swap"})
		end
		if (not state.workspaces[key2].active) then
			table.insert(state.workspaces[key2].queued_events, {"workspace_swap"})
		end
		return true
	end
end

-- removes a workspace from the grid
Workspace.Remove = function(x, y)
	if (state.workspaces[XYtoIndex(x, y)]) then
		state.workspaces[XYtoIndex(x, y)] = nil
		state.do_refresh = true
		state.count = state.count - 1
		state.timer.scroll = os.startTimer(0)
		state.do_refresh = true
		state.do_redraw = true
	end
end

Workspace.CheckVisible = function(space, modx, mody)
	return (
		math.abs(space.x - state.scroll_x + (modx or 0)) < 1 and
		math.abs(space.y - state.scroll_y + (mody or 0)) < 1
	)
end

Workspace.PauseWorkspace = function(space, pause)
	if (space.paused == pause) then
		return
	end

	if (pause) then
		space.clock_last = os.clock() + space.clock_mod - 0.1
		space.time_last = os.time() + space.time_mod - 0.001
		space.epoch_last = os.epoch() + space.epoch_mod - 1000
		space.paused = true

	else
		space.clock_mod = roundp(space.clock_last - os.clock(), 3)
		space.time_mod = roundp(space.time_last - os.time(), 3)
		space.epoch_mod = space.epoch_last - os.epoch()
		space.paused = false
	end
end

Workspace.GetGridMinMax = function()
	if (state.count == 0) then
		return 0, 0, 0, 0
	end
	local max_x, max_y = 0, 0
	local min_x, min_y = math.huge, math.huge
	for key, space in pairs(state.workspaces) do
		max_x = math.max(max_x, space.x)
		max_y = math.max(max_y, space.y)
		min_x = math.min(min_x, space.x)
		min_y = math.min(min_y, space.y)
	end
	return min_x, min_y, max_x, max_y
end

Workspace.Notification = function(mode, option)
	if (not mode) then
		state.win_overlay.setVisible(false)
		state.is_overlay_visible = false
		state.do_redraw = true
		return
	end

	state.timer.osd = os.startTimer(config.osd_duration)

	if (mode == "pause") then
		local msg = option and "PAUSED" or "UNPAUSED"
		creposition(state.win_overlay, msg:len() + 2, 3)
		state.win_overlay.setVisible(true)
		state.is_overlay_visible = true
		state.win_overlay.setTextColor(colors.black)
		state.win_overlay.setBackgroundColor(colors.white)
		state.win_overlay.clear()
		cwrite(msg, 2, state.win_overlay)

	elseif (mode == "show_grid") then
		local min_x, min_y, max_x, max_y = Workspace.GetGridMinMax()
		local win = state.win_overlay
		local x, y

		for key, space in pairs(state.workspaces) do
			max_x = math.max(max_x, space.x)
			max_y = math.max(max_y, space.y)
			min_x = math.min(min_x, space.x)
			min_y = math.min(min_y, space.y)
		end

		local space = state.workspaces[XYtoIndex(state.x, state.y)]
		if (space.shell) then
			space.title = space.shell.getRunningProgram() or ""
		end
		space.title = config.program_titles[space.title] or config.program_titles[fs.getName(space.title)] or space.title

		local width
		if (space.active) then
			width = math.max(space.title:len() + 0, (max_x - min_x) + 3)
		else
			width = max_x - min_x + 3
		end

		creposition(state.win_overlay, width, (max_y - min_y) + 3)
		win.setVisible(true)
		state.is_overlay_visible = true
		win.setTextColor(colors.black)
		win.setBackgroundColor(colors.white)
		win.clear()

		if (space.title and space.active) then
			cwrite(space.title, 1, win)
		end

		y = 1
		for _y = min_y, max_y do
			y = y + 1
			x = math.floor((width / 2) - math.ceil((max_x - min_x) / 2))
			for _x = min_x, max_x do
				x = x + 1
				space = state.workspaces[XYtoIndex(_x, _y)]
				win.setCursorPos(x, y)
				if (space) then
					if (space.x == state.x and space.y == state.y) then
						win.setBackgroundColor(colors.lightGray)
					elseif space.active then
						win.setBackgroundColor(colors.gray)
					else
						win.setBackgroundColor(colors.black)
					end

					if space.paused then
						win.write("\7")
					else
						win.write(" ")
					end

				else
					win.setBackgroundColor(colors.white)
				end
			end
		end


	else
		os.cancelTimer(state.timer.osd)
	end

end

-- selects the topleft-most workspace
-- used if we desperately need SOME workspace to select, and don't care which
local function selectGoodWorkspace(do_scroll)
	local minx, miny = math.huge, math.huge
	local maxx, maxy = -math.huge, -math.huge
	for k,v in pairs(state.workspaces) do
		minx = math.min(v.x, minx)
		miny = math.min(v.y, miny)
		maxx = math.max(v.x, maxx)
		maxy = math.max(v.y, maxy)
	end
	for x = minx, maxx do
		if (state.workspaces[XYtoIndex(x, miny)]) then
			state.x = x
			state.y = miny
			if (do_scroll) then
				state.scroll_x = x
				state.scroll_y = miny
			end
			break
		end
	end
end

local function canRunWorkspace(space, evt, ignore_focus)
	-- never trust a programming teacher who tells you to never early return
	if (not evt) then
		return false

	elseif (space.paused) then
		return false

	elseif (focus_events[evt[1]] and (space.x ~= state.x or space.y ~= state.y) and (not ignore_focus)) then
		return false
	
	elseif (focus_events[evt[1]] and not space.allow_input) then
		return false

	elseif (space.yield_return[2] == nil) or (space.yield_return[2] == evt[1]) or (evt[1] == "terminate") then
		return true
	end

	return false
end

local function tryMoveViewport(x, y, do_skip)
	if (Workspace.Select(state.x + x, state.y + y)) then
		return true

	elseif (do_skip) then
		-- do some workspace skipping logic
		local min_x, min_y, max_x, max_y = Workspace.GetGridMinMax()
		for i = math.min(min_x, min_y), math.max(max_x, max_y) do
			if (x ~= 0) then x = x + (x / math.abs(x)) end
			if (y ~= 0) then y = y + (y / math.abs(y)) end
			if (Workspace.Select(state.x + x, state.y + y)) then
				return true
			end
		end
		return false
	else
		return false
	end
end

local function drawVoid(win)
	local line_ch = ("f"):rep(state.term_width)
	local line_tx = ("f"):rep(state.term_width)
	local line_bg = ("f"):rep(state.term_width)

	for y = 1, state.term_height do
		win.setCursorPos(1, y)
		win.blit(
			line_ch:gsub(".", function() return string.char(math.random(128, 159)) end),
			line_tx:gsub(".", function() return math.random(1, 2) and "7" or "f" end),
			line_bg
		)
	end
end

-- set up fake _G table
__G = {
	Workspace = Workspace,
	__WS_SPACE = {},
	__WORKSPACE_RUNNING = true,
}
__G._G = __G

setmetatable(__G, {
	__index = function(tbl, key)
		return _G[key]
	end,

	__newindex = function(tbl, key, value)
		_G[key] = value
	end
})


local function main()
	state.active = true
	term.clear()

	for k,v in pairs(config.space_grid) do
		Workspace.Add(config.default_program, k, nil, false)
	end

	state.x = 1
	state.y = 1
	if not (state.workspaces[XYtoIndex(state.x, state.y)]) then
		selectGoodWorkspace(true)
	end
	state.workspaces[XYtoIndex(state.x, state.y)].start_on_program = true

	local evt = {}
	state.timer.tick = os.startTimer(0)
	state.timer.redraw = os.startTimer(config.redraw_tick_delay)

	state.win_overlay = window.create(term.current(), 1, 1, 1, 1, false)

	-- in the loop, absolute window position of each workspace
	local space_absX, space_absY = 0, 0

	-- used as reference for fake timers
	local current_clock = os.clock()
	local current_time = os.time()

	-- if true, don't send the command keystrokes to the workspace
	local did_command = false

	-- used for click to drag stuff
	state.drag_spots = {{}, {}}
	state.drag_scroll = {0, 0}

	-- used to limit how many times a workspace can resume itself in a row
	local times_queued = 0
	local max_queued = 10

	-- reference for currently selected state
	local _space

	local is_redraw_tick = false
	local c_term = term.current()

	if (fs.exists(fs.combine(_CONFIG_DIR, _WS_STARTUP_PATH))) then
		local _f = loadfile( fs.combine(_CONFIG_DIR, _WS_STARTUP_PATH) )
		local _e = {Workspace = Workspace, state = state}
		setmetatable(_e, {__index = _ENV})
		setfenv(_f, _e)
		_f()
	else
		local file = fs.open(fs.combine(_CONFIG_DIR, _WS_STARTUP_PATH), "w")
		file.writeLine("-- This file will be ran once upon starting Workspace after spawning all instances.")
		file.writeLine("-- You can use this file to arrange Workspaces how you want.")
		file.writeLine("-- Example: ")
		file.writeLine("-- Workspace.Clear()")
		file.writeLine("-- Workspace.Add(nil, 1, 1, false) -- defaults to shell.lua") 
		file.writeLine("-- Workspace.Add(\"rom/programs/fun/worm.lua\", 2, 1, true)")
		file.writeLine("-- Workspace.Select(2, 1)\n\n")
		file.close()
	end

	while (state.active) do

		is_redraw_tick = false

		evt = {os.pullEventRaw()}

		_space = state.workspaces[XYtoIndex(state.x, state.y)]

		if (evt[1] == "key") then
			if (not evt[3]) then
				keysDown[ evt[2] ] = os.epoch()
				keysDown[ keys.ctrl ] = (keysDown[keys.leftCtrl] or keysDown[keys.rightCtrl])
				keysDown[ keys.alt ] = (keysDown[keys.leftAlt] or keysDown[keys.rightAlt])
				keysDown[ keys.shift ] = (keysDown[keys.leftShift] or keysDown[keys.rightShift])

				-- handle key combinations

				-- CTRL + SHIFT + ?
				if (keysDown[keys.ctrl] and keysDown[keys.shift]) then

					if (evt[2] == keys.right) then
						if keysDown[keys.tab] then
							Workspace.Swap(state.x, state.y, state.x + 1, state.y)
						else
							tryMoveViewport(1, 0, true)
						end
						Workspace.Notification("show_grid")
						did_command = true

					elseif (evt[2] == keys.left) then
						if keysDown[keys.tab] then
							Workspace.Swap(state.x, state.y, state.x - 1, state.y)
						else
							tryMoveViewport(-1, 0, true)
						end
						Workspace.Notification("show_grid")
						did_command = true

					elseif (evt[2] == keys.up) then
						if keysDown[keys.tab] then
							Workspace.Swap(state.x, state.y, state.x, state.y - 1)
						else
							tryMoveViewport(0, -1, true)
						end
						Workspace.Notification("show_grid")
						did_command = true

					elseif (evt[2] == keys.down) then
						if keysDown[keys.tab] then
							Workspace.Swap(state.x, state.y, state.x, state.y + 1)
						else
							tryMoveViewport(0, 1, true)
						end
						Workspace.Notification("show_grid")
						did_command = true

					elseif (evt[2] == keys.p) then
						if (_space.active) then
							Workspace.PauseWorkspace(_space, not _space.paused)
							Workspace.Notification("pause", _space.paused)
							did_command = true
						end

					elseif (evt[2] == keys.w) then
						Workspace.Add(config.default_program, state.x, state.y - 1)
						if (config.update_space_grid) then
							config.space_grid[XYtoIndex(state.x, state.y - 1)] = true
							setConfig()
						end
						Workspace.Notification("show_grid")
						did_command = true

					elseif (evt[2] == keys.s) then
						Workspace.Add(config.default_program, state.x, state.y + 1)
						if (config.update_space_grid) then
							config.space_grid[XYtoIndex(state.x, state.y + 1)] = true
							setConfig()
						end
						Workspace.Notification("show_grid")
						did_command = true

					elseif (evt[2] == keys.a) then
						Workspace.Add(config.default_program, state.x - 1, state.y)
						if (config.update_space_grid) then
							config.space_grid[XYtoIndex(state.x - 1, state.y)] = true
							setConfig()
						end
						Workspace.Notification("show_grid")
						did_command = true

					elseif (evt[2] == keys.d) then
						Workspace.Add(config.default_program, state.x + 1, state.y)
						if (config.update_space_grid) then
							config.space_grid[XYtoIndex(state.x + 1, state.y)] = true
							setConfig()
						end
						Workspace.Notification("show_grid")
						did_command = true

					elseif (evt[2] == keys.q) then
						if (state.count >= 2) then
							Workspace.Remove(state.x, state.y)
							if (config.update_space_grid) then
								config.space_grid[XYtoIndex(state.x, state.y)] = nil
								setConfig()
							end
							if (state.workspaces[XYtoIndex(state.x - 1, state.y)]) then
								state.x = state.x - 1

							elseif (state.workspaces[XYtoIndex(state.x + 1, state.y)]) then
								state.x = state.x + 1

							elseif (state.workspaces[XYtoIndex(state.x, state.y - 1)]) then
								state.y = state.y - 1

							elseif (state.workspaces[XYtoIndex(state.x, state.y + 1)]) then
								state.y = state.y + 1

							else
								selectGoodWorkspace(false)
							end

							Workspace.Notification("show_grid")
							did_command = true
						end
					end

				end
			end

		elseif (evt[1] == "key_up") then
			keysDown[ evt[2] ] = false
			keysDown[ keys.ctrl ] = (keysDown[keys.leftCtrl] or keysDown[keys.rightCtrl])
			keysDown[ keys.alt ] = (keysDown[keys.leftAlt] or keysDown[keys.rightAlt])
			keysDown[ keys.shift ] = (keysDown[keys.leftShift] or keysDown[keys.rightShift])

		elseif (evt[1] == "mouse_click" and evt[2] == 1 ) then
			if (keysDown[keys.ctrl] and keysDown[keys.shift]) then
				did_command = true
				state.is_dragging = true
				state.drag_spots[1] = {evt[3], evt[4]}
				state.drag_spots[2] = {}

			else
				state.drag_spots[1] = {}
				state.drag_spots[2] = {}
				state.drag_scroll[1] = 0
				state.drag_scroll[2] = 0
				state.is_dragging = false
			end

		elseif (evt[1] == "mouse_drag" and evt[2] == 1) then
			if (state.is_dragging) then
				if (not state.drag_spots[1][1]) or (not state.drag_spots[1][2]) then
					state.drag_spots[1] = {evt[3], evt[4]}
				end
				did_command = true
				state.do_refresh = true
				state.drag_spots[2] = {evt[3], evt[4]}
				state.drag_scroll = {
					(state.drag_spots[2][1] - state.drag_spots[1][1]) / state.term_width,
					(state.drag_spots[2][2] - state.drag_spots[1][2]) / state.term_height,
				}
			end

		elseif (evt[1] == "mouse_up" and evt[2] == 1) then
			if (state.is_dragging) then
				local modx, mody = 0, 0
				if (state.drag_scroll[1] > 0.3) then
					modx = -math.ceil(state.drag_scroll[1] - 0.3)

				elseif (state.drag_scroll[1] < -0.3) then
					modx = -math.floor(state.drag_scroll[1] + 0.3)

				end

				if (state.drag_scroll[2] > 0.3) then
					mody = -math.ceil(state.drag_scroll[2] - 0.3)

				elseif (state.drag_scroll[2] < -0.3) then
					mody = -math.floor(state.drag_scroll[2] + 0.3)

				end

				if (modx ~= 0 or mody ~= 0) then
					tryMoveViewport(modx, mody, true)
				end

				state.scroll_x = state.scroll_x - state.drag_scroll[1]
				state.scroll_y = state.scroll_y - state.drag_scroll[2]

				state.do_refresh = true
				state.timer.scroll = os.startTimer(0)
			end
			state.is_dragging = false
			state.drag_spots[1] = {}
			state.drag_spots[2] = {}
			state.drag_scroll[1] = 0
			state.drag_scroll[2] = 0

		elseif (evt[1] == "timer") then
			if (evt[2] == state.timer.scroll) then
				local xdiff = state.x - state.scroll_x
				local ydiff = state.y - state.scroll_y

				if (math.abs(xdiff) < 0.01) then
					state.scroll_x = state.x
				else
					state.timer.scroll = os.startTimer(config.scroll_delay)
					state.scroll_x = state.scroll_x + (xdiff * config.scroll_speed)
				end

				if (math.abs(ydiff) < 0.01) then
					state.scroll_y = state.y
				else
					state.timer.scroll = os.startTimer(config.scroll_delay)
					state.scroll_y = state.scroll_y + (ydiff * config.scroll_speed)
				end

				state.do_redraw = true
				state.do_refresh = true

			elseif (evt[2] == state.timer.tick) then
				state.timer.tick = os.startTimer(0)

			elseif (evt[2] == state.timer.osd) then
				state.win_overlay.setVisible(false)
				state.is_overlay_visible = false
				state.do_redraw = true
				state.do_refresh = true

			elseif (evt[2] == state.timer.redraw) then
				is_redraw_tick = true
				state.do_redraw = true
				state.timer.redraw = os.startTimer(config.redraw_tick_delay)

			end

		elseif (evt[1] == "terminate") then
			if (_space.active == false) then
				state.active = false
			end

		elseif (evt[1] == "term_resize") then
			state.term_width, state.term_height = term.getSize()
			state.alt_term.reposition(1, 1, state.term_width, state.term_height)
			state.do_refresh = true

		end

		-- reload config file if neccesary
		if (state.do_refresh_config) then
			state.do_refresh_config = false
			getConfig()
			setConfig()
		end

		current_clock = os.clock()
		current_time = os.time()

		state.is_void_visible = not (
			state.x == (state.scroll_x - (state.drag_scroll[1] or 0)) and
			state.y == (state.scroll_y - (state.drag_scroll[2] or 0))
		)

		if (state.is_void_visible or state.is_overlay_visible) then

			state.do_refresh = true

			if (not state.use_alt_term) then
				wreposition(state.win_overlay, nil, nil, nil, nil, state.alt_term)
			end
			state.use_alt_term = true
			if (is_redraw_tick) then
				if (config.do_draw_void) then
					drawVoid(state.alt_term)
				else
					state.alt_term.clear()
				end
			end

		else
			if (state.use_alt_term) then
				state.do_redraw = true
				wreposition(state.win_overlay, nil, nil, nil, nil, state.term)
			end
			state.use_alt_term = false
		end

		-- iterate through all workspaces and do shit

		for key, space in pairs(state.workspaces) do

			-- handle terminal resizing
			space_absX = round(1 + (space.x - state.scroll_x + (state.drag_scroll[1] or 0)) * state.term_width)
			space_absY = round(1 + (space.y - state.scroll_y + (state.drag_scroll[2] or 0)) * state.term_height)

			if (state.do_refresh) then
				space.window.reposition(
					space_absX,
					space_absY,
					state.term_width,
					state.term_height,
					(state.use_alt_term and state.alt_term or state.term)
				)
			end
			-- handle manually queued events
			times_queued = 0

			repeat

				-- handle fake timers
				for tID, tClock in pairs(space.timers) do
					if (tClock <= current_clock + space.clock_mod) then
						space.timers[tID] = nil
						table.insert(space.queued_events, {"timer", tID})
					end
				end

				-- handle fake alarms
				for aID, aTime in pairs(space.alarms) do
					if (
						(((current_time + space.time_mod) % 24) >= aTime) and 
						(((current_time + space.time_mod) % 24) <= aTime + 0.001)
					) then
						space.alarms[aID] = nil
						table.insert(space.queued_events, {"alarm", aID})
					end
				end

				if (space.queued_events[1]) then
					if (space.queued_events[1][1] == "workspace_refresh_config") then
						state.do_refresh_config = true
						table.remove(space.queued_events, 1)

					elseif (canRunWorkspace(space, space.queued_events[1], true) or (state.resumes == 0)) then
						if (state.x == space.x and state.y == space.y) then
							space.window.restoreCursor()
						end
						c_term = term.redirect(space.redirect_target or space.window)
						Workspace.SetCustomFunctions(space)
						space.yield_return = {coroutine.resume(space.coroutine, table.unpack(space.queued_events[1] or {}))}
						Workspace.ResetCustomFunctions()
						times_queued = times_queued + 1
						space.resumes = space.resumes + 1
						term.redirect(c_term)
						table.remove(space.queued_events, 1)
					end
				end

			until (not canRunWorkspace(space, space.queued_events[1])) or (times_queued > max_queued)

			-- change palette
			if (state.do_refresh) and (is_redraw_tick) and (space.x == state.x and space.y == state.y) then
				for i = 0, 15 do
					space.window.setPaletteColor(2^i, table.unpack(space.palette[2^i]))
					state.win_overlay.setPaletteColor(2^i, table.unpack(space.palette[2^i]))
				end
			end

			-- handle real events
			if not ((did_command and focus_events[evt[1]]) or (evt[1] == "timer")) then
				if (canRunWorkspace(space, evt)) then
					if (state.x == space.x and state.y == space.y) then
						space.window.restoreCursor()
					end
					c_term = term.redirect(space.redirect_target or space.window)
					Workspace.SetCustomFunctions(space)
					space.yield_return = {coroutine.resume(space.coroutine, table.unpack(evt))}
					space.resumes = space.resumes + 1
					Workspace.ResetCustomFunctions()
					term.redirect(c_term)
				end
			end

			-- reposition windows so they move like a real desktop grid
			if (Workspace.CheckVisible(space, state.drag_scroll[1], state.drag_scroll[2])) then
				space.window.setVisible(true)
				if (space.x ~= state.scroll_x) or (space.y ~= state.scroll_y) then
					space.window.reposition(space_absX, space_absY)
				end
			else
				space.window.setVisible(false)
			end

		end

		if (is_redraw_tick) then
			if (state.is_overlay_visible) then
				state.win_overlay.redraw()
			end

			if (state.use_alt_term) then
				state.alt_term.setVisible(true)
				state.alt_term.redraw()
				state.alt_term.setVisible(false)
			end

		end

		state.do_redraw = false
		state.do_refresh = false
		did_command = false

	end

	return true
end

local function handleError(err)
	term.clear()
	term.setCursorPos(1, 1)
	printError(err)
end

-- :)
if math.random(1, 2^16) == 100 then
	printError("Fuck you, Curse of Ra")
	return false
end

local status, err

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorPos(1, 1)
term.clear()
if (first_run) then
	print("Welcome to Workspace!\n")
	showHelp()
	print("\nPress any key to continue.")
	waitForKey()
end

while (state.active) do
	status, err = pcall(main)
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
	if (not status) then
		state.active = false
		handleError(err)

	else
		term.clear()
		term.setCursorPos(1, 1)
		print("Thanks for using Workspace!")
	end
end
