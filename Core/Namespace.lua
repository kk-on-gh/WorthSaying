local ADDON_NAME = ...

WorthSaying = WorthSaying or {}
local ns = WorthSaying
ns.name = ADDON_NAME

-- Bindings.xml category; the keybind panel reads this global when it builds
BINDING_HEADER_WORTHSAYING = "Worth Saying"
_G["BINDING_NAME_WS_NEXT"] = "Send next line"
_G["BINDING_NAME_WS_BACK"] = "Step back one line"
_G["BINDING_NAME_WS_PLAYPAUSE"] = "Start or pause auto-play"
_G["BINDING_NAME_WS_PRESENTER"] = "Show or hide the presenter"
_G["BINDING_NAME_WS_WINDOW"] = "Show or hide the main window"

ns.CURRENT_SCHEMA_VERSION = 1

-- SendChatMessage hard cap, in bytes
ns.MAX_CHAT_BYTES = 255

ns.Defaults = {
	schemaVersion = ns.CURRENT_SCHEMA_VERSION,
	settings = {
		windowAlpha = 1.0,
		uiScale = 1.0,
		columnWidths = {},
		columnVisibility = {},
		columnOrder = {},
		windowPositions = {},
		timeFormat = "24h",
		dateFormat = "ymd",
		showPatchNotesOnUpdate = true,
		minimapIcon = { hide = false, angle = 200 },
		listSplit = 0.46,
		playback = {
			delay = 3,
			scaleWithLength = false,
			secondsPer50Chars = 1,
			splitLongLines = true,
			emotesFollowLine = true,
			targetFallback = "friend",
			roleFallbacks = { tank = "tank", healer = "healer", dps = "DPS" },
			macroResumeSeconds = 60,
			waitSound = true,
			waitSoundChoice = "invite",
			pauseSound = true,
			pauseSoundChoice = "eventchime",
			finishSound = false,
			finishSoundChoice = "readycheck",
		},
		presenter = {
			scale = 1.0,
			alpha = 1.0,
			showNext = true,
			closeOnFinish = false,
			locked = false,
			rehearse = false,
			rehearseEmotes = false,
			minimized = false,
		},
		triggers = {
			enabled = true,
			instance = true,
			zone = true,
			subzone = true,
			group = false,
			pick = "random",
			autoPlay = false,
			skipInCombat = true,
			sound = true,
			closeOnLeave = true,
		},
	},
	speeches = {},
	nextId = 1,
	knownInstances = {},
}

-- restricted: needs a real key press or click outside instances
ns.CHAT_TYPES = {
	SAY = { label = "Say", restricted = true },
	YELL = { label = "Yell", restricted = true },
	EMOTE = { label = "Emote" },
	PARTY = { label = "Party" },
	RAID = { label = "Raid" },
	RAID_WARNING = { label = "Raid Warning" },
	INSTANCE_CHAT = { label = "Instance" },
	GUILD = { label = "Guild" },
	OFFICER = { label = "Officer" },
	WHISPER = { label = "Whisper" },
	CHANNEL = { label = "Channel", restricted = true },
	GROUP = { label = "Group" },
}

function ns.RehearseTip()
	if ns.GetSettings().presenter.rehearseEmotes then
		return "Print lines only to your own chat window instead of sending them. Action emotes like /cheer are still performed (Options > Playback)."
	end
	return "Print lines only to your own chat window instead of sending them. Emotes aren't performed."
end

ns.CHANNEL_ORDER = {
	"SAY", "YELL", "EMOTE", "GROUP", "PARTY", "RAID", "RAID_WARNING", "INSTANCE_CHAT", "GUILD", "OFFICER",
}

ns.DEFAULT_CHAT_COLORS = {
	SAY = { 1, 1, 1 },
	YELL = { 1, 0.25, 0.25 },
	EMOTE = { 1, 0.5, 0.25 },
	PARTY = { 0.67, 0.67, 1 },
	RAID = { 1, 0.5, 0 },
	RAID_WARNING = { 1, 0.28, 0 },
	INSTANCE_CHAT = { 1, 0.5, 0 },
	GUILD = { 0.25, 1, 0.25 },
	OFFICER = { 0.25, 0.75, 0.25 },
	WHISPER = { 1, 0.5, 1 },
	CHANNEL = { 1, 0.75, 0.75 },
	ACTION = { 0.4, 0.8, 1 },
	CONTROL = { 0.6, 0.6, 0.6 },
	SECTION = { 1, 0.82, 0 },
	ERROR = { 1, 0.3, 0.3 },
}

function ns.ChatColor(chatType)
	if chatType == "GROUP" then
		chatType = "PARTY"
	end
	local info = ChatTypeInfo and ChatTypeInfo[chatType]
	if info and info.r then
		return info.r, info.g, info.b
	end
	local c = ns.DEFAULT_CHAT_COLORS[chatType] or ns.DEFAULT_CHAT_COLORS.SAY
	return c[1], c[2], c[3]
end

function ns.ChatLabel(chatType, channelNum)
	if chatType == "CHANNEL" and channelNum then
		return "Channel " .. channelNum
	end
	local def = ns.CHAT_TYPES[chatType]
	return def and def.label or tostring(chatType)
end

ns.SPEECH_KINDS = {
	{ value = "speech", text = "Speech" },
	{ value = "quip", text = "Quip" },
}

function ns.KindLabel(kind)
	return kind == "quip" and "Quip" or "Speech"
end

ns.TRIGGER_TYPES = {
	{ value = "instance", text = "Entering an instance" },
	{ value = "zone", text = "Entering a zone" },
	{ value = "subzone", text = "Entering a subzone" },
	{ value = "group", text = "Joining a group" },
}

function ns.TriggerTypeLabel(triggerType)
	if triggerType == "instance" then
		return "Instance"
	elseif triggerType == "zone" then
		return "Zone"
	elseif triggerType == "subzone" then
		return "Subzone"
	elseif triggerType == "group" then
		return "Group"
	end
	return tostring(triggerType)
end

function ns.GetAddonVersion()
	local version = (GetAddOnMetadata and GetAddOnMetadata(ns.name, "Version"))
		or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ns.name, "Version"))
	return version or (ns.CHANGELOG and ns.CHANGELOG[1] and ns.CHANGELOG[1].version)
end

-- open chat tabs except the combat log, in tab order
function ns.GetChatTabs()
	local tabs = {}
	if not GetChatWindowInfo then
		return tabs
	end
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local name, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(i)
		local frame = _G["ChatFrame" .. i]
		if frame and name and name ~= "" and (shown or docked) and frame ~= _G.COMBATLOG then
			tabs[#tabs + 1] = { name = name, frame = frame }
		end
	end
	return tabs
end

-- a saved tab that's been closed or renamed falls back to the main window
function ns.GetOutputFrame()
	local ok, settings = pcall(ns.GetSettings)
	local name = ok and settings and settings.outputTab
	if name then
		for _, tab in ipairs(ns.GetChatTabs()) do
			if tab.name == name then
				return tab.frame
			end
		end
	end
	return DEFAULT_CHAT_FRAME
end

function ns.Print(msg)
	ns.GetOutputFrame():AddMessage("|cffd9a54aWorth Saying|r: " .. tostring(msg))
end

function ns.Trim(text)
	return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

function ns.ParseTags(text)
	local tags, seen = {}, {}
	for raw in tostring(text or ""):gmatch("[^,]+") do
		local tag = ns.Trim(raw)
		if tag ~= "" and not seen[tag:lower()] then
			seen[tag:lower()] = true
			tags[#tags + 1] = tag
		end
	end
	return tags
end

function ns.ToHex(r, g, b)
	return string.format("ff%02x%02x%02x", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
end

function ns.ColorText(text, r, g, b)
	return "|c" .. ns.ToHex(r, g, b) .. text .. "|r"
end

function ns.ApplyPanelBackdrop(frame, alpha)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0.16, 0.11, 0.05, alpha or 0.7)
	frame:SetBackdropBorderColor(1, 0.82, 0, 0.4)
end

function ns.FormatDate(ts)
	local dateFormat = ns.GetSettings().dateFormat
	if dateFormat == "mdy" then
		return date("%m-%d-%Y", ts)
	elseif dateFormat == "dmy" then
		return date("%d-%m-%Y", ts)
	end
	return date("%Y-%m-%d", ts)
end

function ns.FormatTime(ts)
	local settings = ns.GetSettings()
	local timePart = settings.timeFormat == "12h" and date("%I:%M %p", ts) or date("%H:%M", ts)
	return ns.FormatDate(ts) .. " " .. timePart
end

function ns.RelativeDate(ts)
	if not ts then
		return "never"
	end
	local seconds = math.max(0, time() - ts)
	local function unit(n, word)
		return n .. " " .. word .. (n == 1 and "" or "s") .. " ago"
	end
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return unit(math.floor(seconds / 60), "minute")
	elseif seconds < 86400 then
		return unit(math.floor(seconds / 3600), "hour")
	elseif seconds < 7 * 86400 then
		return unit(math.floor(seconds / 86400), "day")
	elseif seconds < 30 * 86400 then
		return unit(math.floor(seconds / (7 * 86400)), "week")
	elseif seconds < 365 * 86400 then
		return unit(math.floor(seconds / (30 * 86400)), "month")
	end
	return unit(math.floor(seconds / (365 * 86400)), "year")
end

-- kit: a SOUNDKIT key (with a numeric fallback); file: a FileDataID
ns.SOUND_OPTIONS = {
	{ value = "invite", text = "Player Invite", kit = "IG_PLAYER_INVITE", fallback = 880 },
	{ value = "readycheck", text = "Ready Check", kit = "READY_CHECK", fallback = 8960 },
	{ value = "eventchime", text = "Event Chime", file = 6684192 },
	{ value = "completed", text = "Completed", file = 4956058 },
	{ value = "roommoved", text = "Room Moved", file = 6838444 },
	{ value = "invalidplacement", text = "Invalid Placement", file = 7001652 },
	{ value = "friendjoin", text = "Friend Join", file = 567518 },
}

function ns.PlaySoundChoice(value)
	for _, option in ipairs(ns.SOUND_OPTIONS) do
		if option.value == value then
			if option.file then
				PlaySoundFile(option.file, "Master")
			else
				ns.PlayUISound(option.kit, option.fallback)
			end
			return
		end
	end
end

function ns.PlayUISound(kit, fallback)
	local id = (SOUNDKIT and SOUNDKIT[kit]) or fallback
	if id then
		PlaySound(id, "Master")
	end
end

function ns.InInstance()
	local inInstance = IsInInstance()
	return inInstance and true or false
end
