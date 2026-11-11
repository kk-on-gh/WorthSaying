local ns = WorthSaying

local CHAT_PREFIXES = {
	SAY = { "s", "say" },
	YELL = { "y", "yell", "sh", "shout" },
	EMOTE = { "e", "em", "emote", "me" },
	PARTY = { "p", "party" },
	RAID = { "ra", "raid", "rsay" },
	RAID_WARNING = { "rw" },
	INSTANCE_CHAT = { "i", "instance" },
	GUILD = { "g", "guild" },
	OFFICER = { "o", "officer" },
	WHISPER = { "w", "whisper", "t", "tell", "send" },
	GROUP = { "gr", "group" },
}

local CONTROL_COMMANDS = {
	wait = "wait", delay = "wait", pause = "pause", stop = "pause",
}

local prefixMap
local emoteMap

local function buildPrefixMap()
	prefixMap = {}
	for chatType, list in pairs(CHAT_PREFIXES) do
		for _, cmd in ipairs(list) do
			prefixMap[cmd] = chatType
		end
		-- localized client slash commands, e.g. SLASH_SAY1
		for i = 1, 12 do
			local cmd = _G["SLASH_" .. chatType .. i]
			if type(cmd) == "string" then
				local bare = cmd:match("^/(.+)$")
				if bare and not prefixMap[bare:lower()] then
					prefixMap[bare:lower()] = chatType
				end
			end
		end
	end
end

local function buildEmoteMap()
	emoteMap = {}
	local maxIndex = tonumber(MAXEMOTEINDEX) or 1000
	for i = 1, maxIndex do
		local token = _G["EMOTE" .. i .. "_TOKEN"]
		if token then
			for j = 1, 10 do
				local cmd = _G["EMOTE" .. i .. "_CMD" .. j]
				if not cmd then
					break
				end
				local bare = cmd:match("^/(.+)$")
				if bare then
					emoteMap[bare:lower()] = token
				end
			end
		end
	end
end

function ns.GetEmoteToken(cmd)
	if not emoteMap then
		buildEmoteMap()
	end
	return emoteMap[cmd:lower()]
end

function ns.GetChatPrefix(cmd)
	if not prefixMap then
		buildPrefixMap()
	end
	return prefixMap[cmd:lower()]
end

-- whisper targets with spaces (Forever surnames) need quotes
local function splitTarget(rest)
	local quoted, after = rest:match('^"([^"]+)"%s*(.-)$')
	if quoted then
		return ns.Trim(quoted), after
	end
	local word, tail = rest:match("^(%S+)%s*(.-)$")
	return word, tail or ""
end

local function utf8Len(s)
	local _, count = s:gsub("[^\128-\191]", "")
	return count
end
ns.Utf8Len = utf8Len

local function parseLine(raw, lineNo)
	local line = ns.Trim(raw)
	if line == "" then
		return nil
	end

	if line:sub(1, 2) == "//" then
		return { lineNo = lineNo, kind = "comment", text = ns.Trim(line:sub(3)) }
	end

	if line:sub(1, 2) == "##" then
		local name = ns.Trim(line:gsub("^#+", ""))
		return { lineNo = lineNo, kind = "section", name = name ~= "" and name or ("Section at line " .. lineNo) }
	end

	if line:sub(1, 1) ~= "/" then
		return { lineNo = lineNo, kind = "chat", text = line }
	end

	local cmd, rest = line:match("^/(%S+)%s*(.-)$")
	if not cmd then
		return { lineNo = lineNo, kind = "error", message = "Empty command" }
	end
	local lower = cmd:lower()

	local control = CONTROL_COMMANDS[lower]
	if control == "wait" then
		local seconds = tonumber(rest)
		if not seconds or seconds < 0 then
			return { lineNo = lineNo, kind = "error", message = "/wait needs a number of seconds, like /wait 5" }
		end
		return { lineNo = lineNo, kind = "wait", seconds = math.min(seconds, 600) }
	elseif control == "pause" then
		return { lineNo = lineNo, kind = "pause", text = rest ~= "" and rest or nil }
	end

	local channelNum = tonumber(lower:match("^(%d)$") or "")
	local chatType = channelNum and "CHANNEL" or ns.GetChatPrefix(lower)
	if chatType then
		local entry = { lineNo = lineNo, chatType = chatType, channelNum = channelNum }
		local text = rest
		if chatType == "WHISPER" then
			local target, tail = splitTarget(rest)
			if not target or target == "" then
				return { lineNo = lineNo, kind = "error", message = "/" .. cmd .. " needs a name, like /w %t Hello" }
			end
			entry.target = target
			text = tail
		end
		if text == "" then
			entry.kind = "channel"
		else
			entry.kind = "chat"
			entry.text = text
			entry.explicit = true
		end
		return entry
	end

	local token = ns.GetEmoteToken(lower)
	if token then
		return { lineNo = lineNo, kind = "emote", token = token, command = "/" .. lower, target = rest ~= "" and rest or nil }
	end

	return { lineNo = lineNo, kind = "error", message = "Unknown command /" .. cmd }
end

-- {cheer} in a chat line becomes an emote sent with it; unknown {words} stay as text
local function extractInlineEmotes(entry)
	if not entry.text:find("{", 1, true) then
		return
	end
	local emotes, unknown = {}, {}
	local text = entry.text:gsub("{(%a+)}", function(word)
		local token = ns.GetEmoteToken(word)
		if not token then
			unknown[#unknown + 1] = "{" .. word .. "}"
			return nil
		end
		emotes[#emotes + 1] = { token = token, command = "/" .. word:lower() }
		return ""
	end)
	if #emotes == 0 and #unknown == 0 then
		return
	end
	entry.text = ns.Trim(text:gsub("%s%s+", " "))
	entry.emotes = #emotes > 0 and emotes or nil
	entry.unknownEmotes = #unknown > 0 and unknown or nil
end

-- bare prefix lines switch the running channel; prefixed text lines don't
function ns.ParseText(text, defaultChannel)
	local result = { lines = {}, sections = {}, sendable = 0, warnings = 0, errors = 0 }
	local running = { chatType = defaultChannel or "SAY" }
	local lineNo = 0
	for raw in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do
		lineNo = lineNo + 1
		local cleaned = raw:gsub("\r", "")
		local entry = parseLine(cleaned, lineNo)
		if entry then
			if entry.kind == "channel" then
				running = { chatType = entry.chatType, channelNum = entry.channelNum, target = entry.target }
			elseif entry.kind == "chat" and not entry.explicit then
				entry.chatType = running.chatType
				entry.channelNum = running.channelNum
				entry.target = running.target
			end
			if entry.kind == "chat" then
				extractInlineEmotes(entry)
				if entry.text == "" and entry.emotes then
					local first = table.remove(entry.emotes, 1)
					entry.kind, entry.token, entry.command, entry.text = "emote", first.token, first.command, nil
					entry.emotes = entry.emotes[1] and entry.emotes or nil
				end
				if entry.unknownEmotes then
					result.warnings = result.warnings + 1
				end
			end
			if entry.kind == "chat" then
				if #entry.text > ns.MAX_CHAT_BYTES then
					entry.warning = "Longer than " .. ns.MAX_CHAT_BYTES .. " characters"
					result.warnings = result.warnings + 1
				end
			end
			if entry.kind == "chat" or entry.kind == "emote" then
				result.sendable = result.sendable + 1
			elseif entry.kind == "error" then
				result.errors = result.errors + 1
			end
			result.lines[#result.lines + 1] = entry
			if entry.kind == "section" then
				result.sections[#result.sections + 1] = { name = entry.name, index = #result.lines }
			end
		end
	end
	return result
end

local parseCache = {}

function ns.GetParsed(speech)
	local cached = parseCache[speech.id]
	if cached and cached.text == speech.text and cached.channel == speech.channel then
		return cached.result
	end
	local result = ns.ParseText(speech.text, speech.channel)
	parseCache[speech.id] = { text = speech.text, channel = speech.channel, result = result }
	return result
end

function ns.InvalidateParse(id)
	if id then
		parseCache[id] = nil
	else
		wipe(parseCache)
	end
end


local usesSurnames = Constants ~= nil and Constants.CharacterNameSeparatorConsts ~= nil

-- full adds a Forever surname; NPC names are always whole
local function unitName(unit, full)
	if not UnitExists(unit) then
		return nil
	end
	local ok, name, surname = pcall(UnitName, unit)
	if not ok or not name or (issecretvalue and (issecretvalue(name) or issecretvalue(surname))) then
		return nil
	end
	if full and usesSurnames and surname and surname ~= "" and UnitIsPlayer(unit) then
		return name .. " " .. surname
	end
	return name
end

local function unitShortName(unit)
	return unitName(unit, false)
end

local function groupLeaderName()
	if not IsInGroup() then
		return unitShortName("player")
	end
	local prefix, count = "party", GetNumSubgroupMembers()
	if IsInRaid() then
		prefix, count = "raid", GetNumGroupMembers()
	end
	if UnitIsGroupLeader("player") then
		return unitShortName("player")
	end
	for i = 1, count do
		local unit = prefix .. i
		if UnitIsGroupLeader(unit) then
			return unitShortName(unit)
		end
	end
end

ns.TOKENS = {
	{ key = "t", preview = "<target>", description = "Your target's first name (an NPC's whole name)",
		resolve = function() return unitName("target", false) or ns.GetSettings().playback.targetFallback end },
	{ key = "tt", preview = "<target full name>", description = "Your target's full name, with surname",
		resolve = function() return unitName("target", true) or ns.GetSettings().playback.targetFallback end },
	{ key = "f", preview = "<focus>", description = "Your focus's first name",
		resolve = function() return unitName("focus", false) or ns.GetSettings().playback.targetFallback end },
	{ key = "ff", preview = "<focus full name>", description = "Your focus's full name",
		resolve = function() return unitName("focus", true) or ns.GetSettings().playback.targetFallback end },
	{ key = "p", preview = "<your name>", description = "Your first name",
		resolve = function() return unitName("player", false) end },
	{ key = "pp", preview = "<your full name>", description = "Your full name",
		resolve = function() return unitName("player", true) end },
	{ key = "z", preview = "<zone>", description = "Current zone",
		resolve = function() return GetRealZoneText and GetRealZoneText() or GetZoneText() end },
	{ key = "sz", preview = "<subzone>", description = "Current subzone (or zone, if none)",
		resolve = function()
			local sub = GetSubZoneText()
			if sub and sub ~= "" then
				return sub
			end
			return GetZoneText()
		end },
	{ key = "c", preview = "<your class>", description = "Your class",
		resolve = function() return (UnitClass("player")) end },
	{ key = "r", preview = "<your race>", description = "Your race",
		resolve = function() return (UnitRace("player")) end },
	{ key = "lvl", preview = "<your level>", description = "Your level",
		resolve = function() return tostring(UnitLevel("player")) end },
	{ key = "g", preview = "<guild>", description = "Your guild's name",
		resolve = function() return GetGuildInfo("player") end },
	{ key = "l", preview = "<group leader>", description = "Your group leader's name (or yours, solo)",
		resolve = groupLeaderName },
	{ key = "time", preview = "<time>", description = "Server time, like 18:30",
		resolve = function()
			local h, m = GetGameTime()
			return string.format("%02d:%02d", h, m)
		end },
}

local tokenByKey = {}
for _, token in ipairs(ns.TOKENS) do
	tokenByKey[token.key] = token
end

-- unknown %words are left alone so "100%off" style typos stay visible
function ns.ExpandTokens(text)
	if not text or not text:find("%", 1, true) then
		return text
	end
	text = text:gsub("%%%%", "\001")
	text = text:gsub("%%(%a+)", function(word)
		local token = tokenByKey[word:lower()]
		if not token then
			return nil
		end
		local ok, value = pcall(token.resolve)
		if ok and value and value ~= "" then
			return (tostring(value):gsub("%%", "%%%%"))
		end
		return ""
	end)
	return (text:gsub("\001", "%%"))
end

-- like ExpandTokens, but with readable placeholders such as <target>
function ns.PreviewTokens(text)
	if not text or not text:find("%", 1, true) then
		return text
	end
	text = text:gsub("%%%%", "\001")
	text = text:gsub("%%(%a+)", function(word)
		local token = tokenByKey[word:lower()]
		return token and token.preview or nil
	end)
	return (text:gsub("\001", "%%"))
end

-- never cuts inside a multibyte character
local function safeCut(text, maxBytes)
	local cut = maxBytes
	while cut > 1 do
		local nextByte = text:byte(cut + 1)
		if not nextByte or nextByte < 128 or nextByte >= 192 then
			break
		end
		cut = cut - 1
	end
	return cut
end

function ns.SplitMessage(text, maxBytes)
	maxBytes = maxBytes or ns.MAX_CHAT_BYTES
	local pieces = {}
	while #text > maxBytes do
		local window = text:sub(1, maxBytes)
		local cut
		for i = #window - 1, math.floor(maxBytes / 3), -1 do
			local ch = window:sub(i, i)
			if (ch == "." or ch == "!" or ch == "?") and window:sub(i + 1, i + 1) == " " then
				cut = i
				break
			end
		end
		if not cut then
			for i = #window, math.floor(maxBytes / 3), -1 do
				if window:sub(i, i) == " " then
					cut = i - 1
					break
				end
			end
		end
		cut = cut or safeCut(text, maxBytes)
		pieces[#pieces + 1] = ns.Trim(text:sub(1, cut))
		text = ns.Trim(text:sub(cut + 1))
	end
	if text ~= "" then
		pieces[#pieces + 1] = text
	end
	return pieces
end
