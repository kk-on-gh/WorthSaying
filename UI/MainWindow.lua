local ns = WorthSaying

local MIN_WIDTH, MIN_HEIGHT = 960, 520
local DEFAULT_SCREEN_SHARE = 0.7
local DEFAULT_MIN_WIDTH, DEFAULT_MAX_WIDTH = 960, 1440
local ASPECT = 9 / 16
local MINIMIZED_WIDTH, MINIMIZED_HEIGHT = 280, 56
local CONTENT_TOP = 68
local LIST_MIN_WIDTH, EDITOR_MIN_WIDTH = 380, 470

local TAB_SPEECHES, TAB_OPTIONS, TAB_GUIDE, TAB_ABOUT = 1, 2, 3, 4
local TAB_LABELS = { "Speeches", "Options", "Guide", "About" }

local mainFrame
local contents = {}

local function defaultWindowSize()
	local scale = ns.GetSettings().uiScale or 1
	local availWidth = UIParent:GetWidth() / scale
	local availHeight = UIParent:GetHeight() / scale
	local width = availWidth * DEFAULT_SCREEN_SHARE
	if width * ASPECT > availHeight * DEFAULT_SCREEN_SHARE then
		width = availHeight * DEFAULT_SCREEN_SHARE / ASPECT
	end
	width = math.max(DEFAULT_MIN_WIDTH, math.min(DEFAULT_MAX_WIDTH, width))
	local height = width * ASPECT
	if height > availHeight then
		height = availHeight
		width = height / ASPECT
	end
	return math.floor(width + 0.5), math.floor(height + 0.5)
end

-- the screen in the main window's own units, which shrink and grow with its scale
local function screenSize()
	local scale = mainFrame and mainFrame:GetScale() or ns.GetSettings().uiScale or 1
	return UIParent:GetWidth() / scale, UIParent:GetHeight() / scale
end

local function updateResizeBounds()
	if mainFrame.SetResizeBounds then
		local maxWidth, maxHeight = screenSize()
		mainFrame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, maxWidth, maxHeight)
	end
end

local function savePosition()
	local settings = ns.GetSettings()
	local point, _, relativePoint, x, y = mainFrame:GetPoint()
	settings.windowPoint, settings.windowRelativePoint, settings.windowX, settings.windowY = point, relativePoint, x, y
end

local function saveSize()
	local settings = ns.GetSettings()
	settings.windowWidth, settings.windowHeight = mainFrame:GetSize()
end

-- SetClampedToScreen doesn't apply on scale changes
function ns.ReclampMainFrame()
	if not mainFrame then
		return
	end
	local screenWidth, screenHeight = screenSize()
	local width, height = mainFrame:GetSize()
	local newWidth = math.max(MIN_WIDTH, math.min(width, screenWidth))
	local newHeight = math.max(MIN_HEIGHT, math.min(height, screenHeight))
	if newWidth ~= width or newHeight ~= height then
		mainFrame:SetSize(newWidth, newHeight)
		saveSize()
	end
	local left, right = mainFrame:GetLeft(), mainFrame:GetRight()
	local bottom, top = mainFrame:GetBottom(), mainFrame:GetTop()
	if not (left and right and bottom and top) then
		return
	end
	local dx, dy = 0, 0
	if right > screenWidth then
		dx = screenWidth - right
	end
	if left + dx < 0 then
		dx = -left
	end
	if top > screenHeight then
		dy = screenHeight - top
	end
	if bottom + dy < 0 then
		dy = -bottom
	end
	if dx ~= 0 or dy ~= 0 then
		mainFrame:ClearAllPoints()
		mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + dx, top + dy)
		savePosition()
	end
end

-- hand-rolled: StartSizing misbehaves under a custom SetScale
local function createResizeGrip()
	local grip = CreateFrame("Button", nil, mainFrame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
	local startX, startY, startW, startH
	local function onResize()
		local scale = mainFrame:GetEffectiveScale()
		local x, y = GetCursorPosition()
		x, y = x / scale, y / scale
		local screenWidth, screenHeight = screenSize()
		local w = math.max(MIN_WIDTH, math.min(screenWidth, startW + (x - startX)))
		local h = math.max(MIN_HEIGHT, math.min(screenHeight, startH - (y - startY)))
		mainFrame:SetSize(w, h)
	end
	grip:SetScript("OnMouseDown", function(self)
		local left, top = mainFrame:GetLeft(), mainFrame:GetTop()
		mainFrame:ClearAllPoints()
		mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		local scale = mainFrame:GetEffectiveScale()
		local x, y = GetCursorPosition()
		startX, startY = x / scale, y / scale
		startW, startH = mainFrame:GetSize()
		self:SetScript("OnUpdate", onResize)
	end)
	grip:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
		savePosition()
		saveSize()
	end)
	return grip
end

function ns.RefreshFooter()
	if not mainFrame then
		return
	end
	local count = ns.CountSpeeches()
	local tags = #ns.GetAllTags()
	local text = count .. (count == 1 and " speech" or " speeches") .. "  \124\124  " .. tags .. (tags == 1 and " tag" or " tags")
	local state = ns.GetPlaybackState()
	if state.speech then
		text = text .. "  \124\124  Presenting: " .. state.speech.name .. (state.playing and " (playing)" or "")
	end
	mainFrame.footer:SetText(text)
	ns.UpdateRehearseButton(mainFrame.rehearseButton)
end

local function layoutSplit()
	local content = contents[TAB_SPEECHES]
	if not content or not content.listPane then
		return
	end
	local total = content:GetWidth() - 24
	if total <= 0 then
		return
	end
	local ratio = ns.GetSettings().listSplit or 0.46
	local listWidth = math.floor(total * ratio)
	listWidth = math.max(LIST_MIN_WIDTH, math.min(listWidth, total - EDITOR_MIN_WIDTH))
	content.listPane:SetWidth(listWidth)
end

local function createSpeechesContent(content)
	local listPane = CreateFrame("Frame", nil, content)
	listPane:SetPoint("TOPLEFT", 12, -4)
	listPane:SetPoint("BOTTOMLEFT", 12, 0)
	listPane:SetWidth(440)
	content.listPane = listPane

	local divider = CreateFrame("Button", nil, content)
	divider:SetWidth(8)
	divider:SetPoint("TOPLEFT", listPane, "TOPRIGHT", 0, 0)
	divider:SetPoint("BOTTOMLEFT", listPane, "BOTTOMRIGHT", 0, 0)
	local line = divider:CreateTexture(nil, "ARTWORK")
	line:SetPoint("TOP", 0, -4)
	line:SetPoint("BOTTOM", 0, 4)
	line:SetWidth(1)
	line:SetColorTexture(1, 0.82, 0, 0.3)
	local lineHover = divider:CreateTexture(nil, "HIGHLIGHT")
	lineHover:SetAllPoints()
	lineHover:SetColorTexture(1, 0.82, 0, 0.25)
	divider:SetScript("OnMouseDown", function(self)
		self:SetScript("OnUpdate", function()
			local scale = content:GetEffectiveScale()
			local x = GetCursorPosition() / scale
			local total = content:GetWidth() - 24
			local ratio = (x - content:GetLeft() - 12) / total
			ns.GetSettings().listSplit = math.max(0.2, math.min(0.8, ratio))
			layoutSplit()
		end)
	end)
	divider:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	ns.AttachHookTooltip(divider, "Drag to resize the list and editor.")

	local editorPane = CreateFrame("Frame", nil, content)
	editorPane:SetPoint("TOPLEFT", divider, "TOPRIGHT", 0, 0)
	editorPane:SetPoint("BOTTOMRIGHT", -12, 0)
	content.editorPane = editorPane

	ns.BuildSpeechList(listPane)
	ns.BuildEditor(editorPane)

	content:SetScript("OnSizeChanged", layoutSplit)
end

local function selectTab(index)
	for i, content in ipairs(contents) do
		content:SetShown(i == index)
	end
	if index == TAB_SPEECHES then
		layoutSplit()
		if ns.RefreshSpeechList then
			ns.RefreshSpeechList()
		end
	end
	ns.RefreshFooter()
end

local function setTab(index)
	if PanelTemplates_SetTab then
		PanelTemplates_SetTab(mainFrame, index)
	end
	mainFrame.selectedTab = index
	selectTab(index)
end

local function createTabs()
	local tabs, prevTab = {}, nil
	for i, label in ipairs(TAB_LABELS) do
		local tab = CreateFrame("Button", "WSFrameTab" .. i, mainFrame, "PanelTabButtonTemplate")
		tab:SetText(label)
		tab:SetID(i)
		if prevTab then
			tab:SetPoint("LEFT", prevTab, "RIGHT", -8, 0)
		else
			tab:SetPoint("TOPLEFT", 14, -36)
		end
		tab:SetScript("OnClick", function(self) setTab(self:GetID()) end)
		prevTab = tab
		tabs[i] = tab
	end
	if PanelTemplates_SetNumTabs then
		PanelTemplates_SetNumTabs(mainFrame, #TAB_LABELS)
		PanelTemplates_SetTab(mainFrame, 1)
	end
	mainFrame.selectedTab = 1
	return tabs
end

local function createMainFrame()
	mainFrame = CreateFrame("Frame", "WSFrame", UIParent, "BackdropTemplate")
	tinsert(UISpecialFrames, "WSFrame")

	local settings = ns.GetSettings()
	mainFrame:SetScale(settings.uiScale)
	local defaultWidth, defaultHeight = defaultWindowSize()
	local width = math.max(settings.windowWidth or defaultWidth, MIN_WIDTH)
	local height = math.max(settings.windowHeight or defaultHeight, MIN_HEIGHT)
	local screenWidth, screenHeight = screenSize()
	mainFrame:SetSize(math.min(width, screenWidth), math.min(height, screenHeight))
	if settings.windowPoint then
		mainFrame:SetPoint(settings.windowPoint, UIParent, settings.windowRelativePoint or settings.windowPoint, settings.windowX, settings.windowY)
	else
		mainFrame:SetPoint("CENTER")
	end
	mainFrame:SetFrameStrata("HIGH")
	mainFrame:SetToplevel(true)
	mainFrame:SetMovable(true)
	mainFrame:SetResizable(true)
	mainFrame:SetClampedToScreen(true)
	if mainFrame.SetResizeBounds then
		mainFrame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, screenSize())
	end
	if mainFrame.SetDontSavePosition then
		mainFrame:SetDontSavePosition(true)
	end
	mainFrame:EnableMouse(true)
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
	mainFrame:SetScript("OnDragStop", function()
		mainFrame:StopMovingOrSizing()
		savePosition()
	end)
	mainFrame:SetBackdrop({
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	mainFrame:SetBackdropBorderColor(0.85, 0.68, 0.3, 1)
	mainFrame:SetAlpha(settings.windowAlpha)
	mainFrame:Hide()
	ns.ReclampMainFrame()

	local fill = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetPoint("TOPLEFT", 11, -9)
	fill:SetPoint("BOTTOMRIGHT", -9, 8)
	fill:SetColorTexture(0.1, 0.08, 0.06, 1)

	local headerBand = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -4)
	headerBand:SetPoint("TOPLEFT", 14, -12)
	headerBand:SetPoint("TOPRIGHT", -14, -12)
	headerBand:SetHeight(22)
	headerBand:SetColorTexture(0.42, 0.3, 0.14, 1)

	local footerBand = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -4)
	footerBand:SetPoint("BOTTOMLEFT", 14, 12)
	footerBand:SetPoint("BOTTOMRIGHT", -14, 12)
	footerBand:SetHeight(22)
	footerBand:SetColorTexture(0.42, 0.3, 0.14, 1)

	for _, band in ipairs({ headerBand, footerBand }) do
		local grain = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -3)
		grain:SetAllPoints(band)
		grain:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
		grain:SetVertexColor(0.75, 0.6, 0.35, 0.75)
		band.grain = grain
	end

	local title = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Worth Saying")

	local close = ns.CreateButton(mainFrame, "X", 20, 20, function() mainFrame:Hide() end)
	close:SetPoint("TOPRIGHT", -18, -13)

	local minimizeButton = ns.CreateButton(mainFrame, "_", 20, 20)
	minimizeButton:SetPoint("RIGHT", close, "LEFT", -4, 0)

	local presenterButton = ns.CreateButton(mainFrame, "Presenter", 80, 20, function() ns.TogglePresenter() end,
		"Show or hide the presenter, the small window you deliver speeches from.")
	presenterButton:SetPoint("RIGHT", minimizeButton, "LEFT", -6, 0)

	mainFrame.footer = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	mainFrame.footer:SetPoint("LEFT", footerBand, "LEFT", 6, 0)
	local footerFont, _, footerFlags = mainFrame.footer:GetFont()
	mainFrame.footer:SetFont(footerFont, 12, footerFlags)
	mainFrame.footer:SetTextColor(0.06, 0.04, 0.02, 1)
	mainFrame.footer:SetShadowOffset(0, 0)

	local rehearseButton = ns.CreateRehearseButton(mainFrame)
	rehearseButton:SetPoint("RIGHT", footerBand, "RIGHT", -18, 0)
	mainFrame.rehearseButton = rehearseButton

	local tabButtons = createTabs()

	for i = 1, #TAB_LABELS do
		local content = CreateFrame("Frame", nil, mainFrame)
		content:SetPoint("TOPLEFT", 0, -CONTENT_TOP)
		content:SetPoint("BOTTOMRIGHT", 0, 44)
		content:Hide()
		contents[i] = content
	end
	createSpeechesContent(contents[TAB_SPEECHES])
	ns.BuildOptionsPanel(contents[TAB_OPTIONS])
	ns.BuildGuidePanel(contents[TAB_GUIDE])
	ns.BuildAboutPanel(contents[TAB_ABOUT])

	local resizeGrip = createResizeGrip()

	local minimized = false
	local expandedWidth, expandedHeight
	local function setMinimized(min)
		local right, top = mainFrame:GetRight(), mainFrame:GetTop()
		if right and top then
			mainFrame:ClearAllPoints()
			mainFrame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
			savePosition()
		end
		minimized = min
		mainFrame.isMinimized = min
		mainFrame:SetResizable(not min)
		resizeGrip:SetShown(not min)
		presenterButton:SetShown(not min)
		for _, tab in ipairs(tabButtons) do
			tab:SetShown(not min)
		end
		footerBand:SetShown(not min)
		footerBand.grain:SetShown(not min)
		mainFrame.footer:SetShown(not min)
		mainFrame.rehearseButton:SetShown(not min)
		if min then
			expandedWidth, expandedHeight = mainFrame:GetSize()
			for _, content in ipairs(contents) do
				content:Hide()
			end
			mainFrame:SetSize(MINIMIZED_WIDTH, MINIMIZED_HEIGHT)
			minimizeButton:SetText("+")
		else
			mainFrame:SetSize(expandedWidth or MIN_WIDTH, expandedHeight or MIN_HEIGHT)
			selectTab(mainFrame.selectedTab or 1)
			minimizeButton:SetText("_")
		end
	end
	minimizeButton:SetScript("OnClick", function() setMinimized(not minimized) end)
	mainFrame.SetMinimized = setMinimized

	mainFrame:SetScript("OnShow", function()
		if not minimized then
			selectTab(mainFrame.selectedTab or 1)
		end
	end)
end

function ns.SetMainWindowScale(scale)
	ns.GetSettings().uiScale = scale
	if not mainFrame then
		return
	end
	if ns.SetScaleKeepingTopLeft(mainFrame, scale) then
		savePosition()
	end
	updateResizeBounds()
	ns.ReclampMainFrame()
end

function ns.EnsureMainFrame()
	if not mainFrame then
		createMainFrame()
	end
	return mainFrame
end

function ns.IsMainWindowShown()
	return mainFrame ~= nil and mainFrame:IsShown()
end

function ns.IsTabVisible(index)
	return mainFrame ~= nil and mainFrame:IsShown() and not mainFrame.isMinimized and mainFrame.selectedTab == index
end

function ns.IsSpeechesTabVisible()
	return ns.IsTabVisible(TAB_SPEECHES)
end

function ns.ToggleMainWindow()
	local f = ns.EnsureMainFrame()
	f:SetShown(not f:IsShown())
end

function ns.ShowMainWindow()
	ns.EnsureMainFrame():Show()
end

local function goToTab(index)
	ns.EnsureMainFrame()
	mainFrame:Show()
	if mainFrame.isMinimized then
		mainFrame.SetMinimized(false)
	end
	if mainFrame.selectedTab ~= index then
		setTab(index)
	end
end

function ns.SelectSpeechesTab() goToTab(TAB_SPEECHES) end
function ns.SelectOptionsTab() goToTab(TAB_OPTIONS) end
function ns.SelectGuideTab() goToTab(TAB_GUIDE) end
function ns.SelectAboutTab() goToTab(TAB_ABOUT) end

local refreshPending = false

local function refreshAllNow()
	refreshPending = false
	if ns.RefreshSpeechList then
		ns.RefreshSpeechList()
	end
	if ns.RefreshEditor then
		ns.RefreshEditor()
	end
	if ns.RefreshPresenter then
		ns.RefreshPresenter()
	end
	ns.RefreshFooter()
end

-- coalesced to one refresh per frame
function ns.RefreshAll()
	if refreshPending then
		return
	end
	refreshPending = true
	C_Timer.After(0, refreshAllNow)
end
