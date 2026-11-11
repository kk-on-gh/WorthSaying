local ns = WorthSaying

local GOLD = "|cffffd100"
local CODE = "|cff9fd0ff"
local R = "|r"

local function code(text)
	return CODE .. text .. R
end

local function tokenLines()
	local lines = {}
	for _, token in ipairs(ns.TOKENS) do
		lines[#lines + 1] = code("%" .. token.key) .. "  " .. token.description
	end
	lines[#lines + 1] = code("%%") .. "  a literal % sign"
	return lines
end

local SECTIONS = {
	{ heading = "The basics", lines = {
		"Write one chat message per line. Blank lines are ignored. Everything saves as you type.",
		"Open a speech in the presenter (double-click it, or press Present), then press Send for each line, or Play to send them on a timer.",
		"Lines with no /prefix go to the speech's default channel (Say, unless you change it in the editor).",
	}},
	{ heading = "Channels", lines = {
		code("/s") .. " Say,  " .. code("/y") .. " Yell,  " .. code("/e") .. " Emote text,  " .. code("/p") .. " Party,  " .. code("/ra") .. " Raid,  " .. code("/rw") .. " Raid Warning",
		code("/i") .. " Instance,  " .. code("/g") .. " Guild,  " .. code("/o") .. " Officer,  " .. code("/1") .. " to " .. code("/9") .. " numbered channels",
		code("/gr") .. " Group: party, raid or instance chat, whichever you're in when the line is sent.",
		code("/w Name message") .. " whispers someone. Use " .. code('/w "First Last" message') .. " for names with a space, and " .. code("/w %t message") .. " for your target.",
		"A prefix with text after it applies to that line only: " .. code("/p Stay close!"),
		"A prefix on a line by itself switches every line after it: " .. code("/p") .. " then plain lines all go to party, until another bare prefix.",
	}},
	{ heading = "Emotes", lines = {
		"Any emote command works on its own line: " .. code("/bow") .. ", " .. code("/wave") .. ", " .. code("/cheer") .. ", " .. code("/laugh") .. " and the rest.",
		"Add a name to aim it: " .. code("/bow %t") .. ". For custom emote text, use " .. code("/e") .. ": " .. code("/e tips their hat."),
		"Put an emote in curly braces to do it at the same moment as a line: " .. code("{cheer} Everyone ready? Doesn't matter, I'm going!") .. " says the line and cheers. Several work, anywhere in the line. A brace word that isn't an emote stays in the text, and Preview points it out.",
	}},
	{ heading = "Control lines (never sent)", lines = {
		code("/wait 5") .. "  during auto-play, wait 5 seconds here instead of the usual delay after the line above it. Decimals and 0 work: " .. code("/wait 0.5") .. ", " .. code("/wait 0") .. ".",
		code("/pause") .. "  stop auto-play here until you press Play again. Handy for \"wait for everyone to catch up\". Add a note and it shows in the presenter and your chat window when playback stops there: " .. code("/pause wait at the bridge"),
		code("## Section name") .. "  a heading. The presenter's dropdown jumps between sections.",
		code("// note") .. "  a note to yourself.",
		"Pressing Send by hand skips past waits and pauses to the next real line.",
	}},
	{ heading = "Tokens", lines = tokenLines() },
	{ heading = "Auto-play and key presses", lines = {
		"Blizzard only lets addons send Say, Yell and numbered-channel messages from a real key press or click when you're outside an instance.",
		"So outdoors, auto-play sends party, raid, guild, emote and whisper lines on its own, then stops on a Say or Yell line, highlights Send and waits for you. Press Send or your Next key, and it carries on.",
		"Inside dungeons and raids, everything can play on its own.",
		"During boss fights and similar, the game can block addon chat entirely. Auto-play waits until it lifts.",
		"Set a Next key in Options, or put " .. code("/ws next") .. " in a macro on your action bar.",
	}},
	{ heading = "Quips", lines = {
		"A quip is a speech where each Send picks one random line. Good for greetings, pull lines and jokes.",
		"Put " .. code("/ws quip Name") .. " in a macro to fire one from your action bar without opening anything.",
	}},
	{ heading = "Triggers", lines = {
		"In the editor, Add Trigger makes a speech pop up the presenter when you enter an instance, zone or subzone, or join a group.",
		"Use the current place, or type the name exactly as the game shows it. Several speeches can share a place: one is picked (randomly by default) and the rest are in the presenter's dropdown.",
		"Triggered speeches don't send anything until you press Send or Play, unless you turn on \"Start auto-play right away\" in Options.",
	}},
	{ heading = "Long lines", lines = {
		"Chat messages max out at 255 characters. The preview flags longer lines, and they're split at a sentence break when sent (or cut off, if you turn splitting off in Options).",
	}},
	{ heading = "Slash commands", lines = {
		code("/ws") .. " window,  " .. code("/ws present Name") .. ",  " .. code("/ws play Name") .. ",  " .. code("/ws next") .. ",  " .. code("/ws back") .. ",  " .. code("/ws skip") .. ",  " .. code("/ws pause") .. ",  " .. code("/ws stop") .. ",  " .. code("/ws quip Name") .. ",  " .. code("/ws rehearse"),
	}},
}

function ns.BuildGuidePanel(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", 16, -8)
	scroll:SetPoint("BOTTOMRIGHT", -34, 4)
	local child = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(child)
	child:SetSize(600, 1)

	local pool = {}
	local function getString(i, template)
		local fs = pool[i]
		if not fs then
			fs = child:CreateFontString(nil, "ARTWORK", template)
			fs:SetJustifyH("LEFT")
			fs:SetWordWrap(true)
			pool[i] = fs
		end
		fs:SetFontObject(template)
		fs:ClearAllPoints()
		fs:Show()
		return fs
	end

	local function layout(width)
		child:SetWidth(width)
		local y, n = -4, 0
		for _, section in ipairs(SECTIONS) do
			n = n + 1
			local heading = getString(n, "GameFontNormal")
			heading:SetPoint("TOPLEFT", 0, y)
			heading:SetWidth(width)
			heading:SetText(GOLD .. section.heading .. R)
			y = y - 20
			for _, line in ipairs(section.lines) do
				n = n + 1
				local fs = getString(n, "GameFontHighlight")
				fs:SetPoint("TOPLEFT", 12, y)
				fs:SetWidth(width - 24)
				fs:SetText(line)
				y = y - fs:GetStringHeight() - 6
			end
			y = y - 10
		end
		child:SetHeight(-y + 10)
	end

	local lastWidth
	scroll:SetScript("OnSizeChanged", function(_, width)
		width = math.floor(width)
		if width > 100 and width ~= lastWidth then
			lastWidth = width
			layout(width)
		end
	end)
end
