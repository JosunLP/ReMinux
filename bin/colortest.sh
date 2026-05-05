-- colortest: render the 16 ComputerCraft colours as labelled swatches.
local args = { ... }
if args[1] == "?" or args[1] == "help" then
	print("Usage: colortest")
	print("Display every CC colour as a labelled swatch. Useful to verify")
	print("that you are running on an advanced (colour) computer.")
	return 0
end

if term.isColor() == false then
	print("colortest: this is a basic (monochrome) computer.")
	return 0
end

local palette = {
	{ "white",      colors.white      },
	{ "orange",     colors.orange     },
	{ "magenta",    colors.magenta    },
	{ "lightBlue",  colors.lightBlue  },
	{ "yellow",     colors.yellow     },
	{ "lime",       colors.lime       },
	{ "pink",       colors.pink       },
	{ "gray",       colors.gray       },
	{ "lightGray",  colors.lightGray  },
	{ "cyan",       colors.cyan       },
	{ "purple",     colors.purple     },
	{ "blue",       colors.blue       },
	{ "brown",      colors.brown      },
	{ "green",      colors.green      },
	{ "red",        colors.red        },
	{ "black",      colors.black      },
}

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
for _, entry in ipairs(palette) do
	local name, colour = entry[1], entry[2]
	term.setBackgroundColor(colour)
	-- Choose a contrasting text colour for readability.
	if colour == colors.white or colour == colors.yellow
			or colour == colors.lime or colour == colors.lightGray
			or colour == colors.pink or colour == colors.lightBlue then
		term.setTextColor(colors.black)
	else
		term.setTextColor(colors.white)
	end
	write(string.format(" %-10s ", name))
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	print("")
end
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
