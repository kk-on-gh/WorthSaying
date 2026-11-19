local ns = WorthSaying

StaticPopupDialogs["WS_CONFIRM_RESET_UI"] = {
	text = "Reset every Worth Saying window (position, size, scale, opacity), column layouts and the minimap button? Your UI will reload.",
	button1 = "Reset UI",
	button2 = "Cancel",
	OnAccept = function()
		ns.ResetUISettings()
		ReloadUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["WS_CONFIRM_RESET_OPTIONS"] = {
	text = "Reset ALL Worth Saying options to their defaults? Your speeches are kept. Your UI will reload.",
	button1 = "Reset Options",
	button2 = "Cancel",
	OnAccept = function()
		ns.ResetAllSettings()
		ReloadUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["WS_CONFIRM_DELETE_ALL"] = {
	text = "Delete ALL %d of your speeches? This cannot be undone. Consider exporting them first.",
	button1 = "Delete Everything",
	button2 = "Cancel",
	OnAccept = function()
		ns.DeleteAllSpeeches()
		ns.LoadSpeech(nil, {})
		ns.SelectSpeech(nil)
		ns.RefreshAll()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local SLIDER_BLOCK_HEIGHT = 52

local function setContainerEnabled(container, enabled)
	container:SetAlpha(enabled and 1 or 0.4)
	local objType = container:GetObjectType()
	if objType == "EditBox" or objType == "Slider" then
		container:EnableMouse(enabled)
		if objType == "EditBox" then
			container:EnableKeyboard(enabled)
		end
	elseif objType == "CheckButton" or objType == "Button" then
		container:SetEnabled(enabled)
	end
	if container.GetChildren then
		for _, child in ipairs({ container:GetChildren() }) do
			setContainerEnabled(child, enabled)
		end
	end
end

local function buildCheckbox(parent, x, y, text, checked, onClick, tooltip)
	local check = ns.CreateSmallCheckbox(parent, 24, checked, onClick)
	check:SetPoint("TOPLEFT", x, y)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetText(text)
	check.label = label
	if tooltip then
		ns.AttachHookTooltip(check, tooltip)
	end
	return check
end

local function buildSlider(parent, opts)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", opts.x, opts.y)
	label:SetText(opts.label)

	local function formatValue(v)
		if opts.isPercent then
			return tostring(math.floor(v * 100 + 0.5))
		end
		return tostring(math.floor(v * 10 + 0.5) / 10)
	end

	local slider = ns.CreateSmallSlider(parent, opts.width or 150, opts.min, opts.max, opts.step, opts.getValue, function() end)
	slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 2, -12)

	local suffix = opts.isPercent and "%" or (opts.suffix or "")
	local lowText = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	lowText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
	lowText:SetText(formatValue(opts.min) .. suffix)
	local highText = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	highText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
	highText:SetText(formatValue(opts.max) .. suffix)

	local valueBox = ns.CreateSmallEditBox(parent, 36, 14)
	valueBox:SetPoint("TOP", slider, "BOTTOM", 0, -2)
	valueBox:SetText(formatValue(opts.getValue()))

	slider:SetScript("OnValueChanged", function(_, value)
		valueBox:SetText(formatValue(value))
		if not opts.commitOnRelease then
			opts.setValue(value)
		end
	end)
	if opts.commitOnRelease then
		slider:SetScript("OnMouseUp", function(self) opts.setValue(self:GetValue()) end)
	end

	local function applyBox()
		local num = tonumber(valueBox:GetText())
		if num then
			if opts.isPercent then
				num = num / 100
			end
			num = math.max(opts.min, math.min(opts.max, num))
			slider:SetValue(num)
			opts.setValue(num)
		end
		valueBox:SetText(formatValue(opts.getValue()))
		valueBox:ClearFocus()
	end
	valueBox:SetScript("OnEnterPressed", applyBox)
	valueBox:SetScript("OnEditFocusLost", applyBox)
	valueBox:SetScript("OnEscapePressed", function(self)
		self:SetText(formatValue(opts.getValue()))
		self:ClearFocus()
	end)

	return { label = label, slider = slider, valueBox = valueBox, lowText = lowText, highText = highText }
end

local function createSectionBox(parent, y, height, title)
	local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 12, y)
	box:SetPoint("TOPRIGHT", -12, y)
	box:SetHeight(height)
	ns.ApplyPanelBackdrop(box, 0.4)
	local titleText = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	titleText:SetPoint("TOPLEFT", 8, -6)
	titleText:SetText(title)
	box.titleText = titleText
	return box
end

local function playback()
	return ns.GetSettings().playback
end

local function presenter()
	return ns.GetSettings().presenter
end

local function triggers()
	return ns.GetSettings().triggers
end

local KEYBINDS = {
	{ binding = "WS_NEXT", label = "Send next line" },
	{ binding = "WS_PLAYPAUSE", label = "Play / pause" },
	{ binding = "WS_BACK", label = "Step back" },
	{ binding = "WS_PRESENTER", label = "Show presenter" },
	{ binding = "WS_WINDOW", label = "Main window" },
}

local keybindButtons = {}

local function buildKeybindBox(parent, y)
	local height = 152
	local box = createSectionBox(parent, y, height, "Keybinds")
	for i, def in ipairs(KEYBINDS) do
		local col = (i - 1) % 2
		local rowIndex = math.floor((i - 1) / 2)
		local label = ns.CreateLabel(box, def.label, "GameFontHighlightSmall")
		label:SetPoint("TOPLEFT", 10 + col * 300, -32 - rowIndex * 28)
		label:SetWidth(110)
		local button = ns.CreateKeybindButton(box, def.binding, 140)
		button:SetPoint("LEFT", label, "RIGHT", 6, 0)
		keybindButtons[#keybindButtons + 1] = button
	end
	local hint = ns.CreateLabel(box, "Click a button, then press a key. Escape cancels, right-click clears. Key presses count as a real press, so Say and Yell work from keybinds. A macro with /ws next works too.", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", 10, -120)
	hint:SetPoint("RIGHT", -10, 0)
	hint:SetWordWrap(true)
	return y - height - 6
end

local outputDropdown

local function outputTabOptions()
	local saved = ns.GetSettings().outputTab
	local mainName = "Main window"
	local options = {}
	local found = not saved
	for _, tab in ipairs(ns.GetChatTabs()) do
		if tab.frame == DEFAULT_CHAT_FRAME then
			mainName = "Main window (" .. tab.name .. ")"
		else
			options[#options + 1] = { value = tab.name, text = tab.name }
		end
		found = found or tab.name == saved
	end
	table.insert(options, 1, { value = "", text = mainName })
	if not found then
		options[#options + 1] = { value = saved, text = saved .. " (closed)" }
	end
	return options
end

local function buildPlaybackBox(parent, y)
	local height = 376
	local box = createSectionBox(parent, y, height, "Playback")

	local delay = buildSlider(box, {
		x = 10, y = -28, label = "Default delay after each line", min = 0.5, max = 15, step = 0.5, width = 180, suffix = "s",
		getValue = function() return playback().delay end,
		setValue = function(value)
			playback().delay = value
			if ns.RefreshPresenter then
				ns.RefreshPresenter()
			end
		end,
	})

	local perChar
	local scaleCheck = buildCheckbox(box, 230, -28, "Add time for longer lines", playback().scaleWithLength, function(checked)
		playback().scaleWithLength = checked
		for _, part in pairs(perChar) do
			setContainerEnabled(part, checked)
		end
	end, "Longer lines wait longer before the next one, so people have time to read.")
	scaleCheck:ClearAllPoints()
	scaleCheck:SetPoint("LEFT", delay.label, "LEFT", 220, 0)
	perChar = buildSlider(box, {
		x = 258, y = -50, label = "Extra seconds per 50 characters", min = 0.5, max = 4, step = 0.5, width = 160, suffix = "s",
		getValue = function() return playback().secondsPer50Chars end,
		setValue = function(value) playback().secondsPer50Chars = value end,
	})
	for _, part in pairs(perChar) do
		setContainerEnabled(part, scaleCheck:GetChecked())
	end

	buildCheckbox(box, 10, -120, "Split long lines into several messages", playback().splitLongLines, function(checked)
		playback().splitLongLines = checked
		ns.RefreshAll()
	end, "Chat messages are capped at 255 characters. With this on, longer lines are split at a sentence break. Off, they're cut off.")
	buildCheckbox(box, 10, -144, "Action emotes play right after the line before them", playback().emotesFollowLine, function(checked)
		playback().emotesFollowLine = checked
	end, "Emotes like /cheer or /bow usually go with the line before them, so they play half a second after it instead of waiting the full delay. A /wait line still overrides this. Text emotes (/e) keep the normal delay.")

	local function soundRow(y, text, enabledKey, choiceKey)
		local dropdown
		local check = buildCheckbox(box, 10, y, text, playback()[enabledKey], function(checked)
			playback()[enabledKey] = checked
			setContainerEnabled(dropdown, checked)
		end)
		dropdown = ns.CreateDropdown(box, ns.SOUND_OPTIONS,
			function(value) return playback()[choiceKey] == value end,
			function(value)
				playback()[choiceKey] = value
				ns.PlaySoundChoice(value)
			end, 150, 20)
		dropdown:SetPoint("LEFT", check.label, "RIGHT", 10, 0)
		ns.AttachHookTooltip(dropdown, "Picking a sound plays it.")
		setContainerEnabled(dropdown, check:GetChecked())
	end
	soundRow(-168, "Play a sound when auto-play needs your key press", "waitSound", "waitSoundChoice")
	soundRow(-192, "Play a sound when a speech pauses", "pauseSound", "pauseSoundChoice")
	soundRow(-216, "Play a sound when a speech finishes", "finishSound", "finishSoundChoice")
	buildCheckbox(box, 10, -240, "Count uses (Uses and Last Used columns)", playback().countUses, function(checked)
		playback().countUses = checked
	end)

	buildCheckbox(box, 10, -264, "Perform action emotes while rehearsing", ns.GetSettings().presenter.rehearseEmotes, function(checked)
		ns.GetSettings().presenter.rehearseEmotes = checked
	end, "Rehearse normally keeps everything to yourself. With this on, emotes like /cheer and {bow} are really performed, so you can check how they look. Players near you will see them. Text lines still only print to you.")

	local fallbackLabel = ns.CreateLabel(box, "%t or %f with no one there becomes", "GameFontHighlightSmall")
	fallbackLabel:SetPoint("TOPLEFT", 14, -298)
	local fallbackBox = ns.CreateSmallEditBox(box, 110, 18)
	fallbackBox:SetJustifyH("LEFT")
	fallbackBox:SetTextInsets(4, 4, 0, 0)
	fallbackBox:SetPoint("LEFT", fallbackLabel, "RIGHT", 6, 0)
	fallbackBox:SetText(playback().targetFallback or "")
	local function applyFallback(self)
		playback().targetFallback = ns.Trim(self:GetText())
		self:ClearFocus()
	end
	fallbackBox:SetScript("OnEnterPressed", applyFallback)
	fallbackBox:SetScript("OnEditFocusLost", applyFallback)
	ns.AttachTooltip(fallbackBox, "Used for %t, %tt, %f and %ff when you have no target or focus. Leave blank to drop the word.")

	local roleLabel = ns.CreateLabel(box, "With nobody in a role, role tokens say", "GameFontHighlightSmall")
	roleLabel:SetPoint("TOPLEFT", 14, -324)
	local anchor = roleLabel
	for _, role in ipairs({ "tank", "healer", "dps" }) do
		local roleBox = ns.CreateSmallEditBox(box, 70, 18)
		roleBox:SetJustifyH("LEFT")
		roleBox:SetTextInsets(4, 4, 0, 0)
		roleBox:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
		roleBox:SetText(playback().roleFallbacks[role] or "")
		local function applyRole(self)
			playback().roleFallbacks[role] = ns.Trim(self:GetText())
			self:ClearFocus()
		end
		roleBox:SetScript("OnEnterPressed", applyRole)
		roleBox:SetScript("OnEditFocusLost", applyRole)
		ns.AttachTooltip(roleBox, "Used for %" .. role .. " and %r" .. role .. " when nobody in your group has that role. Leave blank to drop the word.")
		anchor = roleBox
	end

	local outputLabel = ns.CreateLabel(box, "Rehearse lines and addon messages go to", "GameFontHighlightSmall")
	outputLabel:SetPoint("TOPLEFT", 14, -350)
	outputDropdown = ns.CreateDropdown(box, outputTabOptions,
		function(value) return (ns.GetSettings().outputTab or "") == value end,
		function(value)
			ns.GetSettings().outputTab = value ~= "" and value or nil
			ns.Print("messages will show up here.")
		end, 180, 20)
	outputDropdown:SetPoint("LEFT", outputLabel, "RIGHT", 8, 0)
	ns.AttachHookTooltip(outputDropdown, "Which chat tab gets [Rehearse] lines and Worth Saying's own messages. These aren't a chat type, so the tab's chat filters don't affect them. If the tab is closed or renamed, they go to the main window.")

	return y - height - 6
end

local function buildPresenterBox(parent, y)
	local height = 152
	local box = createSectionBox(parent, y, height, "Presenter")

	buildSlider(box, {
		x = 10, y = -28, label = "Opacity", min = 0.3, max = 1, step = 0.05, width = 150, isPercent = true,
		getValue = function() return presenter().alpha end,
		setValue = function(value)
			presenter().alpha = value
			ns.ApplyPresenterLook()
		end,
	})
	buildSlider(box, {
		x = 200, y = -28, label = "Scale", min = 0.6, max = 1.8, step = 0.05, width = 150, isPercent = true, commitOnRelease = true,
		getValue = function() return presenter().scale end,
		setValue = function(value)
			presenter().scale = value
			ns.ApplyPresenterLook()
		end,
	})

	buildCheckbox(box, 10, -92, "Show the line after next", presenter().showNext, function(checked)
		presenter().showNext = checked
		ns.RefreshAll()
	end)
	buildCheckbox(box, 10, -116, "Close the presenter when a speech finishes", presenter().closeOnFinish, function(checked)
		presenter().closeOnFinish = checked
	end)
	buildCheckbox(box, 300, -92, "Lock position", presenter().locked, function(checked)
		presenter().locked = checked
		ns.ApplyPresenterLook()
	end)
	local show = ns.CreateButton(box, "Show Presenter", 120, 20, function() ns.ShowPresenter() end)
	show:SetPoint("TOPLEFT", 300, -118)
	return y - height - 6
end

local PICK_OPTIONS = {
	{ value = "random", text = "Random" },
	{ value = "randomFavorite", text = "Random favorite" },
	{ value = "mostUsed", text = "Most used" },
	{ value = "leastUsed", text = "Least used" },
	{ value = "lastUsed", text = "Last used" },
	{ value = "longestUnused", text = "Longest unused" },
}

local function buildTriggersBox(parent, y)
	local height = 186
	local box = createSectionBox(parent, y, height, "Triggers")

	local body = CreateFrame("Frame", nil, box)
	body:SetPoint("TOPLEFT", 0, -50)
	body:SetPoint("BOTTOMRIGHT", 0, 0)

	buildCheckbox(box, 10, -24, "Pop up speeches automatically", triggers().enabled, function(checked)
		triggers().enabled = checked
		setContainerEnabled(body, checked)
	end, "Speeches with triggers (set them in the editor) open the presenter when you arrive. Nothing is sent until you press Send or Play, unless you turn on auto-play below.")

	buildCheckbox(body, 10, 0, "Entering an instance", triggers().instance, function(c) triggers().instance = c end)
	buildCheckbox(body, 10, -24, "Entering a zone", triggers().zone, function(c) triggers().zone = c end)
	buildCheckbox(body, 10, -48, "Entering a subzone", triggers().subzone, function(c) triggers().subzone = c end)
	buildCheckbox(body, 10, -72, "Joining a group", triggers().group, function(c) triggers().group = c end)

	local pickLabel = ns.CreateLabel(body, "With several speeches for a place, pick")
	pickLabel:SetPoint("TOPLEFT", 10, -104)
	local pickDropdown = ns.CreateDropdown(body, PICK_OPTIONS,
		function(value) return triggers().pick == value end,
		function(value) triggers().pick = value end, 150, 20)
	pickDropdown:SetPoint("LEFT", pickLabel, "RIGHT", 8, 0)
	ns.AttachHookTooltip(pickDropdown, "Which speech opens first. The rest are always in the presenter's dropdown.\n\nRandom favorite: any favorite, or any speech if none are.\nMost/Least used: by the Uses count.\nLast used: the one you used most recently.\nLongest unused: the one you haven't used in the longest, so they take turns.\n\nTies are picked at random.")

	buildCheckbox(body, 260, 26, "Start auto-play right away", triggers().autoPlay, function(c) triggers().autoPlay = c end,
		"Off: the presenter opens and waits for you. On: it starts playing as soon as it opens.")
	buildCheckbox(body, 260, 2, "Wait until out of combat", triggers().skipInCombat, function(c) triggers().skipInCombat = c end)
	buildCheckbox(body, 260, -22, "Play a sound when one pops up", triggers().sound, function(c) triggers().sound = c end)
	buildCheckbox(body, 260, -46, "Close it again when you leave", triggers().closeOnLeave, function(c) triggers().closeOnLeave = c end,
		"Closes a triggered presenter when you leave the instance, unless it's playing.")

	setContainerEnabled(body, triggers().enabled)
	return y - height - 6
end

local function buildWindowBox(parent, y)
	local height = 150
	local box = createSectionBox(parent, y, height, "Main Window")
	local settings = ns.GetSettings()

	buildSlider(box, {
		x = 10, y = -28, label = "Opacity", min = 0.3, max = 1.0, step = 0.05, width = 150, isPercent = true,
		getValue = function() return settings.windowAlpha end,
		setValue = function(value)
			settings.windowAlpha = value
			ns.EnsureMainFrame():SetAlpha(value)
		end,
	})
	buildSlider(box, {
		x = 200, y = -28, label = "Scale", min = 0.6, max = 1.6, step = 0.05, width = 150, isPercent = true, commitOnRelease = true,
		getValue = function() return settings.uiScale end,
		setValue = function(value)
			ns.EnsureMainFrame()
			ns.SetMainWindowScale(value)
		end,
	})

	local timeLabel = ns.CreateLabel(box, "Time format")
	timeLabel:SetPoint("TOPLEFT", 10, -92)
	local timeDropdown = ns.CreateDropdown(box, {
		{ value = "24h", text = "24-hour" },
		{ value = "12h", text = "12-hour" },
	}, function(value) return settings.timeFormat == value end,
		function(value) settings.timeFormat = value; ns.RefreshAll() end, 120, 20)
	timeDropdown:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -4)

	local dateLabel = ns.CreateLabel(box, "Date format")
	dateLabel:SetPoint("TOPLEFT", 200, -92)
	local dateDropdown = ns.CreateDropdown(box, {
		{ value = "ymd", text = "YYYY-MM-DD" },
		{ value = "mdy", text = "MM-DD-YYYY" },
		{ value = "dmy", text = "DD-MM-YYYY" },
	}, function(value) return settings.dateFormat == value end,
		function(value) settings.dateFormat = value; ns.RefreshAll() end, 150, 20)
	dateDropdown:SetPoint("TOPLEFT", dateLabel, "BOTTOMLEFT", 0, -4)

	buildCheckbox(box, 390, -30, "Show minimap icon", not settings.minimapIcon.hide, function(checked)
		ns.SetMinimapIconShown(checked)
	end)
	buildCheckbox(box, 390, -54, "Show patch notes after updates", settings.showPatchNotesOnUpdate, function(checked)
		settings.showPatchNotesOnUpdate = checked
	end)
	return y - height - 6
end

local function buildDangerBox(parent, y)
	local height = 64
	local box = createSectionBox(parent, y, height, "Danger Zone")
	box.titleText:SetTextColor(1, 0.4, 0.4)

	local resetUI = ns.CreateButton(box, "Reset UI", 100, 22, function() StaticPopup_Show("WS_CONFIRM_RESET_UI") end,
		"Window positions, sizes, scale, opacity, column layouts and the minimap button. Reloads your UI.")
	resetUI:SetPoint("TOPLEFT", 10, -30)
	local resetOptions = ns.CreateButton(box, "Reset All Options", 130, 22, function() StaticPopup_Show("WS_CONFIRM_RESET_OPTIONS") end,
		"Every option back to its default. Speeches are kept. Reloads your UI.")
	resetOptions:SetPoint("LEFT", resetUI, "RIGHT", 8, 0)
	local deleteAll = ns.CreateButton(box, "Delete All Speeches", 140, 22, function()
		StaticPopup_Show("WS_CONFIRM_DELETE_ALL", ns.CountSpeeches())
	end)
	deleteAll:SetPoint("LEFT", resetOptions, "RIGHT", 8, 0)
	return y - height - 6
end

function ns.BuildOptionsPanel(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)
	local child = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(child)
	scroll:SetScript("OnSizeChanged", function(_, width) child:SetWidth(width) end)
	child:SetWidth(math.max(600, parent:GetWidth() - 34))

	local y = -4
	y = buildKeybindBox(child, y)
	y = buildPlaybackBox(child, y)
	y = buildPresenterBox(child, y)
	y = buildTriggersBox(child, y)
	y = buildWindowBox(child, y)
	y = buildDangerBox(child, y)
	child:SetHeight(-y + 10)

	parent:SetScript("OnShow", function()
		for _, button in ipairs(keybindButtons) do
			button.Refresh()
		end
		if outputDropdown then
			outputDropdown:Refresh()
		end
	end)
end
