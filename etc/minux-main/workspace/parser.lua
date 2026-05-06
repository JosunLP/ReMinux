local parser = {}

local function appendToken(tokens, kind, value)
    tokens[#tokens + 1] = {
        kind = kind,
        value = value,
    }
end

function parser.tokenise(line)
    if type(line) ~= "string" then
        return nil, "command line must be a string"
    end

    local tokens = {}
    local current = {}
    local quote = nil
    local index = 1
    local length = #line

    local function flushCurrent()
        if #current == 0 then
            return
        end

        appendToken(tokens, "word", table.concat(current))
        current = {}
    end

    while index <= length do
        local char = string.sub(line, index, index)
        if quote ~= nil then
            if char == quote then
                quote = nil
                index = index + 1
            elseif char == "\\" and quote == '"' and index < length then
                current[#current + 1] = string.sub(line, index + 1, index + 1)
                index = index + 2
            else
                current[#current + 1] = char
                index = index + 1
            end
        else
            local pair = string.sub(line, index, index + 1)
            if pair == "&&" or pair == "||" or pair == ">>" then
                flushCurrent()
                appendToken(tokens, "operator", pair)
                index = index + 2
            elseif char == "|" or char == ">" or char == "<" or char == ";" then
                flushCurrent()
                appendToken(tokens, "operator", char)
                index = index + 1
            elseif char == '"' or char == "'" then
                quote = char
                index = index + 1
            elseif char == "\\" and index < length then
                current[#current + 1] = string.sub(line, index + 1, index + 1)
                index = index + 2
            elseif char == " " or char == "\t" then
                flushCurrent()
                index = index + 1
            else
                current[#current + 1] = char
                index = index + 1
            end
        end
    end

    if quote ~= nil then
        return nil, "unterminated quote"
    end

    flushCurrent()
    return tokens
end

function parser.tokeniseWords(line)
    local tokens, err = parser.tokenise(line)
    if tokens == nil then
        return nil, err
    end

    local words = {}
    for index = 1, #tokens do
        if tokens[index].kind == "word" then
            words[#words + 1] = tokens[index].value
        end
    end

    return words
end

local function peek(state)
    return state.tokens[state.index]
end

local function consumeWord(state, message)
    local token = peek(state)
    if token == nil or token.kind ~= "word" then
        return nil, message
    end

    state.index = state.index + 1
    return token.value
end

local function parseCommand(state)
    local redirects = {}
    local argv = {}
    local consumed = false

    while true do
        local token = peek(state)
        if token == nil then
            break
        end

        if token.kind == "operator" then
            if token.value == "<" or token.value == ">" or token.value == ">>" then
                state.index = state.index + 1
                local target, err = consumeWord(state, "expected file after '" .. token.value .. "'")
                if target == nil then
                    return nil, err
                end

                redirects[#redirects + 1] = {
                    op = token.value,
                    target = target,
                }
                consumed = true
            else
                break
            end
        else
            argv[#argv + 1] = token.value
            state.index = state.index + 1
            consumed = true
        end
    end

    if consumed ~= true or #argv == 0 then
        return nil, "expected command"
    end

    return {
        kind = "command",
        argv = argv,
        redirects = redirects,
    }
end

local function parsePipeline(state)
    local commands = {}
    local command, err = parseCommand(state)
    if command == nil then
        return nil, err
    end

    commands[#commands + 1] = command

    while true do
        local token = peek(state)
        if token == nil or token.kind ~= "operator" or token.value ~= "|" then
            break
        end

        state.index = state.index + 1
        command, err = parseCommand(state)
        if command == nil then
            return nil, err
        end

        commands[#commands + 1] = command
    end

    if #commands == 1 then
        return commands[1]
    end

    return {
        kind = "pipeline",
        commands = commands,
    }
end

function parser.parse(line)
    local tokens, err = parser.tokenise(line)
    if tokens == nil then
        return nil, err
    end

    if #tokens == 0 then
        return {
            kind = "empty",
        }
    end

    local state = {
        tokens = tokens,
        index = 1,
    }

    local steps = {}
    local node
    node, err = parsePipeline(state)
    if node == nil then
        return nil, err
    end

    steps[#steps + 1] = {
        op = nil,
        node = node,
    }

    while state.index <= #tokens do
        local token = peek(state)
        if token.kind ~= "operator" or (token.value ~= "&&" and token.value ~= "||" and token.value ~= ";") then
            return nil, "unexpected token '" .. token.value .. "'"
        end

        state.index = state.index + 1
        node, err = parsePipeline(state)
        if node == nil then
            return nil, err
        end

        steps[#steps + 1] = {
            op = token.value,
            node = node,
        }
    end

    return {
        kind = "sequence",
        steps = steps,
    }
end

return parser
