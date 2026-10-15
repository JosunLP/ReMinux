-- SPDX-FileCopyrightText: 2017 Daniel Ratcliffe
-- parts added by the minux team
-- SPDX-License-Identifier: LicenseRef-CCPL

local make_package = dofile("rom/modules/main/cc/require.lua").make

local multishell = multishell
local parentShell = shell
local parentTerm = term.current()

if multishell then
    multishell.setTitle(multishell.getCurrent(), "shell")
end

local bExit = false
local sDir = parentShell and parentShell.dir() or ""
local sPath = parentShell and parentShell.path() or ".:/rom/programs"
local tAliases = parentShell and parentShell.aliases() or {}
local tCompletionInfo = parentShell and parentShell.getCompletionInfo() or {}
local tProgramStack = {}

local shell = {} --- @export
local function createShellEnv(dir)
    local env = { shell = shell, multishell = multishell }
    env.require, env.package = make_package(env, dir)
    return env
end

-- Set up a dummy require based on the current shell, for loading some of our internal dependencies.
local require
do
    local env = setmetatable(createShellEnv("/rom/programs"), { __index = _ENV })
    require = env.require
end
local expect = require("cc.expect").expect
local exception = require "cc.internal.exception"
local parser = dofile("/etc/minux-main/workspace/parser.lua")
local executor = dofile("/etc/minux-main/workspace/executor.lua")
local baseRead = read
local baseWrite = write
local basePrint = print

local function isSuccessfulProgramResult(result)
    if result == nil or result == true then
        return true
    end
    if result == false then
        return false
    end
    if type(result) == "number" then
        return result == 0
    end
    return true
end

-- Colours
local promptColour, textColour, bgColour
if term.isColour() then
    promptColour = colours.yellow
    textColour = colours.white
    bgColour = colours.black
else
    promptColour = colours.white
    textColour = colours.white
    bgColour = colours.black
end

local function tokenise(...)
    local sLine = table.concat({ ... }, " ")
    local words, err = parser.tokeniseWords(sLine)
    return words or {}, err
end

-- Execute a program using os.run, unless a shebang is present.
local function executeProgram(remainingRecursion, path, args, ioContext)
    local file, err = fs.open(path, "r")
    if not file then
        printError(err)
        return false
    end

    -- First check if the file begins with a #!
    local contents = file.readLine() or ""

    if contents:sub(1, 2) == "#!" then
        file.close()

        remainingRecursion = remainingRecursion - 1
        if remainingRecursion == 0 then
            printError("Hashbang recursion depth limit reached when loading file: " .. path)
            return false
        end

        -- Load the specified hashbang program instead
        local hashbangArgs, tokeniseErr = tokenise(contents:sub(3))
        if tokeniseErr ~= nil then
            printError("Invalid hashbang in " .. path .. ": " .. (tokeniseErr or "parse error"))
            return false
        end
        local originalHashbangPath = table.remove(hashbangArgs, 1)
        if originalHashbangPath == nil or originalHashbangPath == "" then
            printError("Invalid hashbang in " .. path .. ": missing interpreter")
            return false
        end
        local resolvedHashbangProgram = shell.resolveProgram(originalHashbangPath)
        if not resolvedHashbangProgram then
            printError("Hashbang program not found: " .. originalHashbangPath)
            return false
        elseif resolvedHashbangProgram == "rom/programs/shell.lua" and #hashbangArgs == 0 then
            printError("Cannot use the shell as a hashbang program")
            return false
        end

        -- Add the path and any arguments to the interpreter's arguments
        table.insert(hashbangArgs, path)
        for _, v in ipairs(args) do
            table.insert(hashbangArgs, v)
        end

        hashbangArgs[0] = originalHashbangPath
        return executeProgram(remainingRecursion, resolvedHashbangProgram, hashbangArgs, ioContext)
    end

    contents = contents .. "\n" .. (file.readAll() or "")
    file.close()

    local dir = fs.getDir(path)
    local env = setmetatable(createShellEnv(dir), { __index = _G })
    env.arg = args
    env.print = function(...)
        local values = {}
        for i = 1, select("#", ...) do
            values[i] = tostring(select(i, ...))
        end
        if minux ~= nil and type(minux.writeOutputLine) == "function" then
            minux.writeOutputLine(table.concat(values, "\t"))
        else
            basePrint(...)
        end
    end
    env.write = function(text)
        local context = minux ~= nil and type(minux.getIoContext) == "function" and minux.getIoContext() or nil
        if type(context) == "table" and type(context.write) == "function" then
            context.write(tostring(text or ""))
            return
        end
        baseWrite(tostring(text or ""))
    end
    env.read = function(...)
        local context = minux ~= nil and type(minux.getIoContext) == "function" and minux.getIoContext() or nil
        if type(context) == "table" and type(context.read) == "function" then
            return context.read(...)
        end
        return baseRead(...)
    end
    env.io = setmetatable({
        write = function(...)
            env.write(...)
        end,
    }, { __index = io })

    local func, err = load(contents, "@/" .. path, nil, env)
    if not func then
        -- We had a syntax error. Attempt to run it through our own parser if
        -- the file is "small enough", otherwise report the original error.
        if #contents < 1024 * 128 then
            local parser = require "cc.internal.syntax"
            if parser.parse_program(contents) then printError(err) end
        else
            printError(err)
        end

        return false
    end

    if settings.get("bios.strict_globals", false) then
        getmetatable(env).__newindex = function(_, name)
            error("Attempt to create global " .. tostring(name), 2)
        end
    end

    if ioContext ~= nil and minux ~= nil and type(minux.pushIoContext) == "function" then
        minux.pushIoContext(ioContext)
    end
    local ok, result, co = exception.try(func, table.unpack(args, 1, args.n))
    if ioContext ~= nil and minux ~= nil and type(minux.popIoContext) == "function" then
        minux.popIoContext()
    end

    if ok then
        return isSuccessfulProgramResult(result)
    end

    if result and result ~= "" then
        printError(result)
        exception.report(result, co)
    end

    return false
end

-- Damerau-free Levenshtein distance, used for "did you mean" hints.
local function editDistance(left, right)
    if math.abs(#left - #right) > 2 then
        return 3
    end
    local previous = {}
    for j = 0, #right do previous[j] = j end
    for i = 1, #left do
        local current = { [0] = i }
        for j = 1, #right do
            local cost = string.sub(left, i, i) == string.sub(right, j, j) and 0 or 1
            current[j] = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        end
        previous = current
    end
    return previous[#right]
end

local function suggestCommands(command)
    if command:find("/") or #command < 2 then
        return {}
    end
    local candidates = {}
    for alias in pairs(tAliases) do candidates[alias] = true end
    for _, program in ipairs(shell.programs()) do candidates[program] = true end
    local matches = {}
    for candidate in pairs(candidates) do
        local distance = editDistance(command, candidate)
        if distance <= (#command <= 3 and 1 or 2) then
            matches[#matches + 1] = { name = candidate, distance = distance }
        end
    end
    table.sort(matches, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.name < b.name
    end)
    local names = {}
    for index = 1, math.min(3, #matches) do names[index] = matches[index].name end
    return names
end

local function reportUnknownCommand(command)
    printError(tostring(command) .. ": command not found")
    local suggestions = suggestCommands(tostring(command))
    if #suggestions > 0 then
        local previousColour = term.getTextColour()
        if term.isColour() then term.setTextColour(colours.lightGrey) end
        print("Did you mean: " .. table.concat(suggestions, ", ") .. "?")
        term.setTextColour(previousColour)
    end
end

local function runResolvedCommand(command, arguments, ioContext)
    local sPath = shell.resolveProgram(command)
    if sPath ~= nil then
        tProgramStack[#tProgramStack + 1] = sPath
        if multishell then
            local sTitle = fs.getName(sPath)
            if sTitle:sub(-4) == ".lua" then
                sTitle = sTitle:sub(1, -5)
            end
            multishell.setTitle(multishell.getCurrent(), sTitle)
        end

        local result = executeProgram(100, sPath, arguments, ioContext)

        tProgramStack[#tProgramStack] = nil
        if multishell then
            if #tProgramStack > 0 then
                local sTitle = fs.getName(tProgramStack[#tProgramStack])
                if sTitle:sub(-4) == ".lua" then
                    sTitle = sTitle:sub(1, -5)
                end
                multishell.setTitle(multishell.getCurrent(), sTitle)
            else
                multishell.setTitle(multishell.getCurrent(), "shell")
            end
        end
        return result
    else
        reportUnknownCommand(command)
        return false
    end
end

--- Run a program with the supplied arguments.
function shell.execute(command, ...)
    expect(1, command, "string")
    for i = 1, select('#', ...) do
        expect(i + 1, select(i, ...), "string")
    end
    return runResolvedCommand(command, { [0] = command, ... }, nil)
end

function shell.executeWithContext(command, arguments, ioContext)
    expect(1, command, "string")
    expect(2, arguments, "table")
    expect(3, ioContext, "table", "nil")
    local argv = { [0] = command, n = #arguments }
    for index = 1, #arguments do
        expect(index + 2, arguments[index], "string")
        argv[index] = arguments[index]
    end
    return runResolvedCommand(command, argv, ioContext)
end

-- Install shell API
function shell.run(...)
    local argumentCount = select("#", ...)
    if argumentCount == 0 then
        return false
    end
    if argumentCount > 1 then
        local arguments = { ... }
        local sCommand = arguments[1]
        if sCommand ~= nil then
            return shell.execute(sCommand, table.unpack(arguments, 2))
        end
        return false
    end
    local line = ...
    local ast, err = parser.parse(line)
    if ast == nil then
        printError(err)
        return false
    end
    if ast.kind ~= "empty" then
        local ok, err = executor.executeAst(ast, {
            executeCommand = function(commandNode, ioContext)
                local arguments = {}
                for index = 2, #commandNode.argv do
                    arguments[#arguments + 1] = commandNode.argv[index]
                end
                return shell.executeWithContext(commandNode.argv[1], arguments, ioContext)
            end,
            requirePermission = function(path, operation)
                return minux.requirePermission(path, operation)
            end,
            resolvePath = function(path)
                return shell.resolve(path)
            end,
        }, nil)
        if ok ~= true and err ~= nil and err ~= "" then
            printError(err)
        end
        return ok
    end
    return false
end

--- Exit the current shell.
function shell.exit()
    bExit = true
end

--- Return the current working directory. This is what is displayed before the
function shell.dir()
    return sDir
end

--- Set the current working directory.
function shell.setDir(dir)
    expect(1, dir, "string")
    if not fs.isDir(dir) then
        error("Not a directory", 2)
    end
    sDir = fs.combine(dir, "")
end

--- Set the path where programs are located.
function shell.path()
    return sPath
end

--- Set the [current program path][`path`].
function shell.setPath(path)
    expect(1, path, "string")
    sPath = path
end

local function homeDirectory()
    local user = _G.login
    if type(user) ~= "string" or user == "" or user == "foo" then
        return ""
    end
    return "home/" .. user
end

--- Resolve a relative path to an absolute path. "~" expands to the home
-- directory of the logged-in user.
function shell.resolve(path)
    expect(1, path, "string")
    if path == "~" or string.sub(path, 1, 2) == "~/" then
        -- Without a logged-in user there is no home; don't map "~" to "/".
        local home = homeDirectory()
        if home ~= "" then
            return fs.combine(home, string.sub(path, 3))
        end
    end
    local sStartChar = string.sub(path, 1, 1)
    if sStartChar == "/" or sStartChar == "\\" then
        return fs.combine("", path)
    else
        return fs.combine(sDir, path)
    end
end

local function pathWithExtension(_sPath, _sExt)
    local nLen = #_sPath
    local sEndChar = string.sub(_sPath, nLen, nLen)
    -- Remove any trailing slashes so we can add an extension to the path safely
    if sEndChar == "/" or sEndChar == "\\" then
        _sPath = string.sub(_sPath, 1, nLen - 1)
    end
    return _sPath .. "." .. _sExt
end

--- Resolve a program, using the [program path][`path`] and list of [aliases][`aliases`].
function shell.resolveProgram(command)
    expect(1, command, "string")
    -- Substitute aliases firsts
    if tAliases[command] ~= nil then
        command = tAliases[command]
    end

    -- If the path is a global path, use it directly
    if command:find("/") or command:find("\\") then
        local sPath = shell.resolve(command)
        if fs.exists(sPath) and not fs.isDir(sPath) then
            return sPath
        else
            local sPathLua = pathWithExtension(sPath, "lua")
            if fs.exists(sPathLua) and not fs.isDir(sPathLua) then
                return sPathLua
            end
        end
        return nil
    end

     -- Otherwise, look on the path variable
    for sPath in string.gmatch(sPath, "[^:]+") do
        sPath = fs.combine(shell.resolve(sPath), command)
        if fs.exists(sPath) and not fs.isDir(sPath) then
            return sPath
        else
            local sPathLua = pathWithExtension(sPath, "lua")
            if fs.exists(sPathLua) and not fs.isDir(sPathLua) then
                return sPathLua
            end
        end
    end

    -- Not found
    return nil
end

--- Return a list of all programs on the [path][`shell.path`].
function shell.programs(include_hidden)
    expect(1, include_hidden, "boolean", "nil")

    local tItems = {}

    -- Add programs from the path
    for sPath in string.gmatch(sPath, "[^:]+") do
        sPath = shell.resolve(sPath)
        if fs.isDir(sPath) then
            local tList = fs.list(sPath)
            for n = 1, #tList do
                local sFile = tList[n]
                if not fs.isDir(fs.combine(sPath, sFile)) and
                   (include_hidden or string.sub(sFile, 1, 1) ~= ".") then
                    if #sFile > 4 and sFile:sub(-4) == ".lua" then
                        sFile = sFile:sub(1, -5)
                    end
                    tItems[sFile] = true
                end
            end
        end
    end

    -- Sort and return
    local tItemList = {}
    for sItem in pairs(tItems) do
        table.insert(tItemList, sItem)
    end
    table.sort(tItemList)
    return tItemList
end

local function completeProgram(sLine)
    local bIncludeHidden = settings.get("shell.autocomplete_hidden")
    if #sLine > 0 and (sLine:find("/") or sLine:find("\\")) then
        -- Add programs from the root
        return fs.complete(sLine, sDir, {
            include_files = true,
            include_dirs = false,
            include_hidden = bIncludeHidden,
        })

    else
        local tResults = {}
        local tSeen = {}

        -- Add aliases
        for sAlias in pairs(tAliases) do
            if #sAlias > #sLine and string.sub(sAlias, 1, #sLine) == sLine then
                local sResult = string.sub(sAlias, #sLine + 1)
                if not tSeen[sResult] then
                    table.insert(tResults, sResult)
                    tSeen[sResult] = true
                end
            end
        end

        -- Add all subdirectories. We don't include files as they will be added in the block below
        local tDirs = fs.complete(sLine, sDir, {
            include_files = false,
            include_dirs = false,
            include_hidden = bIncludeHidden,
        })
        for i = 1, #tDirs do
            local sResult = tDirs[i]
            if not tSeen[sResult] then
                table.insert (tResults, sResult)
                tSeen [sResult] = true
            end
        end

        -- Add programs from the path
        local tPrograms = shell.programs()
        for n = 1, #tPrograms do
            local sProgram = tPrograms[n]
            if #sProgram > #sLine and string.sub(sProgram, 1, #sLine) == sLine then
                local sResult = string.sub(sProgram, #sLine + 1)
                if not tSeen[sResult] then
                    table.insert(tResults, sResult)
                    tSeen[sResult] = true
                end
            end
        end

        -- Sort and return
        table.sort(tResults)
        return tResults
    end
end

local function completeProgramArgument(sProgram, nArgument, sPart, tPreviousParts)
    local tInfo = tCompletionInfo[sProgram]
    if tInfo then
        return tInfo.fnComplete(shell, nArgument, sPart, tPreviousParts)
    end
    return nil
end

--- Complete a shell command line.
function shell.complete(sLine)
    expect(1, sLine, "string")
    if #sLine > 0 then
        local tWords, err = tokenise(sLine)
        if err ~= nil then
            return nil, err
        end
        local nIndex = #tWords
        if string.sub(sLine, #sLine, #sLine) == " " then
            nIndex = nIndex + 1
        end
        if nIndex == 1 then
            local sBit = tWords[1] or ""
            local sPath = shell.resolveProgram(sBit)
            if tCompletionInfo[sPath] then
                return { " " }
            else
                local tResults = completeProgram(sBit)
                for n = 1, #tResults do
                    local sResult = tResults[n]
                    local sPath = shell.resolveProgram(sBit .. sResult)
                    if tCompletionInfo[sPath] then
                        tResults[n] = sResult .. " "
                    end
                end
                return tResults
            end

        elseif nIndex > 1 then
            local sPath = shell.resolveProgram(tWords[1])
            local sPart = tWords[nIndex] or ""
            local tPreviousParts = tWords
            tPreviousParts[nIndex] = nil
            return completeProgramArgument(sPath , nIndex - 1, sPart, tPreviousParts)

        end
    end
    return nil
end

--- Complete the name of a program.
function shell.completeProgram(program)
    expect(1, program, "string")
    return completeProgram(program)
end

--- Set the completion function for a program. When the program is entered on
function shell.setCompletionFunction(program, complete)
    expect(1, program, "string")
    expect(2, complete, "function")
    tCompletionInfo[program] = {
        fnComplete = complete,
    }
end

--- Get a table containing all completion functions.
function shell.getCompletionInfo()
    return tCompletionInfo
end

--- Returns the path to the currently running program.
function shell.getRunningProgram()
    if #tProgramStack > 0 then
        return tProgramStack[#tProgramStack]
    end
    return nil
end

--- Add an alias for a program.
function shell.setAlias(command, program)
    expect(1, command, "string")
    expect(2, program, "string")
    tAliases[command] = program
end

--- Remove an alias.
function shell.clearAlias(command)
    expect(1, command, "string")
    tAliases[command] = nil
end

--- Get the current aliases for this shell.
function shell.aliases()
    -- Copy aliases
    local tCopy = {}
    for sAlias, sCommand in pairs(tAliases) do
        tCopy[sAlias] = sCommand
    end
    return tCopy
end


if multishell then
    --- Open a new [`multishell`] tab running a command.
    function shell.openTab(...)
        local tWords, err = tokenise(...)
        if err ~= nil then
            printError(err)
            return nil
        end
        local sCommand = tWords[1]
        if sCommand then
            local sPath = shell.resolveProgram(sCommand)
            if sPath == "rom/programs/shell.lua" then
                return multishell.launch(createShellEnv("rom/programs"), sPath, table.unpack(tWords, 2))
            elseif sPath ~= nil then
                return multishell.launch(createShellEnv("rom/programs"), "rom/programs/shell.lua", sCommand, table.unpack(tWords, 2))
            else
                printError("No such program: " .. tostring(sCommand))
            end
        end
    end

    --- Switch to the [`multishell`] tab with the given index.
    function shell.switchTab(id)
        expect(1, id, "number")
        multishell.setFocus(id)
    end
end

local tArgs = { ... }
if #tArgs > 0 then
    -- "shell x y z"
    -- Run the program specified on the commandline
    shell.run(...)

else
    local function show_prompt()
        if _G.lockactive == true then
            minux.lock()
        end
        local colortable = minux.getbashcolor()
        term.setBackgroundColor(colortable[2])
        term.setTextColour(colortable[3])
        local user = minux.displayUser()
        local dir = "/" .. shell.dir()
        local home = homeDirectory()
        if home ~= "" and (shell.dir() == home or string.sub(shell.dir(), 1, #home + 1) == home .. "/") then
            dir = "~" .. string.sub(shell.dir(), #home + 1)
        end
        local symbol = _G.admin == true and "#" or "$"
        write(user .. "@" .. minux.hostname() .. ":" .. dir .. symbol .. " ")
        term.setTextColour(colortable[1])
    end

    -- "shell"
    -- Print the header
    local colortable = minux.getbashcolor()
    term.setBackgroundColor(colortable[2])
    term.setTextColour(colortable[3])
    term.clear()
    term.setCursorPos(1, 1)
    if minux.getconfig("welcome") == "enabled" and term.isColor() then
        minux.debug("Launching welcome screen", "minux")
        local welcomeOk, welcomeErr = pcall(shell.run, "/etc/minux-main/welcome/welcome.sys")
        if not welcomeOk then
            minux.debug("welcome screen failed: " .. tostring(welcomeErr), "minux")
        end
    end
    term.setTextColour(colortable[1])

    -- Run the startup program
    if parentShell == nil then
        shell.run("/etc/minux-main/workspace/startup.lua")
    end

    -- Read commands and execute them
    local tCommandHistory = {}
    while not bExit do
        term.redirect(parentTerm)
        show_prompt()


        local complete
        if settings.get("shell.autocomplete") then complete = shell.complete end

        local ok, result
        local co = coroutine.create(read)
        assert(coroutine.resume(co, nil, tCommandHistory, complete))
        local interrupted = false

        while coroutine.status(co) ~= "dead" do
            local event = table.pack(os.pullEventRaw())
            if event[1] == "file_transfer" then
                -- Abandon the current prompt
                local _, h = term.getSize()
                local _, y = term.getCursorPos()
                if y == h then
                    term.scroll(1)
                    term.setCursorPos(1, y)
                else
                    term.setCursorPos(1, y + 1)
                end
                term.setCursorBlink(false)

                -- Run the import script with the provided files
                local ok, err = require("cc.internal.import")(event[2].getFiles())
                if not ok and err then printError(err) end

                -- And attempt to restore the prompt.
                show_prompt()
                term.setCursorBlink(true)
                event = { "term_resize", n = 1 } -- Nasty hack to force read() to redraw.
            end

            if event[1] == "terminate" then
                -- Ctrl+T at the prompt cancels the current line instead of
                -- killing the shell (which used to reboot the computer).
                interrupted = true
                break
            end

            if result == nil or event[1] == result then
                ok, result = coroutine.resume(co, table.unpack(event, 1, event.n))
                if not ok then error(result, 0) end
            end
        end

        if interrupted then
            term.setCursorBlink(false)
            print("^C")
        elseif type(result) == "string" then
            if result:match("%S") and tCommandHistory[#tCommandHistory] ~= result then
                table.insert(tCommandHistory, result)
            end
            local runOk, runErr = pcall(shell.run, result)
            if not runOk then
                -- Never let a faulty command take the whole shell down.
                term.redirect(parentTerm)
                printError("shell: " .. tostring(runErr))
            end
        end
    end
end
