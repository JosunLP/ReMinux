-- CraftOS-PC smoke test: boots ReMinux with login disabled, then exercises
-- the shell, the core commands and pipelines through the real ReMinux shell.
local originalShellRun = shell.run
local originalReboot = os.reboot
local originalShutdown = os.shutdown
local testsPassed = false
local DISABLED_LOGIN_SESSION_VALUE = "foo"
local BASH = "/etc/minux-main/workspace/shell.lua"
local COMMAND_TIMEOUT = 5

local function fail(message)
    print("CRAFTOS_TEST_FAIL: " .. tostring(message))
    -- Stop right away instead of waiting on the crash screen until timeout.
    originalShutdown()
    error(tostring(message), 0)
end

local function assertTrue(value, message)
    if value ~= true then
        fail(message)
    end
end

-- Output that indicates an uncaught Lua error rather than a handled failure.
local CRASH_PATTERNS = {
    "attempt to ", "bad argument", "%.sh:%d+:", "%.sys:%d+:", "%.lua:%d+:",
    "minux:%d+:", "apt:%d+:", "stack traceback", "invalid order function",
    "malformed pattern",
}

-- Run one command line through the ReMinux shell parser and capture what it
-- printed. os.run passes the line verbatim so pipes and quotes survive.
local function runCaptured(line)
    local log = {}
    local target = term.current()
    local recorder = {}
    for key, value in pairs(target) do recorder[key] = value end
    recorder.write = function(text) log[#log + 1] = tostring(text) return target.write(text) end
    recorder.blit = function(text, fg, bg) log[#log + 1] = text return target.blit(text, fg, bg) end
    recorder.setCursorPos = function(x, y) log[#log + 1] = "\n" return target.setCursorPos(x, y) end
    term.redirect(recorder)
    local finished, ok, err = false, true, nil
    parallel.waitForAny(function()
        ok, err = pcall(os.run, setmetatable({ shell = shell, multishell = multishell }, { __index = _G }), BASH, line)
        finished = true
    end, function()
        sleep(COMMAND_TIMEOUT)
    end)
    term.redirect(target)
    local text = table.concat(log)
    if not finished then text = text .. "\nTIMEOUT" end
    if not ok then text = text .. "\nPCALL:" .. tostring(err) end
    return text
end

-- Commands that must run without crashing (their exit status is not checked).
local NO_CRASH = {
    "ls", "ls -l /", "ls -a -R /etc/apt", "ls /nonexistent", "ls -d /bin",
    "cat", "cat /nope", "cat /bin", "echo hello world", "echo -n hi",
    "pwd", "whoami", "id", "date", "date %Y", "uname -a", "uptime", "env",
    "basename /a/b.c .c", "dirname /a/b", "realpath .", "seq 3", "seq 1 2 7", "yes 2", "yes",
    "factor 12", "factor x", "expr 1 + 2", "expr 1 / 0", "expr", "printf %d x",
    "stat /startup.lua", "stat /nope", "du -s -h /bin", "df", "mktemp",
    "cal", "cal 2 2024", "cal 13 2024", "which ls", "which nope", "tree /etc/apt",
    "find /etc -name *.db", "find /etc -type d -maxdepth 1", "search apt", "programs",
    "mkdir /dtest", "mkdir -p /dtest/a/b", "touch /dtest/f", "cp /dtest/f /dtest/g", "mv /dtest/g /dtest/h",
    "chmod 700 /dtest/h", "chmod 999 /dtest/h", "chown root /dtest/h", "rm /dtest/h", "rm /dtest", "rm -r /dtest",
    "rm /nope", "rm -f /nope", "cp /nope /x", "mv", "cp",
    "config", "config login", "config bogus", "config login nope",
    "doctor", "doctor --repair", "config", "service", "service list", "service status autorun", "service status nope", "service bogus",
    "apt", "apt -l", "apt help", "apt -v", "apt -i", "apt bogus",
    "man", "man list", "man -k file", "man nope", "neofetch", "colortest", "peripherals", "peripherals left",
    "rs", "rs left", "top", "speak", "curl",
    "bash help", "bash setcolor", "bash setcolor red red red", "useradd", "userdel", "usermod",
    "ls;", "ls &&", "echo 'unterminated", "nosuchcmd", "ls | nosuchcmd", "cat < /nope",
}

-- Command lines whose output must match a Lua pattern.
local EXPECTED_OUTPUT = {
    { "printf 'b\\na\\nc\\n' > /p.txt", nil },
    { "cat /p.txt | sort | head -n 1", "a" },
    { "cat /p.txt | wc -l", "3" },
    { "tac < /p.txt | head -1", "c" },
    { "echo hello | tr a-z A-Z", "HELLO" },
    { "echo a,,c | cut -d , -f 3", "c" },
    { "echo abc | rev", "cba" },
    { "sort -n /p.txt | uniq -c | wc -l", "3" },
    { "head -n 1 /p.txt /p.txt", "==> " },
    { "cat -n /p.txt", "1  b" },
    { "true && echo yes-and", "yes%-and" },
    { "false || echo yes-or", "yes%-or" },
    { "echo trailing;", "trailing" },
    { "ls / | grep -c bin", nil },
    { "lsx", "Did you mean" },
    { "config", "ReMinux configuration" },
    { "cat /bin", "is a directory" },
    { "config clearlogin disabled", "clearlogin = disabled" },
    { "config ui prompt", "ui = prompt" },
    { "config clearlogin", "disabled" },
    { "doctor", "Errors: +0" },
    { "which doctor", "doctor" },
    { "which service", "service" },
    { "man -k pipe", "cat" },
    { "cd ~ && pwd", "/" },
}

local function findCrash(text)
    for _, pattern in ipairs(CRASH_PATTERNS) do
        if string.find(text, pattern) then
            return pattern
        end
    end
    return nil
end

local function runCommandMatrix()
    local failures = {}
    for _, line in ipairs(NO_CRASH) do
        local out = runCaptured(line)
        if string.find(out, "TIMEOUT", 1, true) then
            failures[#failures + 1] = "timed out: " .. line
        elseif findCrash(out) then
            failures[#failures + 1] = "crashed: " .. line .. " => " .. out:gsub("\n", " | "):sub(1, 200)
        end
    end
    for _, case in ipairs(EXPECTED_OUTPUT) do
        local out = runCaptured(case[1])
        if findCrash(out) or string.find(out, "TIMEOUT", 1, true) then
            failures[#failures + 1] = "crashed: " .. case[1] .. " => " .. out:gsub("\n", " | "):sub(1, 200)
        elseif case[2] ~= nil and not string.find(out, case[2]) then
            failures[#failures + 1] = "unexpected output: " .. case[1] .. " (wanted " .. case[2] .. ") => "
                .. out:gsub("\n", " | "):sub(1, 200)
        end
    end
    for _, failure in ipairs(failures) do
        print("CRAFTOS_TEST_FAIL: " .. failure)
    end
    assertTrue(#failures == 0, #failures .. " command check(s) failed")
end

-- The interactive prompt must survive Ctrl+T and failing commands, and must
-- leave cleanly via 'exit'.
local function runInteractiveShell()
    local exited = false
    local ok, err
    parallel.waitForAny(function()
        ok, err = pcall(os.run, setmetatable({ shell = shell, multishell = multishell }, { __index = _G }), BASH)
        exited = true
    end, function()
        -- The queued "terminate" reaches every coroutine, so wait on raw
        -- timer events here to keep this driver alive.
        local function rawSleep(seconds)
            local timer = os.startTimer(seconds)
            repeat
                local _, id = os.pullEventRaw("timer")
            until id == timer
        end
        local function typeLine(text)
            for char in text:gmatch(".") do os.queueEvent("char", char) end
            os.queueEvent("key", keys.enter, false)
            rawSleep(0.3)
        end
        rawSleep(0.5)
        typeLine("nosuchprogram")
        os.queueEvent("terminate")
        rawSleep(0.3)
        typeLine("touch /still-alive.txt")
        typeLine("exit")
        rawSleep(COMMAND_TIMEOUT)
    end)
    assertTrue(exited == true, "interactive shell did not exit via 'exit'")
    assertTrue(ok == true, "interactive shell crashed: " .. tostring(err))
    assertTrue(fs.exists("/still-alive.txt"), "interactive shell did not survive Ctrl+T / unknown command")
end

os.reboot = function()
    if testsPassed == true then
        print("CRAFTOS_TEST_PASS")
        return originalShutdown()
    end
    return originalReboot()
end

shell.run = function(program, ...)
    if testsPassed ~= true and program == BASH then
        local findings = minux.doctor(false)
        local errorCount = 0
        for _, finding in ipairs(findings) do
            if finding.level == "error" then
                errorCount = errorCount + 1
            end
        end

        assertTrue(errorCount == 0, "doctor reported runtime errors")
        assertTrue(_G.validlogin == true, "login did not complete")
        assertTrue(_G.login == DISABLED_LOGIN_SESSION_VALUE, "expected disabled-login sentinel user")
        assertTrue(type(shell.resolveProgram("doctor")) == "string", "doctor command is unavailable")
        assertTrue(type(shell.resolveProgram("whoami")) == "string", "whoami command is unavailable")
        assertTrue(type(shell.resolveProgram("uname")) == "string", "uname command is unavailable")
        assertTrue(originalShellRun("doctor") == true, "doctor command failed")
        assertTrue(originalShellRun("whoami") == true, "whoami command failed")
        assertTrue(originalShellRun("uname") == true, "uname command failed")

        runCommandMatrix()
        runInteractiveShell()

        testsPassed = true
        return true
    end

    return originalShellRun(program, ...)
end
