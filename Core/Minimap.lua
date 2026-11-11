local ns = WorthSaying

local button

local function getMinimapShape()
	return GetMinimapShape and GetMinimapShape() or "ROUND"
end

local function updatePosition()
	local radius = (Minimap:GetWidth() / 2) + 5
	local angle = math.rad(ns.GetSettings().minimapIcon.angle or 200)
	local x, y = math.cos(angle), math.sin(angle)
	if getMinimapShape() ~= "ROUND" then
		local scale = math.max(math.abs(x), math.abs(y))
		x, y = x / scale, y / scale
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

local function onDragUpdate()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale
	ns.GetSettings().minimapIcon.angle = math.deg(math.atan2(py - my, px - mx))
	updatePosition()
end

local function showTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("Worth Saying")
	GameTooltip:AddLine("Left-click to open", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Shift-click for the presenter", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Right-click for more options", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

-- owned by UIParent: button bags can hide the button before a menu click lands
local function showMenu()
	MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
		rootDescription:CreateTitle("Worth Saying")
		rootDescription:CreateButton("Open Window", function() ns.ShowMainWindow() end)
		rootDescription:CreateButton("Presenter", function() ns.ShowPresenter() end)
		rootDescription:CreateButton("Options", function() ns.SelectOptionsTab() end)
		rootDescription:CreateDivider()
		rootDescription:CreateButton("Hide Minimap Icon", function() ns.SetMinimapIconShown(false) end)
	end)
end

local function createButton()
	button = CreateFrame("Button", "WSMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetPoint("TOPLEFT")
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetTexture("Interface\\AddOns\\WorthSaying\\Media\\MinimapIcon.png")
	button.icon = icon

	button:SetScript("OnEnter", showTooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			showMenu()
		elseif IsShiftKeyDown() then
			ns.TogglePresenter()
		else
			ns.ToggleMainWindow()
		end
	end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDragUpdate) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

	updatePosition()
end

function ns.SetMinimapIconShown(shown)
	ns.GetSettings().minimapIcon.hide = not shown
	if not button then
		if shown then
			createButton()
		end
		return
	end
	button:SetShown(shown)
end

function ns.EnsureMinimapButton()
	if not button and not ns.GetSettings().minimapIcon.hide then
		createButton()
	end
	return button
end
