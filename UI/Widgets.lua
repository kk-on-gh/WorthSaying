local ns = WorthSaying

-- frames the tour points at, filled in as each panel builds (UI/Tour.lua)
ns.tourTargets = {}
-- Options section boxes by title
ns.tourBoxes = {}

-- target: a frame, { topLeftFrame, bottomRightFrame }, or a function returning either
function ns.RegisterTourTarget(name, target)
	ns.tourTargets[name] = target
end

-- options may be a function, rebuilt each time the menu opens
function ns.CreateDropdown(parent, options, isSelected, onChange, width, height)
	local function getOptions()
		return type(options) == "function" and options() or options
	end
	local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")

	if ok and dropdown and dropdown.SetupMenu then
		dropdown:SetupMenu(function(_, rootDescription)
			for _, option in ipairs(getOptions()) do
				rootDescription:CreateRadio(option.text, function() return isSelected(option.value) end, function()
					dropdown:SetText(option.text)
					onChange(option.value, option.text)
				end)
			end
		end)
	else
		dropdown = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		dropdown:SetScript("OnClick", function(self)
			local opts = getOptions()
			local currentIndex = 1
			for i, option in ipairs(opts) do
				if isSelected(option.value) then
					currentIndex = i
					break
				end
			end
			local option = opts[(currentIndex % #opts) + 1]
			self:SetText(option.text)
			onChange(option.value, option.text)
		end)
	end

	function dropdown:Refresh()
		for _, option in ipairs(getOptions()) do
			if isSelected(option.value) then
				self:SetText(option.text)
				return
			end
		end
	end
	dropdown:Refresh()

	dropdown:SetSize(width or 150, height or 22)

	return dropdown
end

local SMALL_BACKDROP = {
	bgFile = "Interface/Buttons/WHITE8X8",
	edgeFile = "Interface/Buttons/WHITE8X8",
	edgeSize = 1,
}

local BORDER_PIECES = {
	"TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
	"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
}

local function applySmallBackdrop(frame)
	frame:SetBackdrop(SMALL_BACKDROP)
	frame:SetBackdropColor(0.08, 0.06, 0.03, 0.9)
	frame:SetBackdropBorderColor(1, 0.82, 0, 0.5)
	for _, pieceName in ipairs(BORDER_PIECES) do
		local piece = frame[pieceName]
		if piece and piece.SetSnapToPixelGrid then
			piece:SetSnapToPixelGrid(false)
			piece:SetTexelSnappingBias(0)
		end
	end
end

local smallTooltip
local SMALL_TOOLTIP_MAX_WIDTH = 260

local function getSmallTooltip()
	if not smallTooltip then
		smallTooltip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		smallTooltip:SetFrameStrata("TOOLTIP")
		smallTooltip:SetBackdrop(SMALL_BACKDROP)
		smallTooltip:SetBackdropColor(0.04, 0.03, 0.02, 1)
		smallTooltip:SetBackdropBorderColor(1, 0.82, 0, 0.6)
		smallTooltip.text = smallTooltip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		smallTooltip.text:SetPoint("TOPLEFT", 6, -5)
		smallTooltip.text:SetJustifyH("LEFT")
		smallTooltip.text:SetJustifyV("TOP")
	end
	return smallTooltip
end

-- text may be a function, resolved on every hover
local function showSmallTooltip(owner, text)
	local tip = getSmallTooltip()
	tip.owner, tip.source = owner, text
	if type(text) == "function" then
		text = text()
	end
	tip.text:SetWidth(0)
	tip.text:SetText(text)
	local width = math.min(SMALL_TOOLTIP_MAX_WIDTH, tip.text:GetStringWidth())
	tip.text:SetWidth(width)
	tip:SetWidth(width + 12)
	tip:SetHeight(tip.text:GetStringHeight() + 10)
	tip:ClearAllPoints()
	tip:SetPoint("BOTTOM", owner, "TOP", 0, 4)
	tip:Show()
end

local function hideSmallTooltip()
	if smallTooltip then
		smallTooltip:Hide()
	end
end

-- redraws an open tooltip, for text that changed while hovered
function ns.RefreshTooltipFor(owner)
	if smallTooltip and smallTooltip:IsShown() and smallTooltip.owner == owner then
		showSmallTooltip(owner, smallTooltip.source)
	end
end

function ns.AttachTooltip(frame, text)
	frame:SetScript("OnEnter", function(self) showSmallTooltip(self, text) end)
	frame:SetScript("OnLeave", hideSmallTooltip)
end

function ns.AttachHookTooltip(frame, text)
	frame:HookScript("OnEnter", function(self) showSmallTooltip(self, text) end)
	frame:HookScript("OnLeave", hideSmallTooltip)
end

function ns.CreateSmallCheckbox(parent, size, checked, onClick)
	size = size or 16
	local btn = CreateFrame("CheckButton", nil, parent)
	btn:SetSize(size, size)
	btn:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	btn:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	btn:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
	btn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	btn:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	btn:SetChecked(checked)
	btn:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
	end)

	return btn
end

function ns.CreateSmallEditBox(parent, width, height, numeric)
	local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	box:SetSize(width, height or 16)
	applySmallBackdrop(box)
	box:SetAutoFocus(false)
	box:SetFontObject(GameFontHighlightSmall)
	box:SetJustifyH("CENTER")
	box:SetTextInsets(2, 2, 0, 0)
	if numeric then
		box:SetNumeric(true)
	end

	local setScript = box.SetScript
	function box:SetScript(scriptName, handler)
		if scriptName == "OnEditFocusLost" then
			local callerHandler = handler
			handler = function(self, ...)
				self:HighlightText(0, 0)
				if callerHandler then
					return callerHandler(self, ...)
				end
			end
		end
		return setScript(self, scriptName, handler)
	end
	box:SetScript("OnEditFocusLost", nil)

	local lastClickAt = 0
	box:HookScript("OnMouseUp", function(self)
		local now = GetTime()
		if now - lastClickAt < 0.35 then
			self:HighlightText()
			lastClickAt = 0
		else
			lastClickAt = now
		end
	end)

	return box
end

function ns.CreateSmallSlider(parent, width, min, max, step, getValue, setValue)
	local slider = CreateFrame("Slider", nil, parent)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(width, 12)
	slider:SetMinMaxValues(min, max)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	slider:EnableMouse(true)

	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT", 0, 0)
	track:SetPoint("RIGHT", 0, 0)
	track:SetHeight(2)
	track:SetColorTexture(1, 0.82, 0, 0.35)

	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(8, 12)
	thumb:SetColorTexture(1, 0.82, 0, 1)
	slider:SetThumbTexture(thumb)

	slider:SetValue(getValue())
	slider:SetScript("OnValueChanged", function(self, value)
		setValue(value)
	end)

	return slider
end

local function setDropdownDisplayText(dropdown, text)
	dropdown:SetText(text)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(text)
	end
end

function ns.CreateFilterSet()
	local set = { selected = {}, count = 0 }

	function set:Toggle(value)
		if self.selected[value] then
			self.selected[value] = nil
			self.count = self.count - 1
		else
			self.selected[value] = true
			self.count = self.count + 1
		end
	end

	function set:Set(value)
		wipe(self.selected)
		self.selected[value] = true
		self.count = 1
	end

	function set:Clear()
		wipe(self.selected)
		self.count = 0
	end

	function set:Matches(value)
		return self.count == 0 or self.selected[value] == true
	end

	function set:SummaryText(options, allLabel)
		if self.count == 0 then
			return allLabel
		end
		local names = {}
		for _, option in ipairs(options) do
			if self.selected[option.value] then
				names[#names + 1] = option.text
			end
		end
		return table.concat(names, ", ")
	end

	return set
end

function ns.CreateMultiSelectDropdown(parent, options, isSelected, toggle, getSummaryText, width, clearText, onClear)
	local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")

	local function refreshDisplayText()
		setDropdownDisplayText(dropdown, getSummaryText())
		C_Timer.After(0, function()
			setDropdownDisplayText(dropdown, getSummaryText())
		end)
	end

	if ok and dropdown and dropdown.SetupMenu then
		dropdown:SetupMenu(function(_, rootDescription)
			if clearText then
				local text = type(clearText) == "function" and clearText() or clearText
				rootDescription:CreateButton(text, function()
					onClear()
					refreshDisplayText()
				end)
				rootDescription:CreateDivider()
			end
			for _, option in ipairs(options) do
				rootDescription:CreateCheckbox(option.text, function() return isSelected(option.value) end, function()
					toggle(option.value)
					refreshDisplayText()
				end)
			end
		end)
	else
		dropdown = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		dropdown:SetScript("OnClick", function(self)
			local currentIndex = 0
			for i, option in ipairs(options) do
				if isSelected(option.value) then
					currentIndex = i
					break
				end
			end
			local option = options[(currentIndex % #options) + 1]
			toggle(option.value)
			self:SetText(getSummaryText())
		end)
	end

	refreshDisplayText()
	dropdown:HookScript("OnShow", refreshDisplayText)
	dropdown.RefreshText = refreshDisplayText
	dropdown:SetSize(width or 180, 22)
	return dropdown
end

function ns.CreateFilterBar(parent, config)
	local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	bar:SetHeight(28)
	ns.ApplyPanelBackdrop(bar, 0.75)

	local prevWidget
	bar.dropdowns = {}

	if config.search then
		local searchBox = CreateFrame("EditBox", nil, bar, "SearchBoxTemplate")
		searchBox:SetSize(150, 20)
		searchBox:SetPoint("LEFT", 8, 0)
		searchBox:HookScript("OnTextChanged", function(self)
			config.search.onChange(self:GetText():lower())
		end)
		prevWidget = searchBox
		bar.searchBox = searchBox
	end

	bar.checkboxes = {}

	local function addDropdown(dc)
		local dropdown
		if dc.multi then
			dropdown = ns.CreateMultiSelectDropdown(bar, dc.options, dc.isSelected, dc.toggle, dc.getSummaryText, dc.width, dc.clearText, dc.onClear)
		else
			dropdown = ns.CreateDropdown(bar, dc.options, dc.isSelected, dc.onChange, dc.width)
		end
		dropdown:SetPoint("LEFT", prevWidget or bar, prevWidget and "RIGHT" or "LEFT", prevWidget and 10 or 8, 0)
		prevWidget = dropdown
		bar.dropdowns[#bar.dropdowns + 1] = dropdown
	end

	local function addCheckbox(cc)
		local check = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
		check:SetSize(20, 20)
		check:SetChecked(cc.initial)
		check:SetPoint("LEFT", prevWidget or bar, prevWidget and "RIGHT" or "LEFT", prevWidget and 6 or 8, 0)
		check:SetScript("OnClick", function(self)
			cc.onChange(self:GetChecked() and true or false)
		end)

		local label = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("LEFT", check, "RIGHT", 2, 0)
		label:SetText(cc.label)
		prevWidget = label
		bar.checkboxes[#bar.checkboxes + 1] = check
	end

	if config.items then
		for _, item in ipairs(config.items) do
			if item.type == "checkbox" then
				addCheckbox(item)
			else
				addDropdown(item)
			end
		end
	else
		local dropdownConfigs = config.dropdowns or (config.dropdown and { config.dropdown })
		if dropdownConfigs then
			for _, dc in ipairs(dropdownConfigs) do
				addDropdown(dc)
			end
		end

		local checkboxConfigs = config.checkboxes or (config.checkbox and { config.checkbox })
		if checkboxConfigs then
			for _, cc in ipairs(checkboxConfigs) do
				addCheckbox(cc)
			end
		end
	end
	bar.checkbox = bar.checkboxes[1]

	if config.actionButton then
		local btn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
		btn:SetSize(config.actionButton.width or 80, 20)
		btn:SetPoint("RIGHT", -8, 0)
		btn:SetText(config.actionButton.text)
		btn:SetScript("OnClick", config.actionButton.onClick)
		bar.actionButton = btn
	end

	if config.rightCheckbox then
		local rc = config.rightCheckbox
		local label = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("RIGHT", -8, 0)
		label:SetText(rc.label)
		local check = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
		check:SetSize(20, 20)
		check:SetChecked(rc.initial)
		check:SetPoint("RIGHT", label, "LEFT", -2, 0)
		check:SetScript("OnClick", function(self)
			rc.onChange(self:GetChecked() and true or false)
		end)
		if rc.tooltip then
			ns.AttachHookTooltip(check, rc.tooltip)
		end
		bar.rightCheckbox = check
	end

	bar.countLabel = bar:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	if bar.actionButton then
		bar.countLabel:SetPoint("RIGHT", bar.actionButton, "LEFT", -10, 0)
	elseif bar.rightCheckbox then
		bar.countLabel:SetPoint("RIGHT", bar.rightCheckbox, "LEFT", -10, 0)
	else
		bar.countLabel:SetPoint("RIGHT", -8, 0)
	end

	return bar
end

function ns.ColumnLabel(col)
	if type(col.label) == "function" then
		return col.label()
	end
	return col.label
end

function ns.CreateSortableTable(parent, config)
	local HANDLE_WIDTH = 6
	local columns = config.columns
	local flexKey = columns[#columns].key
	for _, col in ipairs(columns) do
		if col.flex then
			flexKey = col.key
		end
	end

	local function isHideable(key)
		return key ~= columns[1].key
	end

	local function isColumnVisible(key)
		for _, col in ipairs(columns) do
			if col.key == key then
				if col.isVisible then
					return col.isVisible()
				end
				break
			end
		end
		if not config.tableId or not isHideable(key) then
			return true
		end
		local vis = ns.GetSettings().columnVisibility[config.tableId]
		return not (vis and vis[key] == false)
	end

	local function resolveMin(col)
		if type(col.min) == "function" then
			return col.min()
		end
		return col.min or 30
	end

	if config.tableId then
		local saved = ns.GetSettings().columnWidths[config.tableId]
		if saved then
			for _, col in ipairs(columns) do
				if col.key ~= flexKey and saved[col.key] then
					col.width = math.max(resolveMin(col), saved[col.key])
				end
			end
		end
	end
	local ordered = {}
	do
		local byKey, used = {}, {}
		for _, col in ipairs(columns) do
			byKey[col.key] = col
		end
		local saved = config.tableId and ns.GetSettings().columnOrder[config.tableId]
		if saved then
			for _, key in ipairs(saved) do
				if byKey[key] and not used[key] then
					used[key] = true
					ordered[#ordered + 1] = byKey[key]
				end
			end
		end
		for i, col in ipairs(columns) do
			if not used[col.key] then
				used[col.key] = true
				local insertAt = 1
				local previous = columns[i - 1]
				for j, existing in ipairs(ordered) do
					if previous and existing.key == previous.key then
						insertAt = j + 1
						break
					end
				end
				table.insert(ordered, insertAt, col)
			end
		end
	end

	local function saveOrder()
		if not config.tableId then
			return
		end
		local keys = {}
		for i, col in ipairs(ordered) do
			keys[i] = col.key
		end
		ns.GetSettings().columnOrder[config.tableId] = keys
	end

	local function columnAfterFlex()
		local passedFlex = false
		for _, col in ipairs(ordered) do
			if col.key == flexKey then
				passedFlex = true
			elseif passedFlex and isColumnVisible(col.key) then
				return col
			end
		end
	end

	local sortKey = config.defaultSort and config.defaultSort.key or columns[1].key
	local sortDir = config.defaultSort and config.defaultSort.dir or "desc"
	local autoPageSize = config.pageSize == "auto"
	local pageSize = config.pageSize
	local currentPage = 1
	local totalPages = 1

	local container = CreateFrame("Frame", nil, parent)

	local scrollbarInset = autoPageSize and 0 or 22

	local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", -scrollbarInset, 0)
	header:SetHeight(20)
	header:SetClipsChildren(true)
	header:SetBackdrop({
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	header:SetBackdropBorderColor(1, 0.82, 0, 0.5)
	local headerFill = header:CreateTexture(nil, "BACKGROUND")
	headerFill:SetAllPoints()
	headerFill:SetColorTexture(0.32, 0.22, 0.09, 1)

	local PAGE_BAR_HEIGHT = 26
	local pageBar, pageLabel, prevButton, nextButton
	if pageSize then
		pageBar = CreateFrame("Frame", nil, container)
		pageBar:SetHeight(PAGE_BAR_HEIGHT)
		pageBar:SetPoint("BOTTOMLEFT", 0, 0)
		pageBar:SetPoint("BOTTOMRIGHT", 0, 0)

		prevButton = CreateFrame("Button", nil, pageBar, "UIPanelButtonTemplate")
		prevButton:SetSize(70, 20)
		prevButton:SetText("< Prev")
		prevButton:SetPoint("LEFT", 2, 0)

		nextButton = CreateFrame("Button", nil, pageBar, "UIPanelButtonTemplate")
		nextButton:SetSize(70, 20)
		nextButton:SetText("Next >")
		nextButton:SetPoint("RIGHT", -24, 0)

		pageLabel = pageBar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		pageLabel:SetPoint("CENTER", 0, 0)
	end

	local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")

	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", 0, -24)
	scroll:SetPoint("BOTTOMRIGHT", -scrollbarInset, pageSize and PAGE_BAR_HEIGHT or 0)
	local scrollChild = CreateFrame("Frame", nil, scroll)
	scrollChild:SetSize(1, 1)

	if autoPageSize then
		if scroll.ScrollBar then
			scroll.ScrollBar:Hide()
			scroll.ScrollBar:HookScript("OnShow", function(self) self:Hide() end)
		end
	else
		local scrollDivider = container:CreateTexture(nil, "ARTWORK")
		scrollDivider:SetWidth(1)
		scrollDivider:SetColorTexture(1, 0.82, 0, 0.3)
		if scroll.ScrollBar then
			scrollDivider:SetPoint("TOP", scroll.ScrollBar, "TOP", 0, 0)
			scrollDivider:SetPoint("BOTTOM", scroll.ScrollBar, "BOTTOM", 0, 0)
			scrollDivider:SetPoint("RIGHT", scroll.ScrollBar, "LEFT", -4, 0)
		else
			scrollDivider:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -24)
			scrollDivider:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -22, 0)
		end
	end
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width) scrollChild:SetWidth(width) end)
	scrollChild:SetWidth(scroll:GetWidth())

	local headerCells, headerLabels, headerArrows, headerHandles = {}, {}, {}, {}
	local startColumnDrag, finishColumnDrag
	local suppressHeaderClick = false
	local rows = {}
	local items = {}

	local FLEX_MIN_WIDTH = 40

	local function relayout()
		local trailing = 0
		do
			local passedFlex = false
			for _, col in ipairs(ordered) do
				if col.key == flexKey then
					passedFlex = true
				elseif passedFlex and isColumnVisible(col.key) then
					trailing = trailing + col.width
				end
			end
		end

		local availableWidth = header:GetWidth()
		local x = 4
		for _, col in ipairs(ordered) do
			local isFlex = col.key == flexKey
			local cell = headerCells[col.key]
			local handle = headerHandles[col.key]

			if not isColumnVisible(col.key) then
				cell:Hide()
				if handle then
					handle:Hide()
				end
				for _, row in ipairs(rows) do
					row.cells[col.key]:Hide()
					if row.cellButtons and row.cellButtons[col.key] then
						row.cellButtons[col.key]:Hide()
					end
				end
			else
				local width = isFlex and math.max(FLEX_MIN_WIDTH, availableWidth - x - trailing) or (col.width - 6)
				local offScreen = x >= availableWidth

				cell:SetShown(not offScreen)
				cell:ClearAllPoints()
				cell:SetPoint("LEFT", header, "LEFT", x, 0)
				cell:SetWidth(width)

				if handle then
					local handleOffScreen = (x + width + 6 + HANDLE_WIDTH / 2) > availableWidth
					handle:SetShown(not handleOffScreen and not (isFlex and not columnAfterFlex()))
					handle:ClearAllPoints()
					handle:SetPoint("LEFT", cell, "RIGHT", 6 - HANDLE_WIDTH / 2, 0)
				end

				for _, row in ipairs(rows) do
					local rc = row.cells[col.key]
					rc:Show()
					if row.cellButtons and row.cellButtons[col.key] then
						row.cellButtons[col.key]:Show()
					end
					rc:ClearAllPoints()
					rc:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
					rc:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, 0)
					rc:SetWidth(width)
				end

				x = x + (isFlex and (width + 6) or col.width)
			end
		end
	end

	local function computeAutoPageSize()
		return math.max(1, math.floor(scroll:GetHeight() / config.rowHeight))
	end

	local function updateArrows()
		for _, col in ipairs(columns) do
			local active = col.key == sortKey
			local label = headerLabels[col.key]
			label:SetText(ns.ColumnLabel(col))
			if active then
				label:SetTextColor(1, 1, 1)
			else
				label:SetTextColor(1, 0.82, 0)
			end

			local arrowIcon = headerArrows[col.key]
			if arrowIcon then
				arrowIcon:SetShown(active)
				if active then
					arrowIcon:SetTexture(sortDir == "desc" and "Interface/Buttons/Arrow-Down-Up" or "Interface/Buttons/Arrow-Up-Up")
				end
			end
		end
	end

	local function refresh()
		items = config.getItems()
		local sortValues = {}
		for _, item in ipairs(items) do
			sortValues[item] = config.sortValue(item, sortKey)
		end
		local ascending = sortDir == "asc"
		table.sort(items, function(a, b)
			local av, bv = sortValues[a], sortValues[b]
			if av == bv then
				return false
			elseif ascending then
				return av < bv
			end
			return av > bv
		end)

		if autoPageSize then
			pageSize = computeAutoPageSize()
		end

		local pageItems = items
		if pageSize then
			totalPages = math.max(1, math.ceil(#items / pageSize))
			currentPage = math.max(1, math.min(currentPage, totalPages))
			pageItems = {}
			local startIndex = (currentPage - 1) * pageSize + 1
			for i = startIndex, math.min(#items, startIndex + pageSize - 1) do
				pageItems[#pageItems + 1] = items[i]
			end
			pageLabel:SetText(("Page %d / %d"):format(currentPage, totalPages))
			prevButton:SetEnabled(currentPage > 1)
			nextButton:SetEnabled(currentPage < totalPages)
		end

		for i = #rows + 1, #pageItems do
			local row = CreateFrame((config.onClick or config.onRightClick) and "Button" or "Frame", nil, scrollChild)
			row:SetHeight(config.rowHeight)
			row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * config.rowHeight)
			row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

			row.stripe = row:CreateTexture(nil, "BACKGROUND", nil, -1)
			row.stripe:SetAllPoints()
			row.stripeAlpha = i % 2 == 0 and 0.18 or 0
			row.stripe:SetColorTexture(0, 0, 0, row.stripeAlpha)

			row.cells = {}
			row.cellButtons = {}

			local rowHighlight

			for _, col in ipairs(columns) do
				local cell
				if col.cellType == "checkbox" then
					cell = CreateFrame("Frame", nil, row)
					local check = CreateFrame("CheckButton", nil, cell, "UICheckButtonTemplate")
					check:SetSize(18, 18)
					check:SetPoint("LEFT", 0, 0)
					check:SetScript("OnClick", function(self)
						if col.onCheckboxClick then
							col.onCheckboxClick(row.item, self:GetChecked() and true or false)
						end
					end)
					cell.checkbox = check
				else
					cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
					cell:SetJustifyH("LEFT")
					cell:SetJustifyV("MIDDLE")
					cell:SetWordWrap(true)
					cell:SetMaxLines(1)
				end
				row.cells[col.key] = cell

				if col.onCellClick then
					local cellButton = CreateFrame("Button", nil, row)
					cellButton:SetAllPoints(cell)
					cellButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
					cellButton:SetScript("OnClick", function(self, button)
						if button == "RightButton" then
							if config.onRightClick then
								config.onRightClick(row.item, row)
							end
						else
							col.onCellClick(row.item)
						end
					end)
					cellButton:SetScript("OnEnter", function()
						if rowHighlight then
							rowHighlight:Show()
						end
					end)
					cellButton:SetScript("OnLeave", function()
						if rowHighlight then
							rowHighlight:Hide()
						end
					end)
					row.cellButtons[col.key] = cellButton
				end
			end

			if config.onClick or config.onRightClick then
				local clicks = {}
				if config.onClick then
					clicks[#clicks + 1] = "LeftButtonUp"
				end
				if config.onRightClick then
					clicks[#clicks + 1] = "RightButtonUp"
				end
				row:RegisterForClicks(unpack(clicks))
				row:SetScript("OnClick", function(self, button)
					if button == "RightButton" and config.onRightClick then
						config.onRightClick(self.item, self)
					elseif config.onClick then
						config.onClick(self.item, self)
					end
				end)
				rowHighlight = row:CreateTexture(nil, "ARTWORK")
				rowHighlight:SetAllPoints()
				rowHighlight:SetColorTexture(1, 1, 1, 0.08)
				rowHighlight:Hide()
				row:SetScript("OnEnter", function() rowHighlight:Show() end)
				row:SetScript("OnLeave", function() rowHighlight:Hide() end)
			end

			rows[i] = row
		end

		relayout()
		updateArrows()

		for i, row in ipairs(rows) do
			local item = pageItems[i]
			if item then
				row.item = item
				config.render(row, item)
				row:Show()
			else
				row:Hide()
			end
		end

		scrollChild:SetHeight(math.max(1, #pageItems * config.rowHeight))
	end

	local lastAutoPageSize
	local autoPageSizeTimer
	container:SetScript("OnSizeChanged", function()
		relayout()
		if not autoPageSize then
			return
		end
		if autoPageSizeTimer then
			autoPageSizeTimer:Cancel()
		end
		autoPageSizeTimer = C_Timer.NewTimer(0.2, function()
			autoPageSizeTimer = nil
			local newSize = computeAutoPageSize()
			if newSize ~= lastAutoPageSize then
				lastAutoPageSize = newSize
				refresh()
			end
		end)
	end)

	if pageSize then
		prevButton:SetScript("OnClick", function()
			currentPage = math.max(1, currentPage - 1)
			refresh()
		end)
		nextButton:SetScript("OnClick", function()
			currentPage = currentPage + 1
			refresh()
		end)
	end

	local function createResizeHandle(ownerKey, getTargetCol, invert)
		local handle = CreateFrame("Button", nil, header)
		handle:SetSize(HANDLE_WIDTH, 18)
		handle:EnableMouse(true)
		local divider = handle:CreateTexture(nil, "ARTWORK")
		divider:SetPoint("TOP", 0, 0)
		divider:SetPoint("BOTTOM", 0, 0)
		divider:SetWidth(1)
		divider:SetColorTexture(1, 0.82, 0, 0.3)
		local hoverHighlight = handle:CreateTexture(nil, "ARTWORK")
		hoverHighlight:SetAllPoints()
		hoverHighlight:SetColorTexture(1, 0.82, 0, 0.6)
		hoverHighlight:Hide()
		handle:SetScript("OnEnter", function() hoverHighlight:Show() end)
		handle:SetScript("OnLeave", function() hoverHighlight:Hide() end)
		local targetCol
		handle:SetScript("OnMouseDown", function()
			targetCol = getTargetCol()
			if not targetCol then
				return
			end
			local startX = GetCursorPosition()
			local startWidth = targetCol.width
			handle:SetScript("OnUpdate", function()
				local scale = UIParent:GetEffectiveScale()
				local dx = (GetCursorPosition() - startX) / scale
				targetCol.width = math.max(resolveMin(targetCol), startWidth + (invert and -dx or dx))
				relayout()
			end)
		end)
		handle:SetScript("OnMouseUp", function()
			handle:SetScript("OnUpdate", nil)
			if targetCol and config.tableId then
				local widths = ns.GetSettings().columnWidths
				widths[config.tableId] = widths[config.tableId] or {}
				widths[config.tableId][targetCol.key] = targetCol.width
			end
		end)
		headerHandles[ownerKey] = handle
	end

	local dragOverlay = CreateFrame("Frame", nil, container)
	dragOverlay:SetFrameLevel(container:GetFrameLevel() + 20)
	dragOverlay:EnableMouse(false)
	local dragOverlayFill = dragOverlay:CreateTexture(nil, "OVERLAY")
	dragOverlayFill:SetAllPoints()
	dragOverlayFill:SetColorTexture(1, 0.82, 0, 0.14)
	local dragOverlayEdgeL = dragOverlay:CreateTexture(nil, "OVERLAY")
	dragOverlayEdgeL:SetPoint("TOPLEFT")
	dragOverlayEdgeL:SetPoint("BOTTOMLEFT")
	dragOverlayEdgeL:SetWidth(1)
	dragOverlayEdgeL:SetColorTexture(1, 0.82, 0, 0.8)
	local dragOverlayEdgeR = dragOverlay:CreateTexture(nil, "OVERLAY")
	dragOverlayEdgeR:SetPoint("TOPRIGHT")
	dragOverlayEdgeR:SetPoint("BOTTOMRIGHT")
	dragOverlayEdgeR:SetWidth(1)
	dragOverlayEdgeR:SetColorTexture(1, 0.82, 0, 0.8)
	dragOverlay:Hide()

	local draggingCol

	local function cursorX()
		return GetCursorPosition() / header:GetEffectiveScale()
	end

	local function indexOf(col)
		for i, c in ipairs(ordered) do
			if c == col then
				return i
			end
		end
	end

	local function visibleNeighbor(i, step)
		local j = i + step
		while ordered[j] do
			local c = ordered[j]
			if isColumnVisible(c.key) and headerCells[c.key]:IsShown() then
				return j, c
			end
			j = j + step
		end
	end

	local function midpoint(col)
		local cell = headerCells[col.key]
		return (cell:GetLeft() + cell:GetRight()) / 2
	end

	local function updateColumnDrag()
		local x = cursorX()
		for _ = 1, #ordered do
			local i = indexOf(draggingCol)
			local nextIndex, nextCol = visibleNeighbor(i, 1)
			local prevIndex, prevCol = visibleNeighbor(i, -1)
			if nextCol and x > midpoint(nextCol) then
				table.remove(ordered, i)
				table.insert(ordered, nextIndex, draggingCol)
			elseif prevCol and x < midpoint(prevCol) then
				table.remove(ordered, i)
				table.insert(ordered, prevIndex, draggingCol)
			else
				break
			end
			relayout()
		end
	end

	function startColumnDrag(col)
		draggingCol = col
		local cell = headerCells[col.key]
		dragOverlay:ClearAllPoints()
		dragOverlay:SetPoint("TOPLEFT", cell, "TOPLEFT", -3, 1)
		dragOverlay:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 3, 1)
		dragOverlay:SetPoint("BOTTOM", scroll, "BOTTOM", 0, 0)
		dragOverlay:Show()
		header:SetScript("OnUpdate", updateColumnDrag)
	end

	function finishColumnDrag()
		header:SetScript("OnUpdate", nil)
		dragOverlay:Hide()
		if not draggingCol then
			return
		end
		draggingCol = nil
		suppressHeaderClick = true
		C_Timer.After(0, function() suppressHeaderClick = false end)
		saveOrder()
		relayout()
	end

	for _, col in ipairs(columns) do
		local isFlex = col.key == flexKey
		local button = CreateFrame("Button", nil, header)
		button:SetHeight(18)
		if not isFlex then
			button:SetWidth(col.width - 6)
		end

		button:SetClipsChildren(true)
		local labelClip = CreateFrame("Frame", nil, button)
		labelClip:SetPoint("TOPLEFT")
		labelClip:SetPoint("BOTTOMRIGHT", -12, 0)

		local fs = labelClip:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		fs:SetAllPoints()
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(true)
		fs:SetMaxLines(1)
		fs:SetText(ns.ColumnLabel(col))

		if not col.noSort then
			local arrowIcon = button:CreateTexture(nil, "ARTWORK")
			arrowIcon:SetSize(10, 10)
			arrowIcon:SetPoint("RIGHT", -1, 0)
			arrowIcon:Hide()
			headerArrows[col.key] = arrowIcon

			button:RegisterForClicks("LeftButtonUp")
			button:SetScript("OnClick", function()
				if suppressHeaderClick then
					return
				end
				if sortKey == col.key then
					sortDir = (sortDir == "desc") and "asc" or "desc"
				else
					sortKey = col.key
					sortDir = "desc"
				end
				updateArrows()
				refresh()
			end)
		end
		headerCells[col.key] = button
		headerLabels[col.key] = fs

		if not isFlex then
			createResizeHandle(col.key, function() return col end, false)
		else
			createResizeHandle(col.key, columnAfterFlex, true)
		end

		button:RegisterForDrag("LeftButton")
		button:SetScript("OnDragStart", function() startColumnDrag(col) end)
		button:SetScript("OnDragStop", function() finishColumnDrag() end)
	end

	updateArrows()

	local function setColumnVisible(key, visible)
		if not config.tableId or not isHideable(key) then
			return
		end
		local vis = ns.GetSettings().columnVisibility
		vis[config.tableId] = vis[config.tableId] or {}
		if visible then
			vis[config.tableId][key] = nil
		else
			vis[config.tableId][key] = false
		end
		relayout()
	end

	return {
		container = container,
		Refresh = refresh,
		GetItemCount = function() return #items end,
		IsColumnVisible = isColumnVisible,
		SetColumnVisible = setColumnVisible,
		IsColumnHideable = isHideable,
	}
end

function ns.SavePopupPosition(frame, key)
	ns.GetSettings().windowPositions[key] = { x = frame:GetLeft(), y = frame:GetTop() }
end

function ns.RestorePopupPosition(frame, key, point, relativePoint, x, y)
	local saved = ns.GetSettings().windowPositions[key]
	frame:ClearAllPoints()
	if saved and saved.x and saved.y then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", saved.x, saved.y)
	else
		frame:SetPoint(point or "CENTER", UIParent, relativePoint or point or "CENTER", x or 0, y or 0)
	end
end

function ns.MakePopupDraggable(frame, key)
	if frame.SetDontSavePosition then
		frame:SetDontSavePosition(true)
	end
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		ns.SavePopupPosition(self, key)
	end)
end

local MIN_SCROLL_STEP = 20

function ns.SetGentleScroll(scroll)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local bar = self.ScrollBar
		if not bar then
			return
		end
		local step = math.max(MIN_SCROLL_STEP, self:GetHeight() / 4)
		bar:SetValue(bar:GetValue() - delta * step)
	end)
end

-- point offsets are in the frame's own scale, so re-anchor to hold the on-screen top-left
function ns.SetScaleKeepingTopLeft(frame, scale)
	local oldScale = frame:GetEffectiveScale()
	local left, top = frame:GetLeft(), frame:GetTop()
	frame:SetScale(scale)
	if left and top then
		local ratio = oldScale / frame:GetEffectiveScale()
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * ratio, top * ratio)
		return true
	end
	return false
end

function ns.CreateButton(parent, text, width, height, onClick, tooltip)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width or 80, height or 22)
	btn:SetText(text)
	if onClick then
		btn:SetScript("OnClick", onClick)
	end
	if tooltip then
		ns.AttachHookTooltip(btn, tooltip)
	end
	return btn
end

-- red with gold text when on, grayed out when off
function ns.CreateRehearseButton(parent, width, height)
	local btn = ns.CreateButton(parent, "Rehearse", width or 76, height or 18, function(self)
		local presenter = ns.GetSettings().presenter
		presenter.rehearse = not presenter.rehearse
		ns.UpdateRehearseButton(self)
		ns.RefreshTooltipFor(self)
		ns.RefreshAll()
	end, function()
		return ns.RehearseTip() .. "\n\nCurrently " .. (ns.GetSettings().presenter.rehearse and "on." or "off.")
	end)
	ns.UpdateRehearseButton(btn)
	return btn
end

function ns.UpdateRehearseButton(btn)
	local on = ns.GetSettings().presenter.rehearse
	for _, region in ipairs({ btn:GetRegions() }) do
		if region:GetObjectType() == "Texture" then
			region:SetDesaturated(not on)
		end
	end
	btn:SetNormalFontObject(on and GameFontNormal or GameFontDisable)
end

function ns.CreateLabel(parent, text, template)
	local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormalSmall")
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	return fs
end

function ns.CreatePopupFrame(globalName, width, height, title, positionKey)
	local popup = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
	tinsert(UISpecialFrames, globalName)
	popup:SetSize(width, height)
	popup:SetFrameStrata("DIALOG")
	popup:SetToplevel(true)
	popup:SetClampedToScreen(true)
	popup:SetBackdrop({
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		edgeSize = 24,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	})
	popup:SetBackdropBorderColor(0.85, 0.68, 0.3, 1)
	if positionKey then
		ns.MakePopupDraggable(popup, positionKey)
		ns.RestorePopupPosition(popup, positionKey)
	else
		popup:SetPoint("CENTER")
		popup:SetMovable(true)
		popup:EnableMouse(true)
		popup:RegisterForDrag("LeftButton")
		popup:SetScript("OnDragStart", popup.StartMoving)
		popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
	end

	local fill = popup:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetPoint("TOPLEFT", 8, -8)
	fill:SetPoint("BOTTOMRIGHT", -8, 8)
	fill:SetColorTexture(0.1, 0.08, 0.06, 1)

	local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() popup:Hide() end)

	popup.title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	popup.title:SetPoint("TOP", 0, -18)
	popup.title:SetText(title)

	popup:Hide()
	return popup
end

function ns.CreateMultiLineEditBox(parent, fontObject)
	local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	ns.ApplyPanelBackdrop(holder, 0.85)
	holder:SetBackdropColor(0.04, 0.03, 0.02, 0.95)

	local scroll = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", -26, 6)
	ns.SetGentleScroll(scroll)

	-- height is left to the client so it grows with the text
	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(fontObject or ChatFontNormal)
	edit:SetTextInsets(2, 2, 2, 2)
	edit:SetPoint("TOPLEFT")
	edit:SetSize(200, 1)
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	scroll:SetScrollChild(edit)
	scroll:SetScript("OnSizeChanged", function(_, width)
		edit:SetWidth(math.max(50, width))
	end)

	local cursorY, cursorHeight = 0, 0
	local function followCursor()
		local offset = scroll:GetVerticalScroll()
		local viewHeight = scroll:GetHeight()
		local top = -cursorY
		local bottom = top + cursorHeight
		if top < offset then
			scroll:SetVerticalScroll(math.max(0, top))
		elseif bottom > offset + viewHeight then
			scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(), bottom - viewHeight))
		end
	end
	edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
		cursorY, cursorHeight = y, height
		C_Timer.After(0, followCursor)
	end)

	-- clicks below the last line land on the scroll frame
	scroll:SetScript("OnMouseDown", function()
		if not edit:HasFocus() then
			edit:SetFocus()
			edit:SetCursorPosition(#edit:GetText())
		end
	end)

	holder.scroll = scroll
	holder.editBox = edit
	return holder
end

local UNDO_LIMIT = 200
local UNDO_GROUP_SECONDS = 0.8

-- typing bursts collapse into one step; pastes and multi-char deletes are their own step.
-- onRestore(text) runs after undo/redo since SetText doesn't count as user input
function ns.AttachUndo(edit, onRestore)
	local history, index, lastChange = {}, 1, 0
	local restoring = false

	local function reset()
		history = { { text = edit:GetText(), cursor = edit:GetCursorPosition() } }
		index = 1
		lastChange = 0
	end

	edit:HookScript("OnTextChanged", function(self, userInput)
		if restoring or not userInput then
			return
		end
		local text = self:GetText()
		local current = history[index]
		if current and current.text == text then
			return
		end
		local now = GetTime()
		local burst = index > 1 and now - lastChange < UNDO_GROUP_SECONDS
			and current and math.abs(#text - #current.text) <= 1
			and select(2, text:gsub("\n", "")) == select(2, current.text:gsub("\n", ""))
		lastChange = now
		local state = { text = text, cursor = self:GetCursorPosition() }
		if burst then
			history[index] = state
			return
		end
		for i = #history, index + 1, -1 do
			history[i] = nil
		end
		index = index + 1
		history[index] = state
		if #history > UNDO_LIMIT then
			table.remove(history, 1)
			index = index - 1
		end
	end)

	local function apply(state)
		restoring = true
		edit:SetText(state.text)
		edit:SetCursorPosition(math.min(state.cursor or #state.text, #state.text))
		restoring = false
		lastChange = 0
		if onRestore then
			onRestore(state.text)
		end
	end

	edit:SetScript("OnKeyDown", function(_, key)
		if not IsControlKeyDown() then
			return
		end
		if (key == "Z" and not IsShiftKeyDown()) and index > 1 then
			index = index - 1
			apply(history[index])
		elseif (key == "Y" or (key == "Z" and IsShiftKeyDown())) and index < #history then
			index = index + 1
			apply(history[index])
		end
	end)

	edit.ResetUndo = reset
	reset()
end

local MODIFIER_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, UNKNOWN = true,
}

local function bindingText(bindingName)
	local key = GetBindingKey(bindingName)
	return key and (GetBindingText and GetBindingText(key) or key) or "Not Bound"
end

local function clearBinding(bindingName)
	local key = GetBindingKey(bindingName)
	while key do
		SetBinding(key, nil)
		key = GetBindingKey(bindingName)
	end
end

function ns.CreateKeybindButton(parent, bindingName, width)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width or 130, 20)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:SetText(bindingText(bindingName))

	local function stopListening()
		btn:SetText(bindingText(bindingName))
		btn:EnableKeyboard(false)
		btn:SetScript("OnKeyDown", nil)
	end

	btn:SetScript("OnClick", function(self, mouseButton)
		if InCombatLockdown() then
			ns.Print("Keybinds can't be changed in combat.")
			return
		end
		if mouseButton == "RightButton" then
			clearBinding(bindingName)
			SaveBindings(GetCurrentBindingSet())
			stopListening()
			return
		end
		self:SetText("Press a key...")
		self:EnableKeyboard(true)
		self:SetScript("OnKeyDown", function(_, key)
			if key == "ESCAPE" then
				stopListening()
				return
			end
			if MODIFIER_KEYS[key] then
				return
			end
			local combo = key
			if IsAltKeyDown() then combo = "ALT-" .. combo end
			if IsControlKeyDown() then combo = "CTRL-" .. combo end
			if IsShiftKeyDown() then combo = "SHIFT-" .. combo end
			clearBinding(bindingName)
			SetBinding(combo, bindingName)
			SaveBindings(GetCurrentBindingSet())
			stopListening()
		end)
	end)
	btn:SetScript("OnHide", stopListening)
	btn.Refresh = stopListening
	return btn
end

function ns.BindingKeyText(bindingName)
	return GetBindingKey(bindingName)
end
