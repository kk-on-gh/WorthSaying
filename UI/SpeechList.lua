local ns = WorthSaying

StaticPopupDialogs["WS_CONFIRM_DELETE_SPEECH"] = {
	text = "Delete the speech \"%s\"? This cannot be undone.",
	button1 = "Delete",
	button2 = "Cancel",
	OnAccept = function(_, id)
		ns.DeleteSpeech(id)
		if ns.selectedSpeechId == id then
			ns.SelectSpeech(nil)
		end
		ns.RefreshAll()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:13:13|t"
local STAR_OFF = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:13:13:0:0:64:64:0:64:0:64:70:70:70|t"

local listTable
local filterBar, filterBar2
local search = ""
local favoritesOnly = false
local tagFilter = ns.CreateFilterSet()
local kindFilter = ns.CreateFilterSet()
local triggerFilter = ns.CreateFilterSet()
local tagOptions = {}

local KIND_OPTIONS = {
	{ value = "speech", text = "Speeches" },
	{ value = "quip", text = "Quips" },
}

local TRIGGER_OPTIONS = {
	{ value = "instance", text = "Instance" },
	{ value = "zone", text = "Zone" },
	{ value = "subzone", text = "Subzone" },
	{ value = "group", text = "Group" },
	{ value = "none", text = "No trigger" },
}

local function refillTagOptions()
	wipe(tagOptions)
	for _, tag in ipairs(ns.GetAllTags()) do
		tagOptions[#tagOptions + 1] = { value = tag:lower(), text = tag }
	end
	for value in pairs(tagFilter.selected) do
		local still = false
		for _, option in ipairs(tagOptions) do
			if option.value == value then
				still = true
				break
			end
		end
		if not still then
			tagFilter:Toggle(value)
		end
	end
end

local function matchesSearch(speech)
	if search == "" then
		return true
	end
	local triggerNames = {}
	for _, trigger in ipairs(speech.triggers) do
		triggerNames[#triggerNames + 1] = trigger.name or ""
	end
	local haystack = (speech.name .. "\n" .. table.concat(speech.tags, ",") .. "\n" .. table.concat(triggerNames, "\n")
		.. "\n" .. speech.text):lower()
	for rawTerm in search:gmatch("[^,]+") do
		local term = ns.Trim(rawTerm)
		if term ~= "" and haystack:find(term, 1, true) then
			return true
		end
	end
	return false
end

local function matchesTags(speech)
	if tagFilter.count == 0 then
		return true
	end
	for _, tag in ipairs(speech.tags) do
		if tagFilter.selected[tag:lower()] then
			return true
		end
	end
	return false
end

local function matchesTriggers(speech)
	if triggerFilter.count == 0 then
		return true
	end
	if #speech.triggers == 0 then
		return triggerFilter.selected.none == true
	end
	for _, trigger in ipairs(speech.triggers) do
		if triggerFilter.selected[trigger.type] then
			return true
		end
	end
	return false
end

local function getItems()
	local items = {}
	for _, speech in ipairs(ns.GetAllSpeeches()) do
		if (not favoritesOnly or speech.favorite)
			and kindFilter:Matches(speech.kind)
			and matchesTags(speech)
			and matchesTriggers(speech)
			and matchesSearch(speech) then
			items[#items + 1] = speech
		end
	end
	return items
end

local function sortValue(speech, key)
	if key == "fav" then
		return (speech.favorite and 1 or 0) * 1e6 - (speech.name:lower():byte(1) or 0)
	elseif key == "name" then
		return speech.name:lower()
	elseif key == "kind" then
		return speech.kind
	elseif key == "tags" then
		return table.concat(speech.tags, ", "):lower()
	elseif key == "lines" then
		return ns.GetParsed(speech).sendable
	elseif key == "uses" then
		return speech.uses or 0
	elseif key == "lastUsed" then
		return speech.lastUsed or 0
	elseif key == "modified" then
		return speech.modified or 0
	end
	return 0
end

local function triggerSummary(speech)
	if #speech.triggers == 0 then
		return ""
	end
	return " |cff8fb8ff[" .. #speech.triggers .. (#speech.triggers == 1 and " trigger]|r" or " triggers]|r")
end

local function render(row, speech)
	row.cells.fav:SetText(speech.favorite and STAR or STAR_OFF)
	row.cells.name:SetText(speech.name .. triggerSummary(speech))
	row.cells.name:SetTextColor(1, 1, 1)
	row.cells.kind:SetText(ns.KindLabel(speech.kind))
	if speech.kind == "quip" then
		row.cells.kind:SetTextColor(0.55, 0.9, 0.55)
	else
		row.cells.kind:SetTextColor(0.8, 0.8, 0.8)
	end
	row.cells.tags:SetText(table.concat(speech.tags, ", "))
	row.cells.tags:SetTextColor(1, 0.82, 0.45)
	local parsed = ns.GetParsed(speech)
	local linesText = tostring(parsed.sendable)
	if parsed.errors > 0 or parsed.warnings > 0 then
		linesText = linesText .. " |cffff6060!|r"
	end
	row.cells.lines:SetText(linesText)
	row.cells.uses:SetText(tostring(speech.uses or 0))
	row.cells.lastUsed:SetText(speech.lastUsed and ns.RelativeDate(speech.lastUsed) or "never")
	row.cells.lastUsed:SetTextColor(0.75, 0.75, 0.75)
	row.cells.modified:SetText(speech.modified and ns.FormatDate(speech.modified) or "")
	row.cells.modified:SetTextColor(0.75, 0.75, 0.75)

	if speech.id == ns.selectedSpeechId then
		row.stripe:SetColorTexture(1, 0.82, 0, 0.16)
	else
		row.stripe:SetColorTexture(0, 0, 0, row.stripeAlpha or 0)
	end
end

local COLUMNS = {
	{ key = "fav", label = "", width = 24, min = 22, onCellClick = function(speech)
		speech.favorite = not speech.favorite or nil
		ns.RefreshAll()
	end },
	{ key = "name", label = "Name", width = 160, min = 80, flex = true },
	{ key = "kind", label = "Type", width = 56, min = 40 },
	{ key = "tags", label = "Tags", width = 110, min = 40 },
	{ key = "lines", label = "Lines", width = 46, min = 36 },
	{ key = "uses", label = "Uses", width = 44, min = 36 },
	{ key = "lastUsed", label = "Last Used", width = 90, min = 50 },
	{ key = "modified", label = "Edited", width = 80, min = 50 },
}

function ns.SelectSpeech(id)
	ns.selectedSpeechId = id
	if ns.LoadEditor then
		ns.LoadEditor(id)
	end
	if listTable then
		listTable.Refresh()
	end
end

function ns.PresentSpeech(id, play)
	ns.LoadSpeech(id, {})
	ns.ShowPresenter()
	if play then
		ns.Play()
	end
end

local function exportOne(speech)
	ns.ShowExport({ speech })
end

local function showRowMenu(speech, rowFrame)
	MenuUtil.CreateContextMenu(rowFrame, function(_, root)
		root:CreateTitle(speech.name)
		root:CreateButton("Open in Presenter", function() ns.PresentSpeech(speech.id) end)
		if speech.kind ~= "quip" then
			root:CreateButton("Present and Auto-Play", function() ns.PresentSpeech(speech.id, true) end)
		else
			root:CreateButton("Send a Random Line", function() ns.SendRandomLine(speech) end)
		end
		root:CreateDivider()
		root:CreateButton(speech.favorite and "Remove Favorite" or "Mark as Favorite", function()
			speech.favorite = not speech.favorite or nil
			ns.RefreshAll()
		end)
		root:CreateButton("Duplicate", function()
			local copy = ns.DuplicateSpeech(speech.id)
			if copy then
				ns.SelectSpeech(copy.id)
				ns.RefreshAll()
			end
		end)
		root:CreateButton("Export", function() exportOne(speech) end)
		root:CreateDivider()
		root:CreateButton("|cffff6060Delete|r", function()
			StaticPopup_Show("WS_CONFIRM_DELETE_SPEECH", speech.name, nil, speech.id)
		end)
	end)
end

local lastClickId, lastClickAt = nil, 0

local function onRowClick(speech)
	local now = GetTime()
	if lastClickId == speech.id and now - lastClickAt < 0.35 then
		lastClickId = nil
		ns.PresentSpeech(speech.id)
		return
	end
	lastClickId, lastClickAt = speech.id, now
	ns.SelectSpeech(speech.id)
end

local function resetFilters()
	search = ""
	favoritesOnly = false
	tagFilter:Clear()
	kindFilter:Clear()
	triggerFilter:Clear()
	if filterBar.searchBox then
		filterBar.searchBox:SetText("")
	end
	for _, dd in ipairs(filterBar.dropdowns) do
		dd.RefreshText()
	end
	for _, dd in ipairs(filterBar2.dropdowns) do
		dd.RefreshText()
	end
	if filterBar2.checkbox then
		filterBar2.checkbox:SetChecked(false)
	end
end

function ns.CreateNewSpeech(kind)
	local speech = ns.CreateSpeech({
		name = kind == "quip" and "New Quip" or "New Speech",
		kind = kind,
		text = "",
	})
	ns.SelectSpeech(speech.id)
	ns.RefreshAll()
	if ns.FocusEditorName then
		ns.FocusEditorName()
	end
	return speech
end

function ns.BuildSpeechList(parent)
	refillTagOptions()

	filterBar = ns.CreateFilterBar(parent, {
		search = { onChange = function(text) search = text; ns.RefreshSpeechList() end },
		dropdowns = {
			{
				multi = true,
				options = tagOptions,
				isSelected = function(value) return tagFilter.selected[value] == true end,
				toggle = function(value) tagFilter:Toggle(value); ns.RefreshSpeechList() end,
				getSummaryText = function() return tagFilter:SummaryText(tagOptions, "All tags") end,
				clearText = "All tags",
				onClear = function() tagFilter:Clear(); ns.RefreshSpeechList() end,
				width = 150,
			},
		},
	})
	filterBar:SetPoint("TOPLEFT", 0, 0)
	filterBar:SetPoint("TOPRIGHT", 0, 0)

	filterBar2 = ns.CreateFilterBar(parent, {
		items = {
			{
				type = "dropdown",
				multi = true,
				options = KIND_OPTIONS,
				isSelected = function(value) return kindFilter.selected[value] == true end,
				toggle = function(value) kindFilter:Toggle(value); ns.RefreshSpeechList() end,
				getSummaryText = function() return kindFilter:SummaryText(KIND_OPTIONS, "All types") end,
				clearText = "All types",
				onClear = function() kindFilter:Clear(); ns.RefreshSpeechList() end,
				width = 110,
			},
			{
				type = "dropdown",
				multi = true,
				options = TRIGGER_OPTIONS,
				isSelected = function(value) return triggerFilter.selected[value] == true end,
				toggle = function(value) triggerFilter:Toggle(value); ns.RefreshSpeechList() end,
				getSummaryText = function() return triggerFilter:SummaryText(TRIGGER_OPTIONS, "Any trigger") end,
				clearText = "Any trigger",
				onClear = function() triggerFilter:Clear(); ns.RefreshSpeechList() end,
				width = 120,
			},
			{
				type = "checkbox",
				label = "Favorites",
				initial = false,
				onChange = function(checked) favoritesOnly = checked; ns.RefreshSpeechList() end,
			},
		},
		actionButton = { text = "Clear", width = 56, onClick = function()
			resetFilters()
			ns.RefreshSpeechList()
		end },
	})
	filterBar2:SetPoint("TOPLEFT", 0, -30)
	filterBar2:SetPoint("TOPRIGHT", 0, -30)

	local bottomBar = CreateFrame("Frame", nil, parent)
	bottomBar:SetHeight(26)
	bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
	bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)

	local newButton = ns.CreateButton(bottomBar, "New Speech", 96, 22, function() ns.CreateNewSpeech("speech") end,
		"A speech is sent line by line, in order.")
	newButton:SetPoint("LEFT", 0, 0)
	local newQuipButton = ns.CreateButton(bottomBar, "New Quip", 80, 22, function() ns.CreateNewSpeech("quip") end,
		"A quip sends one random line each time. Good for greetings, pull lines and one-liners.")
	newQuipButton:SetPoint("LEFT", newButton, "RIGHT", 6, 0)
	local exportButton = ns.CreateButton(bottomBar, "Export Shown", 100, 22, function()
		local items = getItems()
		if #items == 0 then
			ns.Print("Nothing to export: no speeches match the current filters.")
			return
		end
		ns.ShowExport(items)
	end, "Export every speech currently listed (after filters) as one string.")
	exportButton:SetPoint("RIGHT", 0, 0)
	local importButton = ns.CreateButton(bottomBar, "Import", 70, 22, function() ns.ShowImport() end,
		"Paste a Worth Saying export string to add its speeches.")
	importButton:SetPoint("RIGHT", exportButton, "LEFT", -6, 0)

	listTable = ns.CreateSortableTable(parent, {
		tableId = "speeches",
		columns = COLUMNS,
		rowHeight = 22,
		getItems = getItems,
		sortValue = sortValue,
		render = render,
		onClick = onRowClick,
		onRightClick = showRowMenu,
		defaultSort = { key = "name", dir = "asc" },
		pageSize = "auto",
	})
	listTable.container:SetPoint("TOPLEFT", 0, -62)
	listTable.container:SetPoint("BOTTOMRIGHT", bottomBar, "TOPRIGHT", 0, 4)
end

function ns.RefreshSpeechList()
	if not listTable then
		return
	end
	refillTagOptions()
	if not ns.IsSpeechesTabVisible() then
		return
	end
	listTable.Refresh()
	local shown = listTable.GetItemCount()
	filterBar.countLabel:SetText(shown .. " shown")
end

function ns.FilterByTag(tag)
	tagFilter:Set(tag:lower())
	if filterBar then
		filterBar.dropdowns[1].RefreshText()
	end
	ns.SelectSpeechesTab()
	ns.RefreshSpeechList()
end
