local ns = WorthSaying

-- index always points at the next entry to process
local state = {
	speech = nil,
	parsed = nil,
	index = 1,
	playing = false,
	waiting = nil,
	finished = false,
	counted = false,
	lastSent = nil,
	lastQuipIndex = nil,
	candidates = nil,
	source = nil,
	nextAt = nil,
}

local timer
local learnedRestricted = {}
local lastAttempt

function ns.GetPlaybackState()
	return state
end

local function refresh()
	if ns.RefreshPresenter then
		ns.RefreshPresenter()
	end
end

local function cancelTimer()
	if timer then
		timer:Cancel()
		timer = nil
	end
	state.nextAt = nil
end

local function schedule(seconds, fn)
	cancelTimer()
	state.nextAt = GetTime() + seconds
	timer = C_Timer.NewTimer(seconds, function()
		timer = nil
		state.nextAt = nil
		fn()
	end)
end

local function isSendable(entry)
	return entry and (entry.kind == "chat" or entry.kind == "emote")
end
ns.IsSendableEntry = isSendable

local function isRehearsing()
	return ns.GetSettings().presenter.rehearse
end

local function resolveGroupChannel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	elseif IsInRaid() then
		return "RAID"
	elseif IsInGroup() then
		return "PARTY"
	end
end

function ns.ResolveChatType(entry)
	if entry.chatType == "GROUP" then
		return resolveGroupChannel()
	end
	return entry.chatType
end

local function inLockdown()
	if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
		local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
		return ok and locked == true
	end
	return false
end

-- true when this entry can't be sent from a timer right now
function ns.NeedsKeyPress(entry)
	if isRehearsing() then
		return false
	end
	if entry.kind == "emote" then
		return learnedRestricted.EMOTE_ACTION == true
	end
	return ns.ChatTypeNeedsKeyPress(ns.ResolveChatType(entry))
end

function ns.ChatTypeNeedsKeyPress(chatType)
	if not chatType or isRehearsing() then
		return false
	end
	if learnedRestricted[chatType] then
		return true
	end
	local def = ns.CHAT_TYPES[chatType]
	return def and def.restricted and not ns.InInstance() or false
end

local function resolveWhisperTarget(raw)
	local lower = raw:lower()
	local unit = ((lower == "%t" or lower == "%tt") and "target") or ((lower == "%f" or lower == "%ff") and "focus") or nil
	if unit then
		if not UnitExists(unit) or not UnitIsPlayer(unit) then
			return nil
		end
		local ok, name = pcall(GetUnitName, unit, true)
		if ok and name and not (issecretvalue and issecretvalue(name)) then
			return name
		end
		return nil
	end
	return ns.ExpandTokens(raw)
end

local function echoLocal(prefix, text, r, g, b)
	ns.GetOutputFrame():AddMessage(ns.ColorText("[Rehearse] " .. prefix .. " ", 0.7, 0.7, 0.7) .. ns.ColorText(text, r, g, b))
end

local function performEmote(token, command, target, trackIndex)
	if isRehearsing() then
		echoLocal("[Emote]", command .. (target and (" " .. target) or ""), ns.ChatColor("ACTION"))
		if not ns.GetSettings().presenter.rehearseEmotes then
			return true
		end
	end
	lastAttempt = { index = trackIndex, chatType = "EMOTE_ACTION" }
	state.blocked = false
	if C_ChatInfo and C_ChatInfo.PerformEmote then
		C_ChatInfo.PerformEmote(token, target)
	elseif DoEmote then
		DoEmote(token, target)
	end
	return not state.blocked or "blocked"
end

-- external: a speech sent outside the presenter (macro quips), leaves state alone
local function sendEntry(entry, external)
	-- rehearsals don't count; a run counts once its first real line goes out
	if not isRehearsing() then
		if external then
			ns.MarkSpeechUsed(external)
		elseif not state.counted and state.speech then
			state.counted = true
			ns.MarkSpeechUsed(state.speech)
		end
	end
	local trackIndex = not external and state.index or nil

	if entry.kind == "emote" then
		local target = entry.target and ns.ExpandTokens(entry.target) or nil
		if not external then
			state.lastSent = entry.command .. (target and (" " .. target) or "")
		end
		local result = performEmote(entry.token, entry.command, target, trackIndex)
		if result == true and entry.emotes then
			for _, extra in ipairs(entry.emotes) do
				performEmote(extra.token, extra.command)
			end
		end
		return result
	end

	local chatType = ns.ResolveChatType(entry)
	if not chatType then
		ns.Print("Skipped a Group line: you aren't in a group.")
		return false
	end

	local target
	if chatType == "WHISPER" then
		target = resolveWhisperTarget(entry.target)
		if not target or target == "" then
			ns.Print("Skipped a whisper: no player to send it to.")
			return false
		end
	elseif chatType == "CHANNEL" then
		target = entry.channelNum
	end

	local text = ns.ExpandTokens(entry.text)
	local pieces
	if ns.GetSettings().playback.splitLongLines then
		pieces = ns.SplitMessage(text)
	else
		pieces = { text:sub(1, ns.MAX_CHAT_BYTES) }
	end
	if not external then
		state.lastSent = text
	end

	local queue = { list = pieces, i = 1, chatType = chatType, channelNum = entry.channelNum, target = target }
	local result = ns.SendQueuedPiece(queue, trackIndex)
	if result == true and entry.emotes then
		for _, emote in ipairs(entry.emotes) do
			performEmote(emote.token, emote.command)
		end
	end
	if result == true and queue.i <= #queue.list then
		return "partial", queue
	end
	return result
end

-- sends queue.list[queue.i] and advances i; a split line is one queue
function ns.SendQueuedPiece(queue, trackIndex)
	local piece = queue.list[queue.i]
	local chatType, target = queue.chatType, queue.target
	if isRehearsing() then
		local label = "[" .. ns.ChatLabel(chatType, queue.channelNum) .. (chatType == "WHISPER" and (" to " .. target) or "") .. "]"
		echoLocal(label, piece, ns.ChatColor(chatType))
		queue.i = queue.i + 1
		return true
	end
	lastAttempt = { index = trackIndex, chatType = chatType, piece = queue.i }
	state.blocked = false
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if piece and piece ~= "" then
		send(piece, chatType, nil, target)
	end
	if state.blocked then
		return "blocked"
	end
	queue.i = queue.i + 1
	return true
end

local function delayAfter(entry)
	local settings = ns.GetSettings().playback
	local base = (state.speech and tonumber(state.speech.delay)) or settings.delay
	if settings.scaleWithLength and entry and entry.text then
		base = base + (ns.Utf8Len(entry.text) / 50) * settings.secondsPer50Chars
	end
	return math.max(0.5, base)
end

local function hasSendableFrom(index)
	local lines = state.parsed and state.parsed.lines or {}
	for i = index, #lines do
		if isSendable(lines[i]) then
			return true
		end
	end
	return false
end

local SKIPPED_KINDS = { comment = true, section = true, channel = true, error = true }

local EMOTE_FOLLOW_DELAY = 0.5

-- the gap after a line: a /wait there replaces it, an action emote follows quickly
local function delayBeforeNext(index, sentText)
	local lines = state.parsed and state.parsed.lines or {}
	for i = index, #lines do
		local kind = lines[i].kind
		if kind == "wait" then
			return 0.05
		elseif kind == "emote" and ns.GetSettings().playback.emotesFollowLine then
			return EMOTE_FOLLOW_DELAY
		elseif not SKIPPED_KINDS[kind] then
			break
		end
	end
	return delayAfter({ text = sentText })
end

local function finish()
	cancelTimer()
	state.playing = false
	state.waiting = nil
	state.finished = true
	if ns.GetSettings().playback.finishSound then
		ns.PlaySoundChoice(ns.GetSettings().playback.finishSoundChoice)
	end
	refresh()
	if ns.GetSettings().presenter.closeOnFinish and ns.HidePresenter then
		C_Timer.After(1.5, function()
			if state.finished then
				ns.HidePresenter()
			end
		end)
	end
end

local step

local function waitForKey()
	state.waiting = "key"
	if ns.GetSettings().playback.waitSound then
		ns.PlaySoundChoice(ns.GetSettings().playback.waitSoundChoice)
	end
	refresh()
end

local function waitForLockdown()
	state.waiting = "lockdown"
	refresh()
	schedule(1, function()
		if state.waiting == "lockdown" then
			state.waiting = nil
			step(false)
		end
	end)
end

-- hardware: true when called straight from a click or key press
function step(hardware)
	local lines = state.parsed and state.parsed.lines
	if not lines then
		return
	end
	local queue = state.pieces
	if queue then
		if not isRehearsing() and inLockdown() then
			waitForLockdown()
			return
		end
		if not hardware and ns.ChatTypeNeedsKeyPress(queue.chatType) then
			waitForKey()
			return
		end
		state.waiting = nil
		local piece = queue.list[queue.i]
		if ns.SendQueuedPiece(queue, state.index) == "blocked" then
			return
		end
		local lineDone = queue.i > #queue.list
		if lineDone then
			state.pieces = nil
			state.index = state.index + 1
			if not hasSendableFrom(state.index) then
				finish()
				return
			end
		end
		refresh()
		if state.playing then
			local delay = lineDone and delayBeforeNext(state.index, piece) or delayAfter({ text = piece })
			schedule(delay, function() step(false) end)
		end
		return
	end
	while true do
		local entry = lines[state.index]
		if not entry then
			finish()
			return
		end
		if entry.kind == "wait" then
			state.index = state.index + 1
			if state.playing then
				refresh()
				schedule(entry.seconds, function() step(false) end)
				return
			end
		elseif entry.kind == "pause" then
			state.index = state.index + 1
			if state.playing then
				state.playing = false
				state.waiting = "pause"
				state.pauseNote = entry.text
				cancelTimer()
				ns.Print(entry.text and ("Paused: " .. entry.text) or "Paused. Press Play to continue.")
				if ns.GetSettings().playback.pauseSound then
					ns.PlaySoundChoice(ns.GetSettings().playback.pauseSoundChoice)
				end
				refresh()
				return
			end
		elseif isSendable(entry) then
			if not isRehearsing() and inLockdown() then
				waitForLockdown()
				return
			end
			if not hardware and ns.NeedsKeyPress(entry) then
				waitForKey()
				return
			end
			state.waiting = nil
			local result, pending = sendEntry(entry)
			if result == "blocked" then
				return
			elseif result == "partial" then
				state.pieces = pending
				refresh()
				if state.playing then
					schedule(delayAfter({ text = pending.list[1] }), function() step(false) end)
				end
				return
			end
			state.index = state.index + 1
			if not hasSendableFrom(state.index) then
				finish()
				return
			end
			if state.playing then
				refresh()
				local delay = delayBeforeNext(state.index, entry.text)
				schedule(delay, function() step(false) end)
			else
				refresh()
			end
			return
		else
			state.index = state.index + 1
		end
	end
end

local function sendQuip()
	if state.pieces then
		if not isRehearsing() and inLockdown() then
			ns.Print("The game is blocking addon chat right now (boss fights and similar). Try again after.")
			return
		end
		if ns.SendQueuedPiece(state.pieces) == true and state.pieces.i > #state.pieces.list then
			state.pieces = nil
		end
		refresh()
		return
	end
	local lines = state.parsed and state.parsed.lines or {}
	local options = {}
	for i, entry in ipairs(lines) do
		if isSendable(entry) and (i ~= state.lastQuipIndex or state.parsed.sendable == 1) then
			options[#options + 1] = i
		end
	end
	if #options == 0 then
		return
	end
	if not isRehearsing() and inLockdown() then
		ns.Print("The game is blocking addon chat right now (boss fights and similar). Try again after.")
		return
	end
	local pick = options[math.random(#options)]
	state.lastQuipIndex = pick
	state.index = pick
	local result, pending = sendEntry(lines[pick])
	if result == "partial" then
		state.pieces = pending
	end
	state.index = 1
	refresh()
end

local lastExternalPick = {}
local externalPieces = {}

function ns.SendRandomLine(speech)
	local queue = externalPieces[speech.id]
	if queue then
		if not isRehearsing() and inLockdown() then
			ns.Print("The game is blocking addon chat right now (boss fights and similar). Try again after.")
			return
		end
		if ns.SendQueuedPiece(queue) == true and queue.i > #queue.list then
			externalPieces[speech.id] = nil
		end
		return
	end
	local parsed = ns.GetParsed(speech)
	local options = {}
	for i, entry in ipairs(parsed.lines) do
		if isSendable(entry) and (i ~= lastExternalPick[speech.id] or parsed.sendable == 1) then
			options[#options + 1] = i
		end
	end
	if #options == 0 then
		ns.Print("\"" .. speech.name .. "\" has no lines to send.")
		return
	end
	if not isRehearsing() and inLockdown() then
		ns.Print("The game is blocking addon chat right now (boss fights and similar). Try again after.")
		return
	end
	local pick = options[math.random(#options)]
	lastExternalPick[speech.id] = pick
	local result, pending = sendEntry(parsed.lines[pick], speech)
	if result == "partial" then
		externalPieces[speech.id] = pending
	end
end

function ns.IsQuip()
	return state.speech and state.speech.kind == "quip"
end

function ns.LoadSpeech(id, opts)
	local speech = ns.GetSpeech(id)
	cancelTimer()
	state.speech = speech
	state.parsed = speech and ns.GetParsed(speech) or nil
	state.index = 1
	state.playing = false
	state.waiting = nil
	state.finished = false
	state.counted = false
	state.lastSent = nil
	state.lastQuipIndex = nil
	state.pieces = nil
	if opts then
		state.candidates = opts.candidates
		state.source = opts.source
		state.triggerLabel = opts.label
	end
	refresh()
	return speech
end

function ns.ReloadIfCurrent(id)
	if state.speech and state.speech.id == id then
		local index = state.index
		state.parsed = ns.GetParsed(state.speech)
		state.index = math.min(index, #state.parsed.lines + 1)
		refresh()
	end
end

function ns.OnSpeechDeleted(id)
	if state.speech and state.speech.id == id then
		ns.LoadSpeech(nil)
	end
	if state.candidates then
		for i = #state.candidates, 1, -1 do
			if state.candidates[i] == id then
				table.remove(state.candidates, i)
			end
		end
	end
end

local function ensureLoaded()
	if state.speech then
		return true
	end
	ns.Print("No speech loaded. Pick one in the presenter or the main window.")
	if ns.ShowPresenter then
		ns.ShowPresenter()
	end
	return false
end

function ns.Next()
	if not ensureLoaded() then
		return
	end
	if ns.IsQuip() then
		sendQuip()
		return
	end
	if state.finished then
		return
	end
	cancelTimer()
	if state.waiting == "pause" then
		state.waiting = nil
	end
	-- a manual press steps past waits and pauses to the next real line
	local lines = state.parsed.lines
	while lines[state.index] and not isSendable(lines[state.index]) do
		state.index = state.index + 1
	end
	if state.waiting == "lockdown" or (not isRehearsing() and inLockdown()) then
		state.waiting = nil
		ns.Print("The game is blocking addon chat right now (boss fights and similar). Try again after.")
		refresh()
		return
	end
	step(true)
end

function ns.Back()
	if not ensureLoaded() or ns.IsQuip() then
		return
	end
	cancelTimer()
	state.playing = false
	state.waiting = nil
	state.finished = false
	if state.pieces then
		state.pieces = nil
		refresh()
		return
	end
	local lines = state.parsed.lines
	for i = math.min(state.index - 1, #lines), 1, -1 do
		if isSendable(lines[i]) then
			state.index = i
			refresh()
			return
		end
	end
	state.index = 1
	refresh()
end

function ns.Skip()
	if not ensureLoaded() or ns.IsQuip() or state.finished then
		return
	end
	cancelTimer()
	state.waiting = nil
	state.pieces = nil
	local lines = state.parsed.lines
	while lines[state.index] and not isSendable(lines[state.index]) do
		state.index = state.index + 1
	end
	state.index = state.index + 1
	if not hasSendableFrom(state.index) then
		finish()
		return
	end
	if state.playing then
		schedule(delayAfter(nil), function() step(false) end)
	end
	refresh()
end

function ns.Restart()
	if not state.speech then
		return
	end
	cancelTimer()
	state.index = 1
	state.pieces = nil
	state.playing = false
	state.waiting = nil
	state.finished = false
	refresh()
end

function ns.JumpTo(index)
	if not state.parsed then
		return
	end
	cancelTimer()
	state.index = math.max(1, math.min(index, #state.parsed.lines + 1))
	state.pieces = nil
	state.waiting = nil
	state.finished = false
	if state.playing then
		step(true)
	else
		refresh()
	end
end

function ns.Play()
	if not ensureLoaded() then
		return
	end
	if ns.IsQuip() then
		sendQuip()
		return
	end
	if state.playing then
		return
	end
	if state.finished then
		ns.Restart()
	end
	state.playing = true
	if state.waiting == "pause" then
		state.waiting = nil
	end
	step(true)
end

function ns.Pause()
	cancelTimer()
	state.playing = false
	if state.waiting ~= "pause" then
		state.waiting = nil
	end
	refresh()
end

function ns.TogglePlay()
	if state.playing then
		ns.Pause()
	else
		ns.Play()
	end
end

function ns.Stop()
	ns.Pause()
	ns.Restart()
end

function ns.PendingPiece()
	local queue = state.pieces
	if not queue then
		return nil
	end
	return {
		kind = "chat", chatType = queue.chatType, channelNum = queue.channelNum, target = queue.target,
		text = queue.list[queue.i], expanded = true, continued = true,
	}
end

function ns.PeekUpcoming(n)
	local out = {}
	local lines = state.parsed and state.parsed.lines or {}
	local first = state.index
	local pending = ns.PendingPiece()
	if pending then
		out[1] = pending
		first = state.index + 1
	end
	for i = first, #lines do
		if isSendable(lines[i]) then
			out[#out + 1] = lines[i]
			if #out >= n then
				break
			end
		end
	end
	return out
end

function ns.PlaybackProgress()
	local lines = state.parsed and state.parsed.lines or {}
	local sent, total = 0, 0
	for i, entry in ipairs(lines) do
		if isSendable(entry) then
			total = total + 1
			if i < state.index then
				sent = sent + 1
			end
		end
	end
	return sent, total
end

function ns.CurrentSectionName()
	local sections = state.parsed and state.parsed.sections or {}
	local name
	for _, section in ipairs(sections) do
		if section.index <= state.index then
			name = section.name
		end
	end
	return name
end

-- blocked sends land here; that line is retried on the next key press
local blockWatcher = CreateFrame("Frame")
blockWatcher:RegisterEvent("ADDON_ACTION_BLOCKED")
blockWatcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blockWatcher:SetScript("OnEvent", function(_, _, addonName)
	if addonName ~= ns.name or not lastAttempt then
		return
	end
	local attempt = lastAttempt
	lastAttempt = nil
	state.blocked = true
	if not learnedRestricted[attempt.chatType] then
		learnedRestricted[attempt.chatType] = true
		ns.Print("The game wants a key press for that kind of line here. Auto-play will stop and wait for you on those.")
	end
	if not attempt.index or ns.IsQuip() then
		return
	end
	cancelTimer()
	state.index = attempt.index
	if attempt.piece and state.pieces then
		state.pieces.i = attempt.piece
	end
	state.finished = false
	if state.playing then
		waitForKey()
	else
		refresh()
	end
end)
