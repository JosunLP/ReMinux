-- factor: print the prime factorisation of an integer.
local args = { ... }
if args[1] == nil or args[1] == "?" or args[1] == "help" then
	print("Usage: factor <number> [number...]")
	print("Print the prime factors of each given non-negative integer.")
	return 0
end

local function factorize(value)
	local factors = {}
	local n = value
	if n < 2 then return factors end
	local divisor = 2
	while divisor * divisor <= n do
		while n % divisor == 0 do
			factors[#factors + 1] = divisor
			n = n / divisor
		end
		divisor = divisor + 1
	end
	if n > 1 then factors[#factors + 1] = n end
	return factors
end

for index = 1, #args do
	local raw = args[index]
	local value = tonumber(raw)
	if value == nil or value ~= math.floor(value) or value < 0 then
		print(raw .. ": not a non-negative integer")
	else
		local factors = factorize(value)
		if #factors == 0 then
			print(value .. ":")
		else
			print(value .. ": " .. table.concat(factors, " "))
		end
	end
end
