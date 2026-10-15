-- CraftOS-PC workspace test: boots ReMinux into the default workspace UI,
-- types a command into the first tab and checks it ran without Lua errors.
local originalShellRun = shell.run
local originalShutdown = os.shutdown
local MARKER = "workspace-alive-marker"
local CRASH_PATTERNS = { "attempt to ", "bad argument", "%.lua:%d+:", "%.sh:%d+:", "stack traceback" }

shell.run = function(program, ...)
    if program ~= "/bin/workspace.sh" then
        return originalShellRun(program, ...)
    end
    local log = {}
    local target = term.current()
    local recorder = {}
    for key, value in pairs(target) do recorder[key] = value end
    recorder.write = function(text) log[#log + 1] = tostring(text) return target.write(text) end
    recorder.blit = function(text, fg, bg) log[#log + 1] = text return target.blit(text, fg, bg) end
    recorder.setCursorPos = function(x, y) log[#log + 1] = "\n" return target.setCursorPos(x, y) end
    term.redirect(recorder)
    local crashed, crashErr = false, nil
    parallel.waitForAny(function()
        local ok, err = pcall(originalShellRun, program)
        crashed, crashErr = not ok, err
    end, function()
        sleep(3)
        for char in ("echo " .. MARKER):gmatch(".") do os.queueEvent("char", char) end
        os.queueEvent("key", keys.enter, false)
        sleep(3)
    end)
    term.redirect(target)
    local text = table.concat(log)
    local failures = {}
    if crashed then failures[#failures + 1] = "workspace crashed: " .. tostring(crashErr) end
    if not string.find(text, MARKER, 1, true) then failures[#failures + 1] = "command typed into workspace did not run" end
    for _, pattern in ipairs(CRASH_PATTERNS) do
        local position = string.find(text, pattern)
        if position then
            failures[#failures + 1] = "Lua error on screen: " .. string.sub(text, math.max(1, position - 40), position + 80):gsub("\n", " ")
            break
        end
    end
    for _, failure in ipairs(failures) do print("CRAFTOS_TEST_FAIL: " .. failure) end
    if #failures == 0 then print("CRAFTOS_TEST_PASS") end
    originalShutdown()
end
