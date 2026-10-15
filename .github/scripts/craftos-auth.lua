-- CraftOS-PC auth test: boots ReMinux with local login and checks login,
-- user management, password encryption and the lock screen.
local originalShellRun = shell.run
local originalShutdown = os.shutdown
local BASH = "/etc/minux-main/workspace/shell.lua"
local results = {}
local done = false
local function check(name, cond) results[#results + 1] = (cond and "PASS " or "FAIL ") .. name end
local function flush()
    local f = fs.open("/authtest.txt", "w")
    for _, r in ipairs(results) do f.writeLine(r) end
    f.close()
end
os.reboot = function()
    flush()
    local failed = 0
    for _, line in ipairs(results) do
        print(line)
        if line:sub(1, 4) == "FAIL" then failed = failed + 1 end
    end
    if done and failed == 0 and #results > 0 then
        print("CRAFTOS_TEST_PASS")
    else
        print("CRAFTOS_TEST_FAIL: " .. failed .. " auth check(s) failed")
    end
    return originalShutdown()
end

local function typeText(text)
    for c in text:gmatch(".") do os.queueEvent("char", c) end
    os.queueEvent("key", keys.enter, false)
end

local function runLine(line)
    return os.run(setmetatable({ shell = shell, multishell = multishell }, { __index = _G }), BASH, line)
end

shell.run = function(program, ...)
    if program == "/bin/login.sh" then
        check("wrong password rejected", minux.login("root", "nope") == false and _G.validlogin ~= true)
        check("root login", minux.login("root", "rootpw") == true and _G.admin == true)
        return true
    end
    if not done and program == BASH then
        done = true
        runLine("useradd bob secret")
        check("useradd file", fs.exists("/usr/local/auth/bob.usr"))
        check("checkuser bob", type(minux.checkuser("bob", "secret")) == "table")
        check("session kept after checkuser", _G.login == "root")
        runLine("config encrypt enabled")
        local h = fs.open("/usr/local/auth/root.usr", "r") local stored = h.readLine() h.close()
        check("encrypted on disk", stored ~= "rootpw")
        check("login with encryption", type(minux.checkuser("root", "rootpw")) == "table")
        -- lock: wrong password then right
        local lockResult
        parallel.waitForAll(function() lockResult = minux.lock() end, function()
            sleep(0.2) typeText("bad") sleep(1.5) typeText("rootpw")
        end)
        check("lock unlocks with encryption", lockResult == true and _G.lockactive == false)
        runLine("config encrypt disabled")
        h = fs.open("/usr/local/auth/root.usr", "r") stored = h.readLine() h.close()
        check("decrypted on disk", stored == "rootpw")
        runLine("config login local")
        runLine("config clearlogin enabled")
        runLine("config login local")
        local cfg = minux.readtable("/usr/minux-main/settings.cfg")
        local logins = 0
        for _, l in ipairs(cfg) do if l:match("^login=") then logins = logins + 1 end end
        check("single login line", logins == 1)
        check("clearlogin kept", minux.getconfig("clearlogin") == "enabled")
        check("passwd mismatch", (function()
            local ok
            parallel.waitForAll(function() ok = runLine("passwd bob") end, function()
                sleep(0.2) typeText("aaa") sleep(0.2) typeText("bbb")
            end)
            return minux.checkuser("bob", "secret") ~= false
        end)())
        -- A non-admin must know the current password to change it.
        minux.login("bob", "secret")
        runLine("usermod psw bob hacked wrong-current")
        check("usermod psw needs current password", type(minux.checkuser("bob", "secret")) == "table")
        runLine("usermod psw bob selfchanged secret")
        check("usermod psw self change", type(minux.checkuser("bob", "selfchanged")) == "table" and _G.masterpass == "selfchanged")
        minux.login("root", "rootpw")
        runLine("passwd bob newpw")
        check("passwd change", type(minux.checkuser("bob", "newpw")) == "table")
        runLine("userdel bob -y")
        check("userdel", not fs.exists("/usr/local/auth/bob.usr"))
        flush()
        return true
    end
    return originalShellRun(program, ...)
end
