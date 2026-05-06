local executor = {}

local function copyList(values)
    local result = {}
    if type(values) ~= "table" then
        return result
    end

    for index = 1, #values do
        result[index] = values[index]
    end

    return result
end

local function newInputContext(lines)
    local copied = copyList(lines)
    local cursor = 1
    return {
        inputLines = copied,
        readLines = function()
            return copyList(copied)
        end,
        read = function()
            local value = copied[cursor]
            cursor = cursor + 1
            return value
        end,
    }
end

local function mergeContexts(base)
    local context = {}
    if type(base) == "table" then
        for key, value in pairs(base) do
            context[key] = value
        end
    end

    return context
end

local function readFileLines(path)
    local handle = fs.open(path, "r")
    if handle == nil then
        return nil, "cannot open input: " .. path
    end

    local lines = {}
    local line = handle.readLine()
    while line ~= nil do
        lines[#lines + 1] = line
        line = handle.readLine()
    end

    handle.close()
    return lines
end

local function ensurePermission(runtime, path, operation)
    if runtime ~= nil and type(runtime.requirePermission) == "function" then
        return runtime.requirePermission(path, operation)
    end

    return false, "permission checker unavailable for " .. tostring(operation) .. ": " .. tostring(path)
end

local function attachInput(context, lines)
    local inputContext = newInputContext(lines)
    context.inputLines = inputContext.inputLines
    context.readLines = inputContext.readLines
    context.read = inputContext.read
    return context
end

local function attachBufferedOutput(context, lines)
    local rawBuffer = ""

    local function flushRawBuffer()
        if rawBuffer ~= "" then
            lines[#lines + 1] = rawBuffer
            rawBuffer = ""
        end
    end

    local function writeRaw(text)
        text = tostring(text or "")
        if text == "" then
            return
        end

        rawBuffer = rawBuffer .. text
        while true do
            local newline = string.find(rawBuffer, "\n", 1, true)
            if newline == nil then
                break
            end

            lines[#lines + 1] = string.sub(rawBuffer, 1, newline - 1)
            rawBuffer = string.sub(rawBuffer, newline + 1)
        end
    end

    context.outputLines = lines
    context.writeLine = function(line)
        flushRawBuffer()
        lines[#lines + 1] = tostring(line)
    end
    context.write = writeRaw
    context.flush = flushRawBuffer
    return context
end

local function attachFileOutput(context, runtime, path, append)
    local operation = fs.exists(path) and "write" or "create"
    local permitted, permissionErr = ensurePermission(runtime, path, operation)
    if permitted ~= true then
        return nil, permissionErr
    end

    local handle = fs.open(path, append == true and "a" or "w")
    if handle == nil then
        return nil, "cannot open output: " .. path
    end

    context.writeLine = function(line)
        handle.writeLine(tostring(line))
    end
    context.write = function(text)
        handle.write(tostring(text or ""))
    end
    context.flush = function()
        return true
    end
    context.close = function()
        handle.close()
    end
    return context
end

local function applyRedirects(command, runtime, baseContext, outputSpec)
    local context = mergeContexts(baseContext)
    local inputPath = nil
    local outputRedirect = nil

    for index = 1, #(command.redirects or {}) do
        local redirect = command.redirects[index]
        local targetPath = redirect.target
        if runtime ~= nil and type(runtime.resolvePath) == "function" then
            targetPath = runtime.resolvePath(targetPath)
        end

        if redirect.op == "<" then
            inputPath = targetPath
        elseif redirect.op == ">" or redirect.op == ">>" then
            outputRedirect = {
                op = redirect.op,
                target = targetPath,
            }
        end
    end

    if inputPath ~= nil then
        local permitted, permissionErr = ensurePermission(runtime, inputPath, "read")
        if permitted ~= true then
            return nil, permissionErr
        end

        local lines, err = readFileLines(inputPath)
        if lines == nil then
            return nil, err
        end

        attachInput(context, lines)
    end

    if outputRedirect ~= nil then
        return attachFileOutput(context, runtime, outputRedirect.target, outputRedirect.op == ">>")
    end

    if outputSpec ~= nil and outputSpec.kind == "pipe" then
        attachBufferedOutput(context, outputSpec.lines)
    end

    return context
end

local function finishContext(context)
    if type(context) ~= "table" then
        return
    end

    if type(context.flush) == "function" then
        context.flush()
    end
    if type(context.close) == "function" then
        context.close()
    end
end

local function executeCommand(command, runtime, baseContext, outputSpec)
    local context, err = applyRedirects(command, runtime, baseContext, outputSpec)
    if context == nil then
        return false, err
    end

    local ok, reason = runtime.executeCommand(command, context)
    finishContext(context)
    if ok ~= true then
        return false, reason
    end

    return true, context.outputLines
end

local function executeNode(node, runtime, baseContext)
    if node.kind == "command" then
        return executeCommand(node, runtime, baseContext, nil)
    end
    if node.kind ~= "pipeline" then
        return false, "unsupported node kind: " .. tostring(node.kind)
    end

    local upstreamContext = baseContext
    local lastStatus = true
    for index = 1, #node.commands do
        local outputSpec = nil
        local pipeLines = nil
        if index < #node.commands then
            pipeLines = {}
            outputSpec = {
                kind = "pipe",
                lines = pipeLines,
            }
        end

        local ok, err = executeCommand(node.commands[index], runtime, upstreamContext, outputSpec)
        if ok ~= true then
            return false, err
        end

        lastStatus = ok
        if pipeLines ~= nil then
            upstreamContext = newInputContext(pipeLines)
        end
    end

    return lastStatus
end

function executor.executeAst(ast, runtime, baseContext)
    if ast == nil or ast.kind == "empty" then
        return false
    end

    local lastStatus = true
    local lastError = nil
    for index = 1, #ast.steps do
        local step = ast.steps[index]
        local shouldRun = index == 1
        if index > 1 then
            if step.op == ";" then
                shouldRun = true
            elseif step.op == "&&" then
                shouldRun = lastStatus == true
            elseif step.op == "||" then
                shouldRun = lastStatus ~= true
            end
        end

        if shouldRun then
            lastStatus, lastError = executeNode(step.node, runtime, baseContext)
        end
    end

    return lastStatus == true, lastError
end

return executor
