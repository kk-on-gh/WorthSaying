local ns = WorthSaying

local expanded = { [1] = true }
local scroll, scrollChild
local pool = {}
local used = 0
local headerPool = {}
local headersUsed = 0

local function isNewerVersion(a, b)
	local partsA, partsB = {}, {}
	for n in tostring(a):gmatch("%d+") do partsA[#partsA + 1] = tonumber(n) end
	for n in tostring(b):gmatch("%d+") do partsB[#partsB + 1] = tonumber(n) end
	for i = 1, math.max(#partsA, #partsB) do
		local x, y = partsA[i] or 0, partsB[i] or 0
		if x ~= y then
			return x > y
		end
	end
	return false
end

local function expandMissedVersions()
	local from = ns.UpdatedFromVersion
	if not from then
		return
	end
	for index, entry in ipairs(ns.CHANGELOG) do
		if isNewerVersion(entry.version, from) then
			expanded[index] = true
		end
	end
end

local function getString(template)
	used = used + 1
	local fs = pool[used]
	if not fs then
		fs = scrollChild:CreateFontString(nil, "ARTWORK", template)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(true)
		pool[used] = fs
	end
	fs:SetFontObject(template)
	fs:SetTextColor(1, 1, 1)
	fs:ClearAllPoints()
	fs:Show()
	return fs
end

local layout

local function getHeader()
	headersUsed = headersUsed + 1
	local header = headerPool[headersUsed]
	if not header then
		header = CreateFrame("Button", nil, scrollChild)
		header:SetHeight(20)
		header.text = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		header.text:SetPoint("LEFT", 4, 0)
		local hl = header:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 0.82, 0, 0.08)
		headerPool[headersUsed] = header
	end
	header:ClearAllPoints()
	header:Show()
	return header
end

function layout()
	used, headersUsed = 0, 0
	local width = math.max(200, scroll:GetWidth())
	scrollChild:SetWidth(width)
	local y = -4

	for index, entry in ipairs(ns.CHANGELOG) do
		local header = getHeader()
		header:SetPoint("TOPLEFT", 0, y)
		header:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)
		local tag = entry.shipped and "" or "  |cffff6060(unreleased)|r"
		header.text:SetText((expanded[index] and "[-] " or "[+] ") .. "v" .. entry.version .. ((entry.date or "") ~= "" and (" - " .. entry.date) or "") .. tag)
		header:SetScript("OnClick", function()
			expanded[index] = not expanded[index]
			layout()
		end)
		y = y - 22

		if expanded[index] then
			for _, paragraph in ipairs(entry.intro or {}) do
				local fs = getString("GameFontHighlightSmall")
				fs:SetPoint("TOPLEFT", 16, y)
				fs:SetWidth(width - 32)
				fs:SetText(paragraph)
				y = y - fs:GetStringHeight() - 8
			end
			for _, section in ipairs(entry.sections) do
				local label = getString("GameFontNormalSmall")
				label:SetPoint("TOPLEFT", 16, y)
				label:SetWidth(width - 32)
				label:SetTextColor(1, 0.82, 0)
				label:SetText(section.heading)
				y = y - 16
				for _, item in ipairs(section.items) do
					local fs = getString("GameFontHighlightSmall")
					fs:SetPoint("TOPLEFT", 26, y)
					fs:SetWidth(width - 42)
					fs:SetText("- " .. item)
					y = y - fs:GetStringHeight() - 6
				end
				y = y - 6
			end
		end
		y = y - 6
	end

	for i = used + 1, #pool do
		pool[i]:Hide()
	end
	for i = headersUsed + 1, #headerPool do
		headerPool[i]:Hide()
	end
	scrollChild:SetHeight(-y + 10)
end

function ns.BuildAboutPanel(parent)
	local PAD = 20
	expandMissedVersions()

	local header = CreateFrame("Frame", nil, parent)
	header:SetPoint("TOPLEFT", PAD, -PAD)
	header:SetPoint("TOPRIGHT", -PAD, -PAD)
	header:SetHeight(94)

	local logo = header:CreateTexture(nil, "ARTWORK")
	logo:SetSize(56, 56)
	logo:SetPoint("TOPLEFT", 0, 0)
	logo:SetTexture("Interface\\AddOns\\WorthSaying\\Media\\PortraitIcon.png")

	local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -2)
	title:SetText("Worth Saying")
	local titleFont, titleSize, titleFlags = title:GetFont()
	titleSize = titleSize + 2
	title:SetFont(titleFont, titleSize, titleFlags)

	local version = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	version:SetText("Version " .. tostring(ns.GetAddonVersion()))

	local patchCheck = ns.CreateSmallCheckbox(header, 24, ns.GetSettings().showPatchNotesOnUpdate,
		function(checked) ns.GetSettings().showPatchNotesOnUpdate = checked end)
	patchCheck:SetPoint("TOPLEFT", version, "BOTTOMLEFT", -4, -4)
	local patchCheckLabel = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	patchCheckLabel:SetPoint("LEFT", patchCheck, "RIGHT", 2, 0)
	patchCheckLabel:SetText("Show patch notes for new versions")
	ns.AttachTooltip(patchCheck, "Opens this tab once after Worth Saying updates to a new version.")

	local welcome = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	welcome:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -12)
	welcome:SetPoint("RIGHT", header, "RIGHT", 0, 0)
	welcome:SetJustifyH("LEFT")
	welcome:SetWordWrap(true)
	welcome:SetSpacing(3)
	welcome:SetText("Thank you so much for trying Worth Saying!\n"
		.. "New here? The Guide tab covers everything a script can do, and the Sample Tour speech shows most of it in action.\n"
		.. "Please feel very free to share any feedback, bug reports, feature requests, etc with me, I'd love to hear from you.")

	local patchNotesLabel = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	patchNotesLabel:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -14)
	patchNotesLabel:SetText("Patch Notes")
	local font, _, flags = patchNotesLabel:GetFont()
	patchNotesLabel:SetFont(font, titleSize - 2, flags)

	-- values are read-only edit boxes so they can be selected and copied
	local contactHeading = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	contactHeading:SetPoint("TOPRIGHT", 0, -2)
	contactHeading:SetJustifyH("RIGHT")
	contactHeading:SetText("For feedback, bug reports, feature requests, etc:")

	local lineHeight = math.ceil(contactHeading:GetStringHeight())

	local function addContactLine(anchor, label, value)
		local measure = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		measure:SetText(value)
		local width = math.ceil(measure:GetStringWidth()) + 4
		measure:Hide()

		local valueBox = CreateFrame("EditBox", nil, header)
		valueBox:SetFontObject("GameFontHighlightSmall")
		valueBox:SetAutoFocus(false)
		valueBox:SetJustifyH("RIGHT")
		valueBox:SetSize(width, lineHeight)
		valueBox:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -3)
		valueBox:SetText(value)
		valueBox:SetCursorPosition(0)
		valueBox:SetScript("OnTextChanged", function(self, userInput)
			if userInput then
				self:SetText(value)
				self:HighlightText()
			end
		end)
		valueBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
		valueBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
		valueBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		valueBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
		ns.AttachTooltip(valueBox, "Click, then Ctrl+C to copy.")

		local labelText = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		labelText:SetPoint("RIGHT", valueBox, "LEFT", -4, 0)
		labelText:SetText(label)
		return valueBox
	end

	local emailBox = addContactLine(contactHeading, "Email:", "worthsaying.apricot890@passmail.com")
	addContactLine(emailBox, "Discord:", "maliceftw")

	scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", patchNotesLabel, "BOTTOMLEFT", 0, -6)
	scroll:SetPoint("BOTTOMRIGHT", -(PAD + 22), PAD)

	scrollChild = CreateFrame("Frame", nil, scroll)
	scrollChild:SetSize(600, 1)
	scroll:SetScrollChild(scrollChild)

	local lastWidth
	scroll:SetScript("OnSizeChanged", function(_, width)
		width = math.floor(width)
		if width > 100 and width ~= lastWidth then
			lastWidth = width
			layout()
		end
	end)
	parent:HookScript("OnShow", function()
		expandMissedVersions()
		patchCheck:SetChecked(ns.GetSettings().showPatchNotesOnUpdate)
		if scroll:GetWidth() > 100 then
			layout()
		end
	end)
end
