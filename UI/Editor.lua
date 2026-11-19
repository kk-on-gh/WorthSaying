local ns = WorthSaying

local editor
local currentId
local showingPreview = false
local suppressTextEvents = false
local saveTimer

local CHANNEL_OPTIONS = {}
for _, chatType in ipairs(ns.CHANNEL_ORDER) do
	CHANNEL_OPTIONS[#CHANNEL_OPTIONS + 1] = { value = chatType, text = ns.ChatLabel(chatType) }
end

local CHANNEL_TIP = "Lines with no /prefix go here. Group picks party, raid or instance chat for you when the line is sent."

local function currentSpeech()
	return ns.GetSpeech(currentId)
end

local function leftBox(parent, width, height)
	local box = ns.CreateSmallEditBox(parent, width, height or 20)
	box:SetJustifyH("LEFT")
	box:SetTextInsets(5, 5, 0, 0)
	box:SetFontObject(GameFontHighlight)
	box:SetScript("OnEnterPressed", box.ClearFocus)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	return box
end

local function scheduleSave()
	if saveTimer then
		saveTimer:Cancel()
	end
	saveTimer = C_Timer.NewTimer(0.35, function()
		saveTimer = nil
		local speech = currentSpeech()
		if speech then
			ns.TouchSpeech(speech)
			ns.ReloadIfCurrent(speech.id)
		end
		ns.RefreshEditorStatus()
		ns.RefreshAll()
	end)
end

local function describeEntry(entry)
	if entry.kind == "comment" then
		return ns.ColorText("// " .. entry.text, 0.5, 0.5, 0.5)
	elseif entry.kind == "section" then
		return ns.ColorText("== " .. entry.name .. " ==", ns.ChatColor("SECTION"))
	elseif entry.kind == "wait" then
		return ns.ColorText("(wait " .. entry.seconds .. "s)", ns.ChatColor("CONTROL"))
	elseif entry.kind == "pause" then
		return ns.ColorText("(pause auto-play" .. (entry.text and (": " .. entry.text) or "") .. ")", ns.ChatColor("CONTROL"))
	elseif entry.kind == "channel" then
		local label = ns.ChatLabel(entry.chatType, entry.channelNum)
		if entry.target then
			label = label .. " to " .. ns.PreviewTokens(entry.target, ns.ChatColor("CONTROL"))
		end
		return ns.ColorText("(following lines go to " .. label .. ")", ns.ChatColor("CONTROL"))
	elseif entry.kind == "error" then
		return ns.ColorText("Problem: " .. entry.message .. " (skipped)", ns.ChatColor("ERROR"))
	elseif entry.kind == "emote" then
		local extras = ""
		for _, emote in ipairs(entry.emotes or {}) do
			extras = extras .. " + " .. emote.command
		end
		return ns.ColorText("[Emote] " .. entry.command .. (entry.target and (" " .. ns.PreviewTokens(entry.target, ns.ChatColor("ACTION"))) or "") .. extras, ns.ChatColor("ACTION"))
	end
	local label = ns.ChatLabel(entry.chatType, entry.channelNum)
	if entry.chatType == "WHISPER" then
		label = label .. " to " .. ns.PreviewTokens(entry.target, ns.ChatColor(entry.chatType))
	end
	local text = ns.ColorText("[" .. label .. "] " .. ns.PreviewTokens(entry.text, ns.ChatColor(entry.chatType)), ns.ChatColor(entry.chatType))
	if entry.emotes then
		local commands = {}
		for _, emote in ipairs(entry.emotes) do
			commands[#commands + 1] = emote.command
		end
		text = text .. ns.ColorText("  + " .. table.concat(commands, " "), ns.ChatColor("ACTION"))
	end
	if entry.unknownEmotes then
		text = text .. ns.ColorText("  (not emotes, sent as text: " .. table.concat(entry.unknownEmotes, " ") .. ")", 1, 0.55, 0.2)
	end
	if entry.warning then
		local pieces = ns.GetSettings().playback.splitLongLines and #ns.SplitMessage(entry.text) or 1
		text = text .. ns.ColorText(pieces > 1 and ("  (too long, sent as " .. pieces .. " messages)") or "  (too long, will be cut off)", 1, 0.55, 0.2)
	end
	return text
end

local previewRows = {}

local function refreshPreview()
	if not editor or not showingPreview then
		return
	end
	local speech = currentSpeech()
	local child = editor.previewChild
	local width = math.max(100, editor.previewScroll:GetWidth() - 8)
	child:SetWidth(width)
	local lines = speech and ns.GetParsed(speech).lines or {}
	local y = -2
	for i, entry in ipairs(lines) do
		local row = previewRows[i]
		if not row then
			row = CreateFrame("Button", nil, child)
			row.num = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
			row.num:SetPoint("TOPLEFT", 2, -2)
			row.num:SetWidth(26)
			row.num:SetJustifyH("RIGHT")
			row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			row.text:SetPoint("TOPLEFT", 34, -2)
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(true)
			local hl = row:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			hl:SetColorTexture(1, 0.82, 0, 0.1)
			previewRows[i] = row
		end
		row.num:SetText(entry.lineNo)
		row.text:SetWidth(width - 40)
		row.text:SetText(describeEntry(entry))
		local height = math.max(16, row.text:GetStringHeight() + 4)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, y)
		row:SetSize(width, height)
		row:SetScript("OnClick", function()
			if speech then
				ns.LoadSpeech(speech.id, {})
				ns.JumpTo(i)
				ns.ShowPresenter()
			end
		end)
		row:Show()
		y = y - height
	end
	for i = #lines + 1, #previewRows do
		previewRows[i]:Hide()
	end
	child:SetHeight(math.max(1, -y + 4))
end

function ns.RefreshEditorStatus()
	if not editor then
		return
	end
	local speech = currentSpeech()
	if not speech then
		editor.status:SetText("")
		return
	end
	local parsed = ns.GetParsed(speech)
	local parts = { parsed.sendable .. (parsed.sendable == 1 and " line" or " lines") }
	if #parsed.sections > 0 then
		parts[#parts + 1] = #parsed.sections .. (#parsed.sections == 1 and " section" or " sections")
	end
	if parsed.warnings > 0 then
		parts[#parts + 1] = ns.ColorText(parsed.warnings .. " too long", 1, 0.55, 0.2)
	end
	if parsed.errors > 0 then
		parts[#parts + 1] = ns.ColorText(parsed.errors .. (parsed.errors == 1 and " problem" or " problems"), 1, 0.3, 0.3)
	end
	editor.status:SetText(table.concat(parts, "  \124\124  "))
	refreshPreview()
end

local function setPreviewMode(preview)
	showingPreview = preview
	editor.scriptHolder:SetShown(not preview)
	editor.previewHolder:SetShown(preview)
	editor.scriptTab:SetEnabled(preview)
	editor.previewTab:SetEnabled(not preview)
	if preview then
		editor.scriptHolder.editBox:ClearFocus()
		refreshPreview()
	end
end

local chipPool = {}

local function layoutTriggerChips()
	local speech = currentSpeech()
	local area = editor.chipArea
	local triggers = speech and speech.triggers or {}
	local maxWidth = math.max(100, area:GetWidth())
	local x, y, rowHeight = 0, 0, 22
	for i, trigger in ipairs(triggers) do
		local chip = chipPool[i]
		if not chip then
			chip = ns.CreateButton(area, "", 60, 20, nil, "Click to remove this trigger.")
			chipPool[i] = chip
		end
		chip:SetText(ns.TriggerText(trigger) .. "  |cffff6060x|r")
		chip:SetWidth(math.min(maxWidth, chip:GetFontString():GetStringWidth() + 20))
		if x > 0 and x + chip:GetWidth() > maxWidth then
			x = 0
			y = y - rowHeight
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", x, y)
		chip:SetScript("OnClick", function()
			table.remove(speech.triggers, i)
			ns.TouchSpeech(speech)
			layoutTriggerChips()
			ns.RefreshAll()
		end)
		chip:Show()
		x = x + chip:GetWidth() + 4
	end
	for i = #triggers + 1, #chipPool do
		chipPool[i]:Hide()
	end
	local rows = #triggers == 0 and 1 or (1 + math.floor(-y / rowHeight))
	editor.noTriggers:SetShown(#triggers == 0)
	area:SetHeight(rows * rowHeight)
	editor.header:SetHeight(70 + rows * rowHeight + 10)
end

StaticPopupDialogs["WS_ADD_TRIGGER_NAME"] = {
	text = "%s",
	button1 = "Add",
	button2 = "Cancel",
	hasEditBox = true,
	OnAccept = function(self, data)
		local box = self.editBox or self.EditBox
		local name = ns.Trim(box and box:GetText() or "")
		if name ~= "" then
			data.add({ type = data.triggerType, name = name })
		end
	end,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		StaticPopupDialogs["WS_ADD_TRIGGER_NAME"].OnAccept(parent, parent.data)
		parent:Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function addTrigger(trigger)
	local speech = currentSpeech()
	if not speech or not trigger then
		return
	end
	for _, existing in ipairs(speech.triggers) do
		if existing.type == trigger.type and (existing.name or ""):lower() == (trigger.name or ""):lower() then
			return
		end
	end
	speech.triggers[#speech.triggers + 1] = trigger
	ns.TouchSpeech(speech)
	layoutTriggerChips()
	ns.RefreshAll()
end

local function showAddTriggerMenu(anchor)
	MenuUtil.CreateContextMenu(anchor, function(_, root)
		root:CreateTitle("Pop up this speech when...")
		local here = {
			{ type = "instance", label = "Entering this instance" },
			{ type = "zone", label = "Entering this zone" },
			{ type = "subzone", label = "Entering this subzone" },
		}
		for _, def in ipairs(here) do
			local trigger = ns.CurrentLocationTrigger(def.type)
			local button = root:CreateButton(def.label .. (trigger and (" (" .. trigger.name .. ")") or ""), function()
				addTrigger(trigger)
			end)
			if not trigger and button.SetEnabled then
				button:SetEnabled(false)
			end
		end
		root:CreateButton("Joining a group", function() addTrigger({ type = "group" }) end)
		root:CreateDivider()
		local instances = ns.GetInstanceList()
		local picker = root:CreateButton("Pick an instance")
		if #instances == 0 then
			picker:CreateTitle("None found yet. Open the Group Finder once, or enter an instance.")
		end
		local groups = { { kind = "dungeon", label = "Dungeons" }, { kind = "raid", label = "Raids" }, { kind = "other", label = "Other" } }
		for _, group in ipairs(groups) do
			local sub
			for _, instance in ipairs(instances) do
				if instance.kind == group.kind then
					if not sub then
						sub = picker:CreateButton(group.label)
						sub:SetScrollMode(400)
					end
					sub:CreateButton(instance.name, function()
						addTrigger({ type = "instance", name = instance.name, id = instance.id })
					end)
				end
			end
		end
		for _, triggerType in ipairs({ "instance", "zone", "subzone" }) do
			root:CreateButton((triggerType == "instance" and "Type an " or "Type a ") .. triggerType .. " name...", function()
				StaticPopup_Show("WS_ADD_TRIGGER_NAME", "Exact " .. triggerType .. " name, as the game shows it:", nil,
					{ triggerType = triggerType, add = addTrigger })
			end)
		end
	end)
end

local function showTagMenu(anchor)
	local speech = currentSpeech()
	if not speech then
		return
	end
	MenuUtil.CreateContextMenu(anchor, function(_, root)
		local tags = ns.GetAllTags()
		if #tags == 0 then
			root:CreateTitle("No tags yet. Type some in the box.")
			return
		end
		root:CreateTitle("Tags")
		for _, tag in ipairs(tags) do
			root:CreateCheckbox(tag, function() return ns.SpeechHasTag(speech, tag) end, function()
				if ns.SpeechHasTag(speech, tag) then
					for i = #speech.tags, 1, -1 do
						if speech.tags[i]:lower() == tag:lower() then
							table.remove(speech.tags, i)
						end
					end
				else
					speech.tags[#speech.tags + 1] = tag
				end
				editor.tagsBox:SetText(table.concat(speech.tags, ", "))
				ns.TouchSpeech(speech)
				ns.RefreshAll()
			end)
		end
	end)
end

local function updateKindControls(speech)
	local isQuip = speech and speech.kind == "quip"
	editor.delayBox:EnableMouse(not isQuip)
	editor.delayBox:EnableKeyboard(not isQuip)
	editor.delayBox:SetAlpha(isQuip and 0.4 or 1)
	editor.delayLabel:SetAlpha(isQuip and 0.4 or 1)
	editor.playButton:SetText(isQuip and "Send Random" or "Auto-Play")
end

function ns.LoadEditor(id)
	currentId = id
	if not editor then
		return
	end
	local speech = currentSpeech()
	editor.body:SetShown(speech ~= nil)
	editor.empty:SetShown(speech == nil)
	if not speech then
		return
	end
	suppressTextEvents = true
	editor.nameBox:SetText(speech.name)
	editor.tagsBox:SetText(table.concat(speech.tags, ", "))
	editor.delayBox:SetText(speech.delay and tostring(speech.delay) or "")
	editor.scriptHolder.editBox:SetText(speech.text)
	editor.scriptHolder.editBox:SetCursorPosition(0)
	editor.scriptHolder.editBox.ResetUndo()
	editor.scriptHolder.scroll:SetVerticalScroll(0)
	editor.favCheck:SetChecked(speech.favorite and true or false)
	suppressTextEvents = false
	editor.kindDropdown:Refresh()
	editor.channelDropdown:Refresh()
	updateKindControls(speech)
	layoutTriggerChips()
	ns.RefreshEditorStatus()
end

function ns.RefreshEditor()
	if not editor then
		return
	end
	local speech = currentSpeech()
	if not speech and currentId then
		ns.LoadEditor(nil)
		return
	end
	if speech then
		editor.favCheck:SetChecked(speech.favorite and true or false)
		ns.RefreshEditorStatus()
	end
end

function ns.FocusEditorName()
	if editor then
		editor.nameBox:SetFocus()
		editor.nameBox:HighlightText()
	end
end

function ns.BuildEditor(parent)
	editor = {}

	editor.empty = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	editor.empty:SetPoint("CENTER")
	editor.empty:SetText("Select a speech on the left, or make a new one.")

	local body = CreateFrame("Frame", nil, parent)
	body:SetPoint("TOPLEFT", 8, 0)
	body:SetPoint("BOTTOMRIGHT", 0, 0)
	editor.body = body

	local header = CreateFrame("Frame", nil, body, "BackdropTemplate")
	ns.ApplyPanelBackdrop(header, 0.4)
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", 0, 0)
	editor.header = header

	local LABEL_WIDTH = 54
	local nameLabel = ns.CreateLabel(header, "Name")
	nameLabel:SetPoint("TOPLEFT", 10, -10)
	nameLabel:SetWidth(LABEL_WIDTH)

	local kindDropdown = ns.CreateDropdown(header, ns.SPEECH_KINDS,
		function(value) local s = currentSpeech(); return s and s.kind == value end,
		function(value)
			local s = currentSpeech()
			if s then
				s.kind = value
				ns.TouchSpeech(s)
				updateKindControls(s)
				ns.ReloadIfCurrent(s.id)
				ns.RefreshAll()
			end
		end, 96, 20)
	kindDropdown:SetPoint("TOPRIGHT", -10, -6)
	ns.AttachHookTooltip(kindDropdown, "Speech: sent line by line, in order.\n\nQuip: each send picks one random line.")
	editor.kindDropdown = kindDropdown

	local favCheck = ns.CreateSmallCheckbox(header, 22, false, function(checked)
		local s = currentSpeech()
		if s then
			s.favorite = checked or nil
			ns.RefreshAll()
		end
	end)
	favCheck:SetPoint("RIGHT", kindDropdown, "LEFT", -54, 0)
	local favLabel = ns.CreateLabel(header, "Favorite", "GameFontHighlightSmall")
	favLabel:SetPoint("LEFT", favCheck, "RIGHT", 2, 0)
	editor.favCheck = favCheck

	local nameBox = leftBox(header, 100, 20)
	nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 4, 0)
	nameBox:SetPoint("RIGHT", favCheck, "LEFT", -10, 0)
	nameBox:SetScript("OnTextChanged", function(self, userInput)
		if suppressTextEvents or not userInput then
			return
		end
		local s = currentSpeech()
		if s then
			local text = ns.Trim(self:GetText())
			s.name = text ~= "" and text or "Untitled"
			scheduleSave()
		end
	end)
	editor.nameBox = nameBox

	local tagsLabel = ns.CreateLabel(header, "Tags")
	tagsLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -16)
	tagsLabel:SetWidth(LABEL_WIDTH)

	local delayLabel = ns.CreateLabel(header, "Delay")
	editor.delayLabel = delayLabel
	local delayBox = ns.CreateSmallEditBox(header, 40, 20)
	delayBox:SetFontObject(GameFontHighlight)
	delayBox:SetPoint("TOPRIGHT", -24, -34)
	delayLabel:SetPoint("RIGHT", delayBox, "LEFT", -6, 0)
	local secondsText = ns.CreateLabel(header, "s", "GameFontHighlightSmall")
	secondsText:SetPoint("LEFT", delayBox, "RIGHT", 3, 0)
	ns.AttachTooltip(delayBox, "Seconds to wait after each line during auto-play, before the next one. Leave blank to use the default from Options.")
	local function applyDelay(self)
		local s = currentSpeech()
		if s then
			local value = tonumber(self:GetText())
			s.delay = value and math.max(0.5, math.min(120, value)) or nil
			self:SetText(s.delay and tostring(s.delay) or "")
			ns.TouchSpeech(s)
		end
		self:ClearFocus()
	end
	delayBox:SetScript("OnEnterPressed", applyDelay)
	delayBox:SetScript("OnEditFocusLost", applyDelay)
	delayBox:SetScript("OnEscapePressed", delayBox.ClearFocus)
	editor.delayBox = delayBox

	local channelDropdown = ns.CreateDropdown(header, CHANNEL_OPTIONS,
		function(value) local s = currentSpeech(); return s and s.channel == value end,
		function(value)
			local s = currentSpeech()
			if s then
				s.channel = value
				ns.TouchSpeech(s)
				ns.ReloadIfCurrent(s.id)
				ns.RefreshEditorStatus()
				ns.RefreshAll()
			end
		end, 116, 20)
	channelDropdown:SetPoint("RIGHT", delayLabel, "LEFT", -12, 0)
	ns.AttachHookTooltip(channelDropdown, CHANNEL_TIP)
	editor.channelDropdown = channelDropdown

	local tagPicker = ns.CreateButton(header, "v", 20, 20, function(self) showTagMenu(self) end, "Pick from your existing tags.")
	tagPicker:SetPoint("RIGHT", channelDropdown, "LEFT", -10, 0)

	local tagsBox = leftBox(header, 100, 20)
	tagsBox:SetPoint("LEFT", tagsLabel, "RIGHT", 4, 0)
	tagsBox:SetPoint("RIGHT", tagPicker, "LEFT", -4, 0)
	ns.AttachTooltip(tagsBox, "Separate tags with commas, like: Tour, Stormwind, Funny")
	tagsBox:SetScript("OnTextChanged", function(self, userInput)
		if suppressTextEvents or not userInput then
			return
		end
		local s = currentSpeech()
		if s then
			s.tags = ns.ParseTags(self:GetText())
			scheduleSave()
		end
	end)
	editor.tagsBox = tagsBox

	local triggersLabel = ns.CreateLabel(header, "Triggers")
	triggersLabel:SetPoint("TOPLEFT", tagsLabel, "BOTTOMLEFT", 0, -16)
	triggersLabel:SetWidth(LABEL_WIDTH)

	local addTriggerButton = ns.CreateButton(header, "Add Trigger", 92, 20, function(self) showAddTriggerMenu(self) end,
		"Pop up the presenter with this speech when you enter a place or join a group. Several speeches can share a place, one gets picked and the rest are in the presenter's dropdown.")
	addTriggerButton:SetPoint("TOPRIGHT", -10, -60)

	local chipArea = CreateFrame("Frame", nil, header)
	chipArea:SetPoint("TOPLEFT", triggersLabel, "TOPRIGHT", 4, 4)
	chipArea:SetPoint("RIGHT", addTriggerButton, "LEFT", -8, 0)
	chipArea:SetHeight(22)
	chipArea:SetScript("OnSizeChanged", function()
		if currentSpeech() then
			layoutTriggerChips()
		end
	end)
	editor.chipArea = chipArea

	editor.noTriggers = ns.CreateLabel(chipArea, "None. This speech only opens when you pick it.", "GameFontDisableSmall")
	editor.noTriggers:SetPoint("LEFT", 0, -8)

	header:SetHeight(102)

	local scriptTab = ns.CreateButton(body, "Script", 70, 20, function() setPreviewMode(false) end)
	scriptTab:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
	local previewTab = ns.CreateButton(body, "Preview", 70, 20, function() setPreviewMode(true) end,
		"How each line will be sent. Click a line to start presenting from it.")
	previewTab:SetPoint("LEFT", scriptTab, "RIGHT", 4, 0)
	editor.scriptTab, editor.previewTab = scriptTab, previewTab

	local helpButton = ns.CreateButton(body, "?", 20, 20, function() ns.SelectGuideTab() end,
		"Script syntax: /s /y /e /p /ra /rw /i /g /o /w name /1-/9 /gr, any emote like /bow, /wait 5, /pause, ## Section, // note, and tokens like %t and %z. Click for the full guide.")
	helpButton:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -6)

	editor.status = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	editor.status:SetPoint("RIGHT", helpButton, "LEFT", -8, 0)
	editor.status:SetJustifyH("RIGHT")

	local footer = CreateFrame("Frame", nil, body)
	footer:SetHeight(26)
	footer:SetPoint("BOTTOMLEFT", 0, 0)
	footer:SetPoint("BOTTOMRIGHT", 0, 0)

	local presentButton = ns.CreateButton(footer, "Present", 80, 22, function()
		if currentId then
			ns.PresentSpeech(currentId)
		end
	end, "Open this speech in the presenter. Double-clicking it in the list does the same.")
	presentButton:SetPoint("LEFT", 0, 0)

	local playButton = ns.CreateButton(footer, "Auto-Play", 90, 22, function()
		local s = currentSpeech()
		if not s then
			return
		end
		if s.kind == "quip" then
			ns.SendRandomLine(s)
		else
			ns.PresentSpeech(s.id, true)
		end
	end)
	playButton:SetPoint("LEFT", presentButton, "RIGHT", 6, 0)
	editor.playButton = playButton

	local deleteButton = ns.CreateButton(footer, "Delete", 64, 22, function()
		local s = currentSpeech()
		if s then
			StaticPopup_Show("WS_CONFIRM_DELETE_SPEECH", s.name, nil, s.id)
		end
	end)
	deleteButton:SetPoint("RIGHT", 0, 0)

	local exportButton = ns.CreateButton(footer, "Export", 64, 22, function()
		local s = currentSpeech()
		if s then
			ns.ShowExport({ s })
		end
	end, "Get a string you can share, so others can import this speech.")
	exportButton:SetPoint("RIGHT", deleteButton, "LEFT", -6, 0)

	local duplicateButton = ns.CreateButton(footer, "Duplicate", 80, 22, function()
		local copy = currentId and ns.DuplicateSpeech(currentId)
		if copy then
			ns.SelectSpeech(copy.id)
			ns.RefreshAll()
		end
	end)
	duplicateButton:SetPoint("RIGHT", exportButton, "LEFT", -6, 0)

	local scriptHolder = ns.CreateMultiLineEditBox(body)
	scriptHolder:SetPoint("TOPLEFT", scriptTab, "BOTTOMLEFT", 0, -4)
	scriptHolder:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 6)
	scriptHolder.editBox:HookScript("OnTextChanged", function(self, userInput)
		if suppressTextEvents or not userInput then
			return
		end
		local s = currentSpeech()
		if s then
			s.text = self:GetText()
			scheduleSave()
		end
	end)
	scriptHolder.editBox:HookScript("OnEditFocusLost", function()
		if saveTimer then
			saveTimer:Cancel()
			saveTimer = nil
			local s = currentSpeech()
			if s then
				ns.TouchSpeech(s)
				ns.ReloadIfCurrent(s.id)
			end
			ns.RefreshEditorStatus()
			ns.RefreshAll()
		end
	end)
	editor.scriptHolder = scriptHolder
	ns.AttachUndo(scriptHolder.editBox, function(text)
		local s = currentSpeech()
		if s then
			s.text = text
			scheduleSave()
		end
	end)

	local meterTab = CreateFrame("Frame", nil, scriptHolder, "BackdropTemplate")
	meterTab:SetFrameLevel(scriptHolder.scroll:GetFrameLevel() + 5)
	meterTab:SetPoint("BOTTOMRIGHT", scriptHolder, "BOTTOMRIGHT", -28, 5)
	meterTab:SetHeight(18)
	meterTab:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8" })
	meterTab:SetBackdropColor(0.1, 0.07, 0.04, 0.92)
	meterTab:Hide()
	local meter = meterTab:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	meter:SetPoint("RIGHT", -6, 0)
	meter:SetWordWrap(false)
	local rawSetText = meter.SetText
	function meter:SetText(text)
		rawSetText(self, text)
		meterTab:SetShown(text ~= "")
		meterTab:SetWidth(self:GetStringWidth() + 12)
	end
	editor.meter = meter

	local function updateMeter()
		local edit = scriptHolder.editBox
		if not edit:HasFocus() then
			meter:SetText("")
			return
		end
		local text = edit:GetText()
		local before = text:sub(1, edit:GetCursorPosition())
		local lineNo = select(2, before:gsub("\n", "")) + 1
		local lineStart = before:match(".*\n()") or 1
		local lineEnd = text:find("\n", lineStart, true)
		local line = text:sub(lineStart, (lineEnd or #text + 1) - 1)
		local entry = ns.ParseText(line, "SAY").lines[1]
		if not entry or entry.kind ~= "chat" then
			meter:SetText("Line " .. lineNo)
			meter:SetTextColor(0.6, 0.6, 0.6)
			return
		end
		local left = ns.MAX_CHAT_BYTES - #entry.text
		local tokenNote = entry.text:find("%%%a") and " (before tokens)" or ""
		if left >= 0 then
			meter:SetText("Line " .. lineNo .. ": " .. left .. (left == 1 and " character left" or " characters left") .. tokenNote)
			if left <= 30 then
				meter:SetTextColor(1, 0.3, 0.3)
			else
				meter:SetTextColor(1, 1, 1)
			end
		else
			local outcome
			if ns.GetSettings().playback.splitLongLines then
				outcome = "sent as " .. #ns.SplitMessage(entry.text) .. " messages"
			else
				outcome = "the end gets cut off"
			end
			meter:SetText("Line " .. lineNo .. ": " .. -left .. " over, " .. outcome .. tokenNote)
			meter:SetTextColor(1, 0.3, 0.3)
		end
	end
	scriptHolder.editBox:HookScript("OnCursorChanged", updateMeter)
	scriptHolder.editBox:HookScript("OnTextChanged", updateMeter)
	scriptHolder.editBox:HookScript("OnEditFocusGained", updateMeter)
	scriptHolder.editBox:HookScript("OnEditFocusLost", updateMeter)

	local previewHolder = CreateFrame("Frame", nil, body, "BackdropTemplate")
	ns.ApplyPanelBackdrop(previewHolder, 0.85)
	previewHolder:SetBackdropColor(0.04, 0.03, 0.02, 0.95)
	previewHolder:SetAllPoints(scriptHolder)
	local previewScroll = CreateFrame("ScrollFrame", nil, previewHolder, "UIPanelScrollFrameTemplate")
	previewScroll:SetPoint("TOPLEFT", 6, -6)
	previewScroll:SetPoint("BOTTOMRIGHT", -26, 6)
	ns.SetGentleScroll(previewScroll)
	local previewChild = CreateFrame("Frame", nil, previewScroll)
	previewChild:SetSize(100, 1)
	previewScroll:SetScrollChild(previewChild)
	previewScroll:SetScript("OnSizeChanged", function() refreshPreview() end)
	editor.previewHolder, editor.previewScroll, editor.previewChild = previewHolder, previewScroll, previewChild

	setPreviewMode(false)
	ns.LoadEditor(currentId)
end
