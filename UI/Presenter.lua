local ns = WorthSaying
local Skin = ns.Skin

local WIDTH, HEIGHT = 420, 214
local MINI_WIDTH, MINI_HEIGHT = 230, 34
local frame
local speechOptions = {}
local sectionOptions = {}
local pulse = 0

local function bindingHint(bindingName)
	local key = GetBindingKey(bindingName)
	return key and ("\n\nKeybind: " .. (GetBindingText and GetBindingText(key) or key)) or "\n\nNo keybind set. You can set one in Options."
end

local function refillSpeechOptions()
	wipe(speechOptions)
	local state = ns.GetPlaybackState()
	local list = {}
	if state.candidates and #state.candidates > 0 then
		for _, id in ipairs(state.candidates) do
			local speech = ns.GetSpeech(id)
			if speech then
				list[#list + 1] = speech
			end
		end
	else
		list = ns.GetAllSpeeches()
		table.sort(list, function(a, b)
			if (a.favorite and true or false) ~= (b.favorite and true or false) then
				return a.favorite and true or false
			end
			return a.name:lower() < b.name:lower()
		end)
	end
	for _, speech in ipairs(list) do
		local prefix = speech.favorite and "|cffffd100*|r " or ""
		local suffix = speech.kind == "quip" and " |cff8ce68c(quip)|r" or ""
		speechOptions[#speechOptions + 1] = { value = speech.id, text = prefix .. speech.name .. suffix }
	end
end

local function refillSectionOptions()
	wipe(sectionOptions)
	local state = ns.GetPlaybackState()
	local sections = state.parsed and state.parsed.sections or {}
	sectionOptions[1] = { value = 1, text = "Start" }
	for _, section in ipairs(sections) do
		sectionOptions[#sectionOptions + 1] = { value = section.index, text = section.name }
	end
end

local function entryDisplay(entry)
	if not entry then
		return "", 1, 1, 1
	end
	if entry.kind == "emote" then
		local r, g, b = ns.ChatColor("ACTION")
		return "[Emote] " .. entry.command .. (entry.target and (" " .. ns.ExpandTokens(entry.target)) or ""), r, g, b
	end
	local chatType = ns.ResolveChatType(entry) or entry.chatType
	local label = ns.ChatLabel(chatType, entry.channelNum)
	if entry.chatType == "GROUP" and not ns.ResolveChatType(entry) then
		label = "Group (not in one)"
	end
	if chatType == "WHISPER" then
		label = label .. " to " .. entry.target
	end
	local r, g, b = ns.ChatColor(chatType)
	local text = entry.expanded and entry.text or ns.ExpandTokens(entry.text)
	if entry.emotes and not entry.continued then
		for _, emote in ipairs(entry.emotes) do
			text = text .. " + " .. emote.command
		end
	end
	return "[" .. label .. "] " .. (entry.continued and "(continued) " or "") .. text, r, g, b
end

local function setStatus(text, r, g, b)
	frame.status:SetText(text or "")
	frame.status:SetTextColor(r or 0.8, g or 0.8, b or 0.8)
end

local function updateStatusLine()
	local state = ns.GetPlaybackState()
	if not state.speech then
		setStatus("")
		return
	end
	local rehearse = ns.GetSettings().presenter.rehearse
	if state.waiting == "key" then
		setStatus("Your turn: this line needs a key press here. Press Send or your Next key.", 1, 0.75, 0.2)
	elseif state.waiting == "lockdown" then
		setStatus("The game is blocking addon chat right now. Waiting until it lifts...", 1, 0.4, 0.4)
	elseif state.waiting == "pause" then
		if state.pauseNote then
			setStatus("Paused: " .. state.pauseNote .. "\nPress Play to continue.", 1, 0.82, 0)
		else
			setStatus("Paused at a /pause line. Press Play to continue, or Send for one line.", 1, 0.82, 0)
		end
	elseif state.finished then
		setStatus("Finished. Press Restart to go again.", 0.55, 0.9, 0.55)
	elseif state.playing and state.nextAt then
		setStatus(string.format("Playing: next line in %.1fs", math.max(0, state.nextAt - GetTime())), 0.55, 0.75, 1)
	elseif state.playing then
		setStatus("Playing", 0.55, 0.75, 1)
	elseif ns.IsQuip() then
		setStatus("Quip: each Send picks a random line." .. (rehearse and " Rehearsing." or ""), 0.7, 0.7, 0.7)
	elseif state.triggerLabel and state.index == 1 then
		setStatus(state.triggerLabel, 0.55, 0.9, 0.55)
	elseif rehearse then
		setStatus("Rehearsing: lines only print to your chat window.", 0.7, 0.7, 0.7)
	else
		setStatus("Ready", 0.7, 0.7, 0.7)
	end
end

local onUpdate

local function updateTicker(state)
	local needed = state.waiting == "key" or state.playing
	if needed and not frame.ticking then
		frame.ticking = true
		frame:SetScript("OnUpdate", onUpdate)
	elseif not needed and frame.ticking then
		frame.ticking = false
		frame:SetScript("OnUpdate", nil)
	end
end

function onUpdate(_, elapsed)
	local state = ns.GetPlaybackState()
	if state.waiting == "key" then
		pulse = pulse + elapsed * 4
		local a = 0.45 + 0.45 * math.abs(math.sin(pulse))
		if frame.outline then
			frame.outline:SetBackdropBorderColor(1, 0.6, 0.1, a)
		else
			frame:SetBackdropBorderColor(1, 0.6, 0.1, a)
		end
	end
	if state.playing and state.nextAt then
		frame.tick = (frame.tick or 0) + elapsed
		if frame.tick > 0.1 then
			frame.tick = 0
			updateStatusLine()
		end
	end
end

function ns.RefreshPresenter()
	if ns.RefreshFooter then
		ns.RefreshFooter()
	end
	if not frame or not frame:IsShown() then
		return
	end
	local state = ns.GetPlaybackState()
	local speech = state.speech
	local quip = ns.IsQuip()

	refillSpeechOptions()
	if speech then
		frame.speechDropdown:Refresh()
	else
		frame.speechDropdown:SetText(#speechOptions > 0 and "Choose a speech..." or "No speeches yet")
	end

	refillSectionOptions()
	local hasSections = speech and not quip and #sectionOptions > 1
	frame.sectionDropdown:SetShown(hasSections and true or false)
	if hasSections then
		frame.sectionDropdown:SetText(ns.CurrentSectionName() or "Start")
	end

	local sent, total = ns.PlaybackProgress()
	if quip then
		frame.counter:SetText(total .. (total == 1 and " line" or " lines"))
	elseif speech then
		frame.counter:SetText("Line " .. math.min(sent + 1, total) .. " / " .. total)
	else
		frame.counter:SetText("")
	end
	frame.progress:SetWidth(math.max(0.01, (frame.progressTrack:GetWidth()) * (total > 0 and (quip and 0 or sent / total) or 0)))

	if not speech then
		frame.upNextLabel:SetText("")
		frame.current:SetText("Pick a speech from the dropdown above, or open one from the main window.")
		frame.current:SetTextColor(0.6, 0.6, 0.6)
		frame.next:SetText("")
	elseif quip and ns.PendingPiece() then
		local text, r, g, b = entryDisplay(ns.PendingPiece())
		frame.upNextLabel:SetText("UP NEXT")
		frame.current:SetText(text)
		frame.current:SetTextColor(r, g, b)
		frame.next:SetText("")
	elseif quip then
		frame.upNextLabel:SetText(state.lastSent and "LAST SENT" or "RANDOM LINE")
		frame.current:SetText(state.lastSent or ("One of " .. total .. " lines, picked at random."))
		frame.current:SetTextColor(1, 1, 1)
		frame.next:SetText("")
	else
		local upcoming = ns.PeekUpcoming(2)
		if upcoming[1] then
			frame.upNextLabel:SetText("UP NEXT")
			frame.current:SetText(entryDisplay(upcoming[1]))
			frame.current:SetTextColor(select(2, entryDisplay(upcoming[1])))
		else
			frame.upNextLabel:SetText(state.lastSent and "LAST SENT" or "")
			frame.current:SetText(state.lastSent or "This speech has no lines to send yet.")
			frame.current:SetTextColor(0.7, 0.7, 0.7)
		end
		if ns.GetSettings().presenter.showNext and upcoming[2] then
			local text, r, g, b = entryDisplay(upcoming[2])
			frame.next:SetText("then: " .. text)
			frame.next:SetTextColor(r * 0.6, g * 0.6, b * 0.6)
		else
			frame.next:SetText("")
		end
	end

	for _, controls in ipairs({ frame.controls, frame.miniControls }) do
		controls.send:SetText((quip and not controls.compact) and "Send Random" or "Send")
		controls.send:SetEnabled(speech ~= nil and not (state.finished and not quip))
		controls.back:SetEnabled(speech ~= nil and not quip)
		controls.skip:SetEnabled(speech ~= nil and not quip and not state.finished)
		controls.restart:SetEnabled(speech ~= nil and not quip)
		controls.play:SetShown(not quip)
		controls.play:SetEnabled(speech ~= nil)
		controls.play:SetText(state.playing and "Pause" or (state.finished and "Replay" or "Play"))
		if state.waiting == "key" then
			controls.send:LockHighlight()
		else
			controls.send:UnlockHighlight()
		end
		if controls.rehearse then
			ns.UpdateRehearseButton(controls.rehearse)
		end
	end
	if frame.outline then
		frame.outline:SetShown(state.waiting == "key")
	elseif state.waiting ~= "key" then
		frame:SetBackdropBorderColor(1, 0.82, 0, 0.6)
	end
	frame.miniProgress:SetWidth(math.max(0.01, frame.miniTrack:GetWidth() * (total > 0 and (quip and 0 or sent / total) or 0)))

	frame.delayBox:SetText(tostring((speech and speech.delay) or ns.GetSettings().playback.delay))
	frame.delayBox:SetAlpha((speech and speech.delay) and 1 or 0.7)
	updateStatusLine()
	updateTicker(state)
end

local function applyLook()
	local settings = ns.GetSettings().presenter
	if math.abs(frame:GetScale() - settings.scale) > 0.001 and ns.SetScaleKeepingTopLeft(frame, settings.scale) then
		ns.SavePopupPosition(frame, "presenter")
	end
	frame:SetAlpha(settings.alpha)
	frame:SetMovable(not settings.locked)
	if settings.locked then
		frame:RegisterForDrag()
	else
		frame:RegisterForDrag("LeftButton")
	end
end

function ns.ApplyPresenterLook()
	if frame then
		applyLook()
	end
end

local function upNextHint()
	local entry = ns.PendingPiece() or (not ns.IsQuip() and ns.PeekUpcoming(1)[1])
	if not entry then
		return ""
	end
	local text, r, g, b = entryDisplay(entry)
	return "\n\nUp next: " .. ns.ColorText(text, r, g, b)
end

-- one set of playback buttons; built full size and compact
local function buildControls(parent, compact)
	local height = compact and 20 or 24
	local widths = compact and { 22, 22, 46, 22, 44 } or { 32, 32, 120, 32, 64 }
	local gap = compact and 2 or 4
	local c = { compact = compact }

	local function button(text, width, onClick, tip)
		local btn = ns.CreateButton(parent, text, width, height, onClick, tip)
		if compact then
			btn:SetNormalFontObject(Skin.Font(GameFontNormalSmall))
			btn:SetHighlightFontObject(Skin.Font(GameFontHighlightSmall))
			btn:SetDisabledFontObject(Skin.Font(GameFontDisableSmall))
		end
		return btn
	end

	c.restart = button("|<", widths[1], function() ns.Restart() end, "Restart from the top.")
	c.back = button("<", widths[2], function() ns.Back() end,
		function() return "Step back one line, so Send repeats it." .. bindingHint("WS_BACK") end)
	c.send = button("Send", widths[3], function() ns.Next() end,
		function() return "Send the next line now." .. (compact and upNextHint() or "") .. bindingHint("WS_NEXT") end)
	c.skip = button(">|", widths[4], function() ns.Skip() end, "Skip the next line without sending it.")
	c.play = button("Play", widths[5], function() ns.TogglePlay() end,
		function() return "Send lines on a timer. Outside instances, Say, Yell and numbered channels still need a key press each, so auto-play waits for you on those." .. bindingHint("WS_PLAYPAUSE") end)

	c.back:SetPoint("LEFT", c.restart, "RIGHT", gap, 0)
	c.send:SetPoint("LEFT", c.back, "RIGHT", gap, 0)
	c.skip:SetPoint("LEFT", c.send, "RIGHT", gap, 0)
	c.play:SetPoint("LEFT", c.skip, "RIGHT", gap * 2, 0)

	if not compact then
		c.rehearse = ns.CreateRehearseButton(parent, 76, 18)
	end
	return c
end

local function keepTopLeft()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left and top then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		ns.SavePopupPosition(frame, "presenter")
	end
end

local function setMinimized(minimized)
	ns.GetSettings().presenter.minimized = minimized
	keepTopLeft()
	frame.full:SetShown(not minimized)
	frame.mini:SetShown(minimized)
	frame:SetSize(minimized and MINI_WIDTH or WIDTH, minimized and MINI_HEIGHT or HEIGHT)
	ns.RefreshPresenter()
end

function ns.SetPresenterMinimized(minimized)
	if frame and ns.GetSettings().presenter.minimized ~= minimized then
		setMinimized(minimized)
	end
end

local function createFrame()
	frame = CreateFrame("Frame", "WSPresenter", UIParent, "BackdropTemplate")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	if not Skin.Panel(frame, "float") then
		frame:SetBackdrop({
			bgFile = "Interface/Buttons/WHITE8X8",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		frame:SetBackdropColor(0.1, 0.08, 0.06, 1)
		frame:SetBackdropBorderColor(1, 0.82, 0, 0.6)
	end
	frame.outline = Skin.CreateOutline(frame)
	ns.MakePopupDraggable(frame, "presenter")
	ns.RestorePopupPosition(frame, "presenter", "CENTER", "CENTER", 0, -180)

	local full = CreateFrame("Frame", nil, frame)
	full:SetAllPoints()
	frame.full = full

	local band = full:CreateTexture(nil, "BACKGROUND", nil, 1)
	if Skin.Band(band) then
		band:SetPoint("TOPLEFT", 1, -1)
		band:SetPoint("TOPRIGHT", -1, -1)
		band:SetHeight(33)
	else
		band:SetPoint("TOPLEFT", 4, -4)
		band:SetPoint("TOPRIGHT", -4, -4)
		band:SetHeight(28)
		band:SetColorTexture(0.42, 0.3, 0.14, 0.9)
		local grain = full:CreateTexture(nil, "BACKGROUND", nil, 2)
		grain:SetAllPoints(band)
		grain:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
		grain:SetVertexColor(0.75, 0.6, 0.35, 0.6)
	end

	local close = ns.CreateButton(full, "X", 20, 20, function() frame:Hide() end, nil, "CloseButton")
	close:SetPoint("TOPRIGHT", -8, -8)
	local minimize = ns.CreateButton(full, "_", 20, 20, function() setMinimized(true) end,
		"Shrink to just the playback buttons.")
	minimize:SetPoint("RIGHT", close, "LEFT", -4, 0)
	local openMain = ns.CreateButton(full, "...", 26, 20, function() ns.SelectSpeechesTab() end, "Open the main window.")
	openMain:SetPoint("RIGHT", minimize, "LEFT", -4, 0)

	frame.speechDropdown = ns.CreateDropdown(full, speechOptions,
		function(value) local s = ns.GetPlaybackState().speech; return s and s.id == value end,
		function(value)
			local state = ns.GetPlaybackState()
			ns.LoadSpeech(value, { candidates = state.candidates, source = state.source, label = state.triggerLabel })
		end, 250, 22)
	frame.speechDropdown:SetPoint("TOPLEFT", 8, -7)
	frame.speechDropdown:SetPoint("RIGHT", openMain, "LEFT", -8, 0)

	frame.sectionDropdown = ns.CreateDropdown(full, sectionOptions,
		function() return false end,
		function(value) ns.JumpTo(value) end, 170, 20)
	frame.sectionDropdown:SetPoint("TOPLEFT", 10, -38)
	ns.AttachHookTooltip(frame.sectionDropdown, "Jump to a ## section.")

	frame.counter = Skin.Text(full, "ARTWORK", "GameFontHighlightSmall")
	frame.counter:SetPoint("TOPRIGHT", -12, -42)

	frame.upNextLabel = Skin.Text(full, "ARTWORK", "GameFontNormalSmall")
	frame.upNextLabel:SetPoint("TOPLEFT", 12, -64)

	frame.current = Skin.Text(full, "ARTWORK", "GameFontHighlight")
	frame.current:SetPoint("TOPLEFT", frame.upNextLabel, "BOTTOMLEFT", 0, -4)
	frame.current:SetWidth(WIDTH - 24)
	frame.current:SetJustifyH("LEFT")
	frame.current:SetJustifyV("TOP")
	frame.current:SetWordWrap(true)
	frame.current:SetMaxLines(3)
	frame.current:SetHeight(44)

	frame.next = Skin.Text(full, "ARTWORK", "GameFontHighlightSmall")
	frame.next:SetPoint("TOPLEFT", frame.current, "BOTTOMLEFT", 0, -4)
	frame.next:SetWidth(WIDTH - 24)
	frame.next:SetJustifyH("LEFT")
	frame.next:SetWordWrap(true)
	frame.next:SetMaxLines(1)

	frame.progressTrack = full:CreateTexture(nil, "ARTWORK")
	frame.progressTrack:SetPoint("TOPLEFT", 12, -140)
	frame.progressTrack:SetPoint("TOPRIGHT", -12, -140)
	frame.progressTrack:SetHeight(3)
	Skin.Track(frame.progressTrack, 0.18)
	frame.progress = full:CreateTexture(nil, "OVERLAY")
	frame.progress:SetPoint("TOPLEFT", frame.progressTrack, "TOPLEFT")
	frame.progress:SetHeight(3)
	Skin.Accent(frame.progress, 0.9)

	local row = CreateFrame("Frame", nil, full)
	row:SetPoint("TOPLEFT", 10, -150)
	row:SetPoint("TOPRIGHT", -10, -150)
	row:SetHeight(24)
	frame.controls = buildControls(row, false)
	frame.controls.restart:SetPoint("LEFT", 0, 0)
	frame.controls.rehearse:SetPoint("BOTTOMRIGHT", full, "BOTTOMRIGHT", -10, 8)
	ns.RegisterTourTarget("presenter.controls", row)

	frame.delayBox = ns.CreateSmallEditBox(row, 34, 20)
	frame.delayBox:SetPoint("RIGHT", -12, 0)
	local delayUnit = ns.CreateLabel(row, "s", "GameFontHighlightSmall")
	delayUnit:SetPoint("LEFT", frame.delayBox, "RIGHT", 3, 0)
	ns.AttachTooltip(frame.delayBox, "Seconds to wait after each line for this speech, before the next one. Clear it to use the default.")
	local function applyDelay(self)
		local speech = ns.GetPlaybackState().speech
		if speech then
			local value = tonumber(self:GetText())
			if value then
				value = math.max(0.1, math.min(120, value))
				speech.delay = value ~= ns.GetSettings().playback.delay and value or nil
			elseif ns.Trim(self:GetText()) == "" then
				speech.delay = nil
			end
		end
		self:ClearFocus()
		ns.RefreshAll()
	end
	frame.delayBox:SetScript("OnEnterPressed", applyDelay)
	frame.delayBox:SetScript("OnEditFocusLost", applyDelay)
	frame.delayBox:SetScript("OnEscapePressed", frame.delayBox.ClearFocus)

	frame.status = Skin.Text(full, "ARTWORK", "GameFontHighlightSmall")
	frame.status:SetPoint("TOPLEFT", 12, -182)
	frame.status:SetPoint("RIGHT", -100, 0)
	frame.status:SetJustifyH("LEFT")
	frame.status:SetWordWrap(true)
	frame.status:SetMaxLines(2)

	local mini = CreateFrame("Frame", nil, frame)
	mini:SetAllPoints()
	mini:Hide()
	frame.mini = mini
	frame.miniControls = buildControls(mini, true)
	frame.miniControls.restart:SetPoint("LEFT", 7, 1)
	local miniClose = ns.CreateButton(mini, "X", 18, 18, function() frame:Hide() end, nil, "CloseButton")
	miniClose:SetPoint("RIGHT", -7, 1)
	local restore = ns.CreateButton(mini, "+", 18, 18, function() setMinimized(false) end, "Show the full presenter.")
	restore:SetPoint("RIGHT", miniClose, "LEFT", -2, 0)

	frame.miniTrack = mini:CreateTexture(nil, "ARTWORK")
	frame.miniTrack:SetPoint("BOTTOMLEFT", 6, 4)
	frame.miniTrack:SetPoint("BOTTOMRIGHT", -6, 4)
	frame.miniTrack:SetHeight(2)
	Skin.Track(frame.miniTrack, 0.15)
	frame.miniProgress = mini:CreateTexture(nil, "OVERLAY")
	frame.miniProgress:SetPoint("TOPLEFT", frame.miniTrack, "TOPLEFT")
	frame.miniProgress:SetHeight(2)
	Skin.Accent(frame.miniProgress, 0.8)

	frame:SetScript("OnShow", function() ns.RefreshPresenter() end)
	frame:SetScript("OnHide", function()
		frame.ticking = false
		frame:SetScript("OnUpdate", nil)
	end)
	frame:Hide()
	applyLook()
	if ns.GetSettings().presenter.minimized then
		setMinimized(true)
	end
end

function ns.EnsurePresenter()
	if not frame then
		createFrame()
	end
	return frame
end

function ns.ShowPresenter()
	local f = ns.EnsurePresenter()
	f:Show()
	f:Raise()
	ns.RefreshPresenter()
end

function ns.IsPresenterShown()
	return frame ~= nil and frame:IsShown()
end

function ns.HidePresenter()
	if frame then
		frame:Hide()
	end
end

function ns.TogglePresenter()
	local f = ns.EnsurePresenter()
	if f:IsShown() then
		f:Hide()
	else
		ns.ShowPresenter()
	end
end
