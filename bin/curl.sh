-- curl: minimal CC: Tweaked compatible HTTP client.
-- Usage: curl [-X METHOD] [-H "Header: Value"]... [-d body] [-o file] <url>
-- Defaults to GET and prints the response body to stdout. Designed for the
-- HTTP API documented at https://tweaked.cc/module/http.html so it works on
-- any CC: Tweaked computer where HTTP is enabled.
local args = { ... }

local function usage()
	print("Usage: curl [-X method] [-H 'Header: Value']... [-d body]")
	print("            [-o file] [-i] [-s] [--timeout secs] <url>")
	print("Performs an HTTP request via the CC: Tweaked http API.")
end

if args[1] == nil or args[1] == "?" or args[1] == "help" or args[1] == "--help" then
	usage()
	return 0
end

if minux == nil or minux.hasHttpSupport == nil or minux.hasHttpSupport() ~= true then
	print("curl: HTTP API is unavailable on this computer.")
	print("Enable 'http_enable' in the CC: Tweaked server config.")
	return 1
end

local method = "GET"
local body
local headers = {}
local outfile
local includeHeaders = false
local silent = false
local timeout
local url

local index = 1
while index <= #args do
	local arg = args[index]
	if arg == "-X" or arg == "--request" then
		method = args[index + 1]
		index = index + 2
	elseif arg == "-H" or arg == "--header" then
		local raw = args[index + 1] or ""
		local key, value = string.match(raw, "^%s*([^:]+)%s*:%s*(.-)%s*$")
		if key == nil then
			print("curl: invalid header '" .. raw .. "'")
			return 1
		end
		headers[key] = value
		index = index + 2
	elseif arg == "-d" or arg == "--data" then
		body = args[index + 1]
		if method == "GET" then method = "POST" end
		index = index + 2
	elseif arg == "-o" or arg == "--output" then
		outfile = args[index + 1]
		index = index + 2
	elseif arg == "-i" or arg == "--include" then
		includeHeaders = true
		index = index + 1
	elseif arg == "-s" or arg == "--silent" then
		silent = true
		index = index + 1
	elseif arg == "--timeout" then
		timeout = tonumber(args[index + 1])
		index = index + 2
	elseif string.sub(arg, 1, 1) == "-" then
		print("curl: unknown option '" .. arg .. "'")
		usage()
		return 1
	else
		url = arg
		index = index + 1
	end
end

if url == nil then
	usage()
	return 1
end

local ok, checkErr = http.checkURL(url)
if ok ~= true then
	print("curl: " .. tostring(checkErr or "URL rejected"))
	return 1
end

local request = {
	url = url,
	method = method,
	headers = headers,
	timeout = timeout,
}

local response, err, failed
if body ~= nil then
	request.body = body
	-- http.post accepts a body via the table form and routes the chosen method.
	response, err, failed = http.post(request)
else
	-- http.get rejects a body in the table form; only use it for body-less calls.
	response, err, failed = http.get(request)
end
if response == nil then
	-- http.get/post with a table arg also returns the failing response when present.
	if failed ~= nil and type(failed.close) == "function" then
		failed.close()
	end
	print("curl: " .. tostring(err or "request failed"))
	return 1
end

local content = response.readAll() or ""
local statusCode, statusMessage = response.getResponseCode and response.getResponseCode() or 200, ""
if response.getResponseHeaders == nil then
	-- Older CC versions: skip header dump silently.
end

if outfile ~= nil then
	local target = shell.resolve(outfile)
	local handle = fs.open(target, "w")
	if handle == nil then
		response.close()
		print("curl: cannot write to " .. target)
		return 1
	end
	handle.write(content)
	handle.close()
	if silent ~= true then
		print("Saved " .. #content .. " bytes to " .. target .. " (HTTP " .. tostring(statusCode) .. ")")
	end
else
	if includeHeaders == true then
		print("HTTP " .. tostring(statusCode))
		if response.getResponseHeaders ~= nil then
			for header, value in pairs(response.getResponseHeaders()) do
				print(tostring(header) .. ": " .. tostring(value))
			end
		end
		print("")
	end
	write(content)
	if string.sub(content, -1) ~= "\n" then write("\n") end
end

response.close()
return 0
