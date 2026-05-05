-- ReMinux net-installer
--
-- Bootstraps a ReMinux installation directly from this Git repository,
-- using the raw GitHub content URLs.  The list of files to install is
-- read from /etc/apt/manifest/minux-main.db, which is also the manifest
-- consumed by the APT package manager once ReMinux is installed.  This
-- removes the need for a separate "packaged" build artefact and lets
-- anyone fork the repository and host their own install of ReMinux.
--
-- Original installer (c) Minux team
-- Menu API by ComputerCrafter, double-buffer by Missooni
-- Refactored to use Git in 2026 for the JosunLP/ReMinux fork.

------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local DEFAULT_REPO     = "JosunLP/ReMinux"
local DEFAULT_BRANCH   = "main"
local GITHUB_API_BASE  = "https://api.github.com/repos/"
local LEGACY_APT_OS    = "https://minux.cc/apt/2.0/os/"
local LEGACY_APT_SOFT  = "https://minux.cc/apt/2.0/soft/"
local LEGACY_APT_BETA  = "https://minux.cc/beta/"
local MANIFEST_PATH    = "/etc/apt/list/minux-main.db"
local LEGACY_MANIFEST  = "/etc/apt/manifest/minux-main.db"

------------------------------------------------------------
-- Terminal helpers
------------------------------------------------------------

local ogTerm     = term.current()
local termX, termY = term.getSize()
local bufferWindow = window.create(ogTerm, 1, 1, termX, termY)
local dumpWindow   = window.create(term.current(), 1, 1, 1, 1, false)

local function disableOutput()
        local previousTerm = term.current()
        term.redirect(dumpWindow)
        return previousTerm
end

local function enableOutput(previousTerm)
        term.redirect(previousTerm)
end

local function clearScreen()
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1, 1)
end

local function printError(message)
        if term.isColor() then term.setTextColor(colors.red) end
        print(message)
        if term.isColor() then term.setTextColor(colors.white) end
end

local function printOk(message)
        if term.isColor() then term.setTextColor(colors.lime) end
        print(message)
        if term.isColor() then term.setTextColor(colors.white) end
end

------------------------------------------------------------
-- Menu (selection list)
------------------------------------------------------------

local function showMenu(title, choices, actions)
        local active = true
        local selection = 1
        repeat
                bufferWindow.setVisible(false)
                term.redirect(bufferWindow)
                term.setBackgroundColor(colors.black)
                term.clear()
                local width = term.getSize()
                paintutils.drawLine(1, 1, width, 1, colors.gray)
                term.setCursorPos(1, 1)
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                print(title)
                term.setBackgroundColor(colors.black)
                print("")
                for index = 1, #choices do
                        local prefix = "  "
                        if selection == index then
                                prefix = "> "
                                term.setTextColor(colors.yellow)
                        else
                                term.setTextColor(colors.white)
                        end
                        print(prefix .. choices[index])
                end
                term.setTextColor(colors.white)
                bufferWindow.setVisible(true)

                local _, key = os.pullEvent("key")
                if key == keys.up or key == keys.w then
                        if choices[selection - 1] then selection = selection - 1 end
                elseif key == keys.down or key == keys.s then
                        if choices[selection + 1] then selection = selection + 1 end
                elseif key == keys.enter then
                        if actions[selection] then
                                term.redirect(ogTerm)
                                clearScreen()
                                actions[selection]()
                                active = false
                        end
                end
        until active == false
end

------------------------------------------------------------
-- Installation source descriptors
------------------------------------------------------------

-- An installation source is a strategy for fetching a file from a remote
-- location, given the file's repository-relative path.  Two kinds are
-- supported:
--   * git: serves files from raw.githubusercontent.com/<repo>/<branch>/
--   * apt: serves files from a legacy minux.cc-style APT repository, by
--          downloading and executing a packed .map file.
local Source = {}
Source.__index = Source

function Source.git(repo, branch)
        return setmetatable({
                kind   = "git",
                repo   = repo or DEFAULT_REPO,
                branch = branch or DEFAULT_BRANCH,
                base   = "https://raw.githubusercontent.com/"
                        .. (repo or DEFAULT_REPO) .. "/"
                        .. (branch or DEFAULT_BRANCH) .. "/",
        }, Source)
end

function Source.apt(baseUrl, softUrl)
        return setmetatable({
                kind = "apt",
                base = baseUrl,
                soft = softUrl,
        }, Source)
end

function Source:describe()
        if self.kind == "git" then
                return "Git: " .. self.repo .. "@" .. self.branch
        end
        return "APT: " .. self.base
end

-- Translate a repository-relative path (e.g. "boot/init.sys" or
-- "/boot/init.sys") into an absolute fetch URL.
function Source:urlFor(path)
        local clean = path
        while clean:sub(1, 1) == "/" do clean = clean:sub(2) end
        return self.base .. clean
end

------------------------------------------------------------
-- Filesystem helpers
------------------------------------------------------------

local function ensureParent(filepath)
        local parent = fs.getDir(filepath)
        if parent ~= nil and parent ~= "" and fs.exists(parent) == false then
                fs.makeDir(parent)
        end
end

local function writeFile(filepath, content)
        ensureParent(filepath)
        if fs.exists(filepath) then fs.delete(filepath) end
        local handle = fs.open(filepath, "w")
        handle.write(content)
        handle.close()
end

------------------------------------------------------------
-- HTTP helpers
------------------------------------------------------------

local function httpFetch(url, headers)
        if http == nil then
                return nil, "http API not available"
        end
        if http.checkURL ~= nil and http.checkURL(url) ~= true then
                return nil, "URL rejected by http.checkURL: " .. url
        end
        local response = http.get(url, headers)
        if response == nil then
                return nil, "request failed: " .. url
        end
        local body = response.readAll()
        response.close()
        if body == nil or body == "" then
                return nil, "empty response: " .. url
        end
        return body
end

local function decodeJson(body)
        if textutils == nil then return nil end
        local decoder = textutils.unserialiseJSON or textutils.unserializeJSON
        if decoder == nil then return nil end
        local ok, data = pcall(decoder, body)
        if ok ~= true or type(data) ~= "table" then return nil end
        return data
end

local function isReleaseTag(tag)
        return type(tag) == "string" and tag:match("^v?%d+%.%d+%.%d+[%w%._%-]*$") ~= nil
end

local function fetchLatestReleaseTag(repo)
        local body = httpFetch(GITHUB_API_BASE .. repo .. "/releases/latest", {
                ["User-Agent"] = "ReMinux",
                Accept = "application/vnd.github+json",
        })
        if body == nil then return nil end

        local data = decodeJson(body)
        if data ~= nil and isReleaseTag(data.tag_name) then
                return data.tag_name
        end
        return nil
end

local function resolveRecommendedGitSource(repo, fallbackRef)
        local latestTag = fetchLatestReleaseTag(repo)
        if latestTag ~= nil then
                return Source.git(repo, latestTag)
        end
        return Source.git(repo, fallbackRef)
end

local function downloadFile(source, repoPath, destPath)
        local url = source:urlFor(repoPath)
        local body, err = httpFetch(url)
        if body == nil then return false, err end
        writeFile(destPath, body)
        return true
end

------------------------------------------------------------
-- Manifest (Git-driven install)
------------------------------------------------------------

-- Return the canonical list of files to install, fetched from the
-- manifest in this repository.  Falls back to a built-in minimal list if
-- the network manifest cannot be retrieved.
local function fetchFileList(source)
        local body, err = httpFetch(source:urlFor(MANIFEST_PATH))
        if body == nil then
                -- Try the legacy manifest path as a fallback.
                body, err = httpFetch(source:urlFor(LEGACY_MANIFEST))
        end
        if body == nil then
                return nil, err
        end

        local files = {}
        local inFileList = false
        for line in body:gmatch("([^\r\n]+)") do
                if line == "[filelist]" then
                        inFileList = true
                elseif line:sub(1, 1) == "[" then
                        inFileList = false
                elseif inFileList and line ~= "" then
                        table.insert(files, line)
                end
        end
        if #files == 0 then
                return nil, "manifest contained no [filelist]"
        end
        return files, body
end

------------------------------------------------------------
-- Install strategies
------------------------------------------------------------

local function installFromGit(source, profile)
        print("Fetching file manifest from " .. source:describe())
        local files, manifestBodyOrErr = fetchFileList(source)
        if files == nil then
                printError("Cannot read manifest: " .. tostring(manifestBodyOrErr))
                printError("Aborting installation.")
                return false
        end
        printOk("Manifest retrieved (" .. #files .. " files).")
        print("")

        local total   = #files
        local failed  = {}
        for index, repoPath in ipairs(files) do
                local destPath = repoPath
                if destPath:sub(1, 1) ~= "/" then destPath = "/" .. destPath end
                local pct = math.floor((index - 1) * 100 / total)
                io.write(string.format("[%3d%%] %s ", pct, destPath))
                local ok, fetchErr = downloadFile(source, repoPath, destPath)
                if ok then
                        if term.isColor() then term.setTextColor(colors.lime) end
                        print("OK")
                else
                        if term.isColor() then term.setTextColor(colors.red) end
                        print("FAIL")
                        table.insert(failed, repoPath .. " (" .. tostring(fetchErr) .. ")")
                end
                if term.isColor() then term.setTextColor(colors.white) end
        end

        if #failed > 0 then
                printError("Some files could not be downloaded:")
                for _, entry in ipairs(failed) do print("  - " .. entry) end
                printError("Installation may be incomplete.")
        end

        -- Also fetch /startup.lua so the computer boots ReMinux on next start.
        local startupOk = downloadFile(source, "startup.lua", "/startup.lua")
        if startupOk == false then
                -- Older repos used /startup; try once more.
                downloadFile(source, "startup", "/startup")
        end

        -- Generate the package database and the APT source list.
        ensureParent("/etc/apt/list/installed.db")
        local installed = fs.open("/etc/apt/list/installed.db", "w")
        installed.writeLine("minux-main")
        if profile == "desktop" then
                installed.writeLine("menu")
                installed.writeLine("minex")
                installed.writeLine("auth-client")
        elseif profile == "default" then
                installed.writeLine("menu")
                installed.writeLine("auth-client")
                installed.writeLine("netlib")
        end
        installed.close()

        -- Store the installed manifest locally so boot/version logic and later
        -- APT operations can read the installed version and compare updates.
        writeFile("/etc/apt/list/minux-main.db", manifestBodyOrErr)

        ensureParent("/usr/apt/source.ls")
        local sourceFile = fs.open("/usr/apt/source.ls", "w")
        sourceFile.writeLine(source:urlFor("/etc/apt/"))
        sourceFile.writeLine(LEGACY_APT_SOFT)
        sourceFile.writeLine(LEGACY_APT_OS)
        sourceFile.close()

        return #failed == 0
end

local function installFromApt(source, profile)
        print("Fetching APT manifest from " .. source.base)
        local manifestUrl = source.base .. "manifest/minux-main.db"
        local body, err = httpFetch(manifestUrl)
        if body == nil then
                printError("Cannot reach APT source: " .. tostring(err))
                return false
        end
        ensureParent(LEGACY_MANIFEST)
        writeFile(LEGACY_MANIFEST, body)

        local first = body:match("([^\r\n]+)")
        if first ~= "AIF=true" then
                printError("Verification failed: not a valid APT manifest.")
                return false
        end

        printOk("Manifest verified, downloading package map.")
        local previousTerm = disableOutput()
        local mapOk = shell.run("wget run " .. source.base .. "repository/minux-main.map /")
        enableOutput(previousTerm)
        if mapOk ~= true then
                printError("Failed to download or unpack the package map.")
                return false
        end

        ensureParent("/etc/apt/list/installed.db")
        local installed = fs.open("/etc/apt/list/installed.db", "w")
        installed.writeLine("minux-main")
        if profile == "desktop" then
                installed.writeLine("menu")
                installed.writeLine("minex")
                installed.writeLine("auth-client")
        elseif profile == "default" then
                installed.writeLine("menu")
                installed.writeLine("auth-client")
                installed.writeLine("netlib")
        end
        installed.close()

        ensureParent("/usr/apt/source.ls")
        local sourceFile = fs.open("/usr/apt/source.ls", "w")
        sourceFile.writeLine(source.base)
        if source.soft ~= nil then sourceFile.writeLine(source.soft) end
        sourceFile.close()

        return true
end

local function runInstall(source, profile)
        if source.kind == "git" then
                return installFromGit(source, profile)
        end
        return installFromApt(source, profile)
end

------------------------------------------------------------
-- Main wizard
------------------------------------------------------------

local function chooseAction()
        local choice
        showMenu("ReMinux Installer", {
                "Install ReMinux (recommended)",
                "Reset existing installation",
                "Repair ReMinux (keep settings)",
                "Start an empty CraftOS shell",
                "Start computer normally",
        }, {
                function() choice = "install" end,
                function() choice = "reinstall" end,
                function() choice = "repair" end,
                function() choice = "shell" end,
                function() choice = "start" end,
        })
        return choice
end

local function chooseSource()
        local source
        local profile = "default"
        showMenu("Installation Source", {
                "GitHub Release: latest stable for " .. DEFAULT_REPO .. " (recommended)",
                "GitHub: " .. DEFAULT_REPO .. " (choose branch)",
                "GitHub: custom repository",
                "Custom raw URL (Git, Gitea, GitLab, ...)",
                "Legacy APT: minux.cc stable",
                "Legacy APT: minux.cc beta",
                "Legacy APT: custom server",
        }, {
                function() source = resolveRecommendedGitSource(DEFAULT_REPO, DEFAULT_BRANCH) end,
                function()
                        write("Branch (default 'main'): ")
                        local input = read()
                        if input == nil or input == "" then input = DEFAULT_BRANCH end
                        source = Source.git(DEFAULT_REPO, input)
                end,
                function()
                        write("Repository (owner/name): ")
                        local repo = read()
                        write("Branch (default 'main'): ")
                        local branch = read()
                        if repo == nil or repo == "" then repo = DEFAULT_REPO end
                        if branch == nil or branch == "" then branch = DEFAULT_BRANCH end
                        source = Source.git(repo, branch)
                end,
                function()
                        print("Enter a base URL ending with '/'. The installer")
                        print("will append repository-relative paths to it.")
                        write("URL: ")
                        local url = read()
                        if url == nil or url == "" then
                                printError("No URL given, defaulting to GitHub.")
                                source = Source.git(DEFAULT_REPO, DEFAULT_BRANCH)
                        else
                                if url:sub(-1) ~= "/" then url = url .. "/" end
                                source = setmetatable({
                                        kind = "git", base = url,
                                        repo = url, branch = "custom",
                                }, Source)
                        end
                end,
                function() source = Source.apt(LEGACY_APT_OS, LEGACY_APT_SOFT) end,
                function() source = Source.apt(LEGACY_APT_BETA) end,
                function()
                        write("APT base URL: ")
                        local url = read()
                        if url == nil or url == "" then
                                printError("No URL given, defaulting to legacy stable.")
                                source = Source.apt(LEGACY_APT_OS, LEGACY_APT_SOFT)
                        else
                                if url:sub(-1) ~= "/" then url = url .. "/" end
                                source = Source.apt(url)
                        end
                end,
        })
        if source == nil then return nil end

        showMenu("Installation Profile", {
                "Default (recommended)",
                "Desktop (more apps)",
                "Minimal (core only)",
        }, {
                function() profile = "default" end,
                function() profile = "desktop" end,
                function() profile = "minimal" end,
        })

        return source, profile
end

------------------------------------------------------------
-- Entry point
------------------------------------------------------------

if dofile ~= nil and fs.exists("/rom/modules/main/cc/expect.lua") then
        _G.expect = dofile("/rom/modules/main/cc/expect.lua")
end

clearScreen()
local action = chooseAction()

if action == "shell" then
        return 0
elseif action == "start" then
        if fs.exists("/startup") then
                shell.run("/startup")
        elseif fs.exists("/startup.lua") then
                shell.run("/startup.lua")
        else
                printError("No installation detected, dropping into shell.")
        end
        return 0
elseif action == "repair" then
        if fs.exists("/etc/api/minux") and fs.exists("/etc/api/apt") then
                print("Loading ReMinux API")
                os.loadAPI("/etc/api/minux")
                os.loadAPI("/etc/api/apt")
                print("Forcing APT update")
                apt.update("-f")
                printOk("Repair complete. Reboot or run /boot/init.sys.")
                shell.run("/rom/programs/shell.lua")
        else
                printError("Cannot find ReMinux API; aborting repair.")
                shell.run("/rom/programs/shell.lua")
        end
        return 0
end

-- install / reinstall
if action == "install" and (fs.exists("/startup") or fs.exists("/startup.lua")) then
        print("This computer already has software installed.")
        print("Type 'yes' to overwrite, anything else to abort.")
        write("> ")
        local confirm = read()
        if confirm ~= "yes" and confirm ~= "Yes" and confirm ~= "YES" then
                printError("Aborted.")
                return 0
        end
end

local source, profile = chooseSource()
if source == nil then
        printError("No source selected, aborting.")
        return 0
end

print("")
print("Installing from: " .. source:describe())
print("Profile        : " .. profile)
print("")

local ok = runInstall(source, profile)

clearScreen()
if ok then
        printOk("ReMinux base installed.")
else
        printError("ReMinux installation finished with errors.")
        printError("Inspect the messages above; you can re-run the installer to retry.")
end
print("")
print("Hit Enter to reboot.")
read()
os.reboot()
