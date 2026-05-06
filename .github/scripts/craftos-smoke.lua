local originalShellRun = shell.run
local originalReboot = os.reboot
local originalShutdown = os.shutdown
local testsPassed = false
local DISABLED_LOGIN_USER = "foo"

local function fail(message)
    print("CRAFTOS_TEST_FAIL: " .. tostring(message))
    error(tostring(message), 0)
end

local function assertTrue(value, message)
    if value ~= true then
        fail(message)
    end
end

os.reboot = function()
    if testsPassed == true then
        print("CRAFTOS_TEST_PASS")
        return originalShutdown()
    end
    return originalReboot()
end

shell.run = function(program, ...)
    if testsPassed ~= true and program == "/etc/minux-main/workspace/shell.lua" then
        local findings = minux.doctor(false)
        local errorCount = 0
        for _, finding in ipairs(findings) do
            if finding.level == "error" then
                errorCount = errorCount + 1
            end
        end

        assertTrue(errorCount == 0, "doctor reported runtime errors")
        assertTrue(_G.validlogin == true, "login did not complete")
        assertTrue(_G.login == DISABLED_LOGIN_USER, "expected nobody session with login disabled")
        assertTrue(type(shell.resolveProgram("doctor")) == "string", "doctor command is unavailable")
        assertTrue(type(shell.resolveProgram("whoami")) == "string", "whoami command is unavailable")
        assertTrue(originalShellRun("/bin/whoami.sh") == true, "whoami script failed")
        assertTrue(originalShellRun("/bin/uname.sh") == true, "uname script failed")

        testsPassed = true
        return true
    end

    return originalShellRun(program, ...)
end
