local ns = WorthSaying

-- step = { title, text, tab? ("speeches" | "options" | "guide" | "about"), target? (ns.RegisterTourTarget
--   name) or box? (Options section title, scrolled into view), side? ("below" | "above" | "left" |
--   "right" | "center"), also? + alsoSide? (a second target with its own arrow and glow),
--   marks? (targets that get a faint box, no arrow), hook? (a STEP_HOOKS name below) }
-- no target, or a target that isn't visible, centers the box on the window.
-- left/right flip to the other side when the screen edge is in the way
ns.TOURS = {
	basics = {
		{
			title = "Welcome!",
			text = "This quick tour shows you around Worth Saying. It takes about two minutes.\n\nLeave any time with the X or Escape, and start it again from the About tab.",
		},
		{
			tab = "speeches", target = "tab.speeches", side = "below",
			title = "Speeches",
			text = "Your library: speeches, tours, RP scripts and one-liners, all written ahead of time.",
		},
		{
			tab = "speeches", target = "speeches.filters", side = "right",
			title = "Finding speeches",
			text = "Search names, tags, trigger places and the scripts themselves. Separate terms with commas to match any of them.\n\nNarrow it down by tag, type, trigger or favorites. Clear resets everything.",
		},
		{
			tab = "speeches", target = "speeches.table", side = "right",
			title = "The list",
			text = "Click a speech to edit it, double-click to open it in the presenter, and right-click for more.\n\nClick a column header to sort, and drag between headers to resize.",
		},
		{
			tab = "speeches", target = "speeches.bottom", side = "above",
			title = "New, import and export",
			text = "Start a new speech or quip, or share them as import strings.",
		},
		{
			tab = "speeches", target = "editor.header", side = "left", hook = "sample",
			title = "The editor",
			text = "Everything saves as you type.\n\nThe channel is where plain lines go, Say unless you change it. Delay is the pause after each line during auto-play. Leave it blank to use the default from Options.",
		},
		{
			tab = "speeches", target = "editor.triggers", side = "left", hook = "sample",
			title = "Triggers",
			text = "Pop the presenter up with this speech when you enter an instance, zone or subzone, or join a group.\n\nSeveral speeches can share a place. One gets picked (Options > Triggers decides how) and the rest are a click away.",
		},
		{
			tab = "speeches", target = "editor.macro", side = "left", hook = "sample",
			title = "Macro",
			text = "Put this in a macro to start the speech from your action bar. Running it again carries on if it stopped.\n\nPlay hidden plays it without opening the presenter.",
		},
		{
			tab = "speeches", target = "editor.script", side = "left", hook = "sample", marks = { "editor.help" },
			title = "The script",
			text = "One chat message per line. Start a line with /y, /p, /g and so on to change its channel, or with an emote like /bow.\n\n{cheer} in braces performs an emote along with the line. /wait 3, /pause, ## Sections and // notes control the flow. Tokens like %t and %z fill in names and places.\n\nThe ? button opens the Guide with everything.",
		},
		{
			tab = "speeches", target = "editor.tabs", side = "below", hook = "preview",
			title = "Preview",
			text = "Each line exactly as it'll be sent, colored by channel, with tokens in gold. Lines that are too long or have a problem are flagged.\n\nClick a line to start presenting from there.",
		},
		{
			target = "presenter", side = "right", hook = "presenter",
			title = "The presenter",
			text = "The line up next and the one after, a progress bar, and a section dropdown if the script has ## sections.\n\nSend sends one line. Play sends them on a timer. The _ button shrinks it to a tiny bar.\n\nRehearse is on for this tour, so go ahead and press Send. Only you will see it.",
		},
		{
			target = "presenter.controls", side = "right", hook = "presenter",
			title = "Key presses",
			text = "Outside instances, Blizzard only lets addons send Say, Yell and numbered-channel lines from a real key press or click.\n\nSo auto-play stops on those and waits. Press Send, your Next key, or the speech's macro, and it carries on. Inside dungeons and raids, everything plays on its own.",
		},
		{
			tab = "speeches", target = "main.rehearse", side = "above", hook = "presenter",
			title = "Rehearse",
			text = "With Rehearse on, lines print only to your own chat window, so you can practice a speech without anyone seeing it.\n\nIt's here and on the presenter, and pulses while it's on.",
		},
		{
			tab = "speeches", target = "speeches.bottom", side = "above",
			title = "Quips",
			text = "A quip sends one random line each time. Good for greetings, pull lines and jokes.\n\nPut /ws quip and its name in a macro to fire one from your action bar without opening anything.",
		},
		{
			tab = "options", target = "tab.options", side = "below",
			title = "Options",
			text = "A theme and font, keybinds for Send, Play and the windows, playback timing, sounds, the presenter's look, and how triggers behave. Hover anything for an explanation.",
		},
		{
			tab = "guide", target = "tab.guide", side = "below",
			title = "Guide",
			text = "Everything a script can do: channels, emotes, control lines and every token.",
		},
		{
			tab = "about", target = "tab.about", side = "below",
			title = "About",
			text = "Patch notes and ways to reach me.",
		},
		{
			tab = "about", target = "about.tours", side = "below", also = "about.contact", alsoSide = "left",
			title = "That's it!",
			text = "Take the Tour starts this again any time, and the Sample Tour and Sample Quip speeches show most of it in action.\n\nQuestions, feedback, ideas, or bugs? My contact info is at the top right. I love hearing from people.\n\nThank you for trying Worth Saying!",
		},
	},
	-- "what's new" tours, one per version, started from that version's patch notes.
	-- keep only the newest three, the About tab ignores older ones anyway
	["v0.3"] = {
		{
			title = "What's new in 0.3",
			text = "A quick look at what's new.",
		},
		{
			box = "Main Window", side = "right", marks = { "options.look" },
			title = "Themes and fonts",
			text = "Pick a theme: Default, Dark, or EllesmereUI if you use it. Dark and EllesmereUI turn checkboxes into toggles and restyle the dropdown menus.\n\nNext to it, pick any font the game has or your other addons share. Both change after a reload.\n\nThe Main Window settings moved up here too.",
		},
		{
			tab = "speeches", target = "main.rehearse", side = "above", hook = "presenter",
			title = "Rehearse",
			text = "The Rehearse button pulses while it's on, so it's hard to forget. It's on for this tour, so you can see it.",
		},
		{
			tab = "speeches", target = "editor.script", side = "left", hook = "sample",
			title = "Script lines",
			text = "Every other line of the script is shaded, so a long line that wraps reads as one.",
		},
		{
			tab = "about",
			title = "That's all for 0.3",
			text = "Thanks for using Worth Saying!",
		},
	},
	["v0.2"] = {
		{
			title = "What's new in 0.2",
			text = "A quick look at what's new.",
		},
		{
			tab = "speeches", target = "editor.macro", side = "left", hook = "sample",
			title = "Macro and Play hidden",
			text = "The editor shows each speech's macro, ready to copy.\n\nTick Play hidden and the macro plays the speech without opening the presenter. When it needs a key press or reaches a /pause, it says so in chat. Run the macro again to carry on.",
		},
		{
			box = "Playback", side = "right", marks = { "options.resume", "options.delay" },
			title = "Playback options",
			text = "Running a speech's macro again picks up where it stopped, unless it's been sitting longer than this. 60 seconds by default.\n\nThe delay after each line can now go as low as 0.1 seconds.\n\nUses always count now, so that option is gone.",
		},
		{
			tab = "about", target = "about.tours", side = "below",
			title = "Tours",
			text = "Tours are new too! Take the full tour any time from here.",
		},
		{
			tab = "about",
			title = "That's all for 0.2",
			text = "Thanks for using Worth Saying!",
		},
	},
}

local TAB_SELECTORS = {
	speeches = function() ns.SelectSpeechesTab() end,
	options = function() ns.SelectOptionsTab() end,
	guide = function() ns.SelectGuideTab() end,
	about = function() ns.SelectAboutTab() end,
}

-- put back on EndTour: the selected speech, rehearse, and the presenter as it was
local saved

local function sampleSpeech()
	local fallback
	for _, speech in ipairs(ns.GetAllSpeeches()) do
		if speech.name == "Sample Tour" then
			return speech
		end
		if speech.kind ~= "quip" and (not fallback or speech.id < fallback.id) then
			fallback = speech
		end
	end
	return fallback
end

local function showSample()
	local speech = sampleSpeech()
	if speech and ns.selectedSpeechId ~= speech.id then
		ns.SelectSpeech(speech.id)
	end
	return speech
end

-- onEnter (before showing), onPlaced(box) (after the tour box is positioned), onLeave (on Next/Back/close)
local STEP_HOOKS = {
	sample = {
		onEnter = showSample,
	},
	preview = {
		onEnter = function()
			showSample()
			ns.SetEditorPreview(true)
		end,
		onLeave = function()
			ns.SetEditorPreview(false)
		end,
	},
	presenter = {
		onEnter = function()
			local settings = ns.GetSettings().presenter
			if saved.rehearse == nil then
				saved.rehearse = settings.rehearse
			end
			settings.rehearse = true
			local state = ns.GetPlaybackState()
			if not state.playing then
				local speech = sampleSpeech()
				if speech and (not state.speech or state.speech.id ~= speech.id) then
					if saved.presented == nil then
						saved.presented = state.speech and state.speech.id or false
					end
					ns.LoadSpeech(speech.id, {})
				end
			end
			if saved.presenterShown == nil then
				saved.presenterShown = ns.IsPresenterShown()
				saved.presenterMini = settings.minimized
			end
			ns.ShowPresenter()
			ns.SetPresenterMinimized(false)
			ns.RefreshAll()
		end,
	},
}

local function runHook(step, name, ...)
	local hook = step and step.hook and STEP_HOOKS[step.hook]
	if hook and hook[name] then
		local ok, err = pcall(hook[name], ...)
		if not ok then
			ns.Print("Tour step failed: " .. tostring(err))
		end
	end
end

local targets = ns.tourTargets

ns.RegisterTourTarget("presenter", function() return _G.WSPresenter end)

local BOX_WIDTH, PAD, ARROW_GAP = 300, 14, 26
local ARROW_FILE = "Interface\\TalentFrame\\TalentFrame-Parts"
local ROTATION = { up = 180, down = 0, left = 90, right = 270 }
-- side the box sits on -> direction its arrow points
local ARROW_DIR = { below = "up", above = "down", right = "left", left = "right" }
local GLOW_PIECES = { "BG", "ShadowTopLeft", "ShadowTopRight", "ShadowBottomLeft", "ShadowBottomRight",
	"ShadowTop", "ShadowBottom", "ShadowLeft", "ShadowRight" }

local callout, highlight, arrow, glow, proxy, boxProxy, alsoArrow, alsoGlow, alsoHighlight, alsoProxy
local tour, stepIndex

-- size is set once at creation; the clamped helper swaps width/height itself
local function rotate(tex, degrees)
	if SetClampedTextureRotation then
		SetClampedTextureRotation(tex, degrees)
	else
		tex:SetRotation(math.rad(degrees))
	end
end

local function newGlowBox(name)
	local ok, frame = pcall(CreateFrame, "Frame", name, UIParent, "GlowBoxTemplate")
	if ok then
		return frame
	end
	frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	frame:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
	frame:SetBackdropColor(0.1, 0.08, 0.02, 0.95)
	frame:SetBackdropBorderColor(1, 0.82, 0, 1)
	return frame
end

local function newOutline()
	local frame = newGlowBox(nil)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:EnableMouse(false)
	for _, key in ipairs(GLOW_PIECES) do
		if frame[key] then
			frame[key]:Hide()
		end
	end
	if frame.SetBackdropColor then
		frame:SetBackdropColor(0, 0, 0, 0)
	end
	return frame
end

local function newArrow(width, height, glowWidth, glowHeight, alpha, glowAlpha)
	local host = callout.artHost
	local tex = host:CreateTexture(nil, "ARTWORK")
	tex:SetTexture(ARROW_FILE)
	tex:SetTexCoord(0.78515625, 0.99218750, 0.54687500, 0.58789063)
	tex:SetSize(width, height)
	tex:SetAlpha(alpha)
	local shine = host:CreateTexture(nil, "BORDER")
	shine:SetTexture(ARROW_FILE)
	shine:SetTexCoord(0.40625000, 0.66015625, 0.77343750, 0.82812500)
	shine:SetSize(glowWidth, glowHeight)
	shine:SetBlendMode("ADD")
	shine:SetAlpha(glowAlpha)
	shine:SetPoint("CENTER", tex, "CENTER")
	return tex, shine
end

local function buildCallout()
	callout = newGlowBox("WSTourCallout")
	callout:SetFrameStrata("FULLSCREEN_DIALOG")
	callout:SetToplevel(true)
	callout:SetClampedToScreen(true)
	callout:EnableMouse(true)
	callout:SetWidth(BOX_WIDTH)
	tinsert(UISpecialFrames, "WSTourCallout")
	ns.Skin.Panel(callout, "float")
	callout.artHost = ns.Skin.CreateArtHost(callout)

	callout.title = ns.Skin.Text(callout, "OVERLAY", "GameFontNormalLarge")
	callout.title:SetPoint("TOPLEFT", PAD, -PAD)
	callout.title:SetPoint("RIGHT", -28, 0)
	callout.title:SetJustifyH("LEFT")
	ns.Skin.Heading(callout.title)

	callout.body = ns.Skin.Text(callout, "OVERLAY", "GameFontHighlight")
	callout.body:SetPoint("TOPLEFT", callout.title, "BOTTOMLEFT", 0, -8)
	callout.body:SetWidth(BOX_WIDTH - 2 * PAD)
	callout.body:SetJustifyH("LEFT")
	callout.body:SetSpacing(2)

	local close = CreateFrame("Button", nil, callout, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		ns.EndTour()
		callout:Hide()
	end)
	ns.Skin.CloseButton(close)

	callout.next = CreateFrame("Button", nil, callout, "UIPanelButtonTemplate")
	callout.next:SetSize(80, 22)
	callout.next:SetPoint("BOTTOMRIGHT", -PAD, PAD - 2)
	callout.next:SetScript("OnClick", function()
		if not (tour and stepIndex) then
			callout:Hide()
		elseif stepIndex < #tour then
			ns.ShowTourStep(stepIndex + 1)
		else
			ns.EndTour()
		end
	end)
	ns.Skin.Button(callout.next)

	callout.back = CreateFrame("Button", nil, callout, "UIPanelButtonTemplate")
	callout.back:SetSize(80, 22)
	callout.back:SetPoint("RIGHT", callout.next, "LEFT", -6, 0)
	callout.back:SetText("Back")
	callout.back:SetScript("OnClick", function()
		if not (tour and stepIndex) then
			callout:Hide()
			return
		end
		ns.ShowTourStep(stepIndex - 1)
	end)
	ns.Skin.Button(callout.back)

	callout.counter = ns.Skin.Text(callout, "OVERLAY", "GameFontDisableSmall")
	callout.counter:SetPoint("LEFT", callout, "BOTTOMLEFT", PAD, PAD + 9)

	callout:SetScript("OnHide", function()
		if tour then
			ns.EndTour()
		end
	end)

	arrow, glow = newArrow(53, 21, 65, 28, 1, 0.5)
	highlight = newOutline()

	-- the secondary pointer is a quieter version of the main one
	alsoArrow, alsoGlow = newArrow(37, 15, 46, 20, 0.8, 0.2)
	alsoHighlight = newOutline()
	alsoHighlight:SetAlpha(0.45)

	proxy = CreateFrame("Frame", nil, UIParent)
	alsoProxy = CreateFrame("Frame", nil, UIParent)
	boxProxy = CreateFrame("Frame", nil, UIParent)
end

local function scrollFrameOf(box)
	local child = box:GetParent()
	local scroll = child and child:GetParent()
	if scroll and scroll.GetObjectType and scroll:GetObjectType() == "ScrollFrame" then
		return scroll, child
	end
end

local function scrollToBox(key)
	local box = ns.tourBoxes[key]
	if not box then
		return
	end
	local scroll, child = scrollFrameOf(box)
	if not (scroll and child:GetTop() and box:GetTop()) then
		return
	end
	local offset = child:GetTop() - box:GetTop() - 8
	scroll:SetVerticalScroll(math.max(0, math.min(offset, scroll:GetVerticalScrollRange() or 0)))
end

-- the part of the box currently scrolled into view
local function boxTarget(key)
	local box = ns.tourBoxes[key]
	if not (box and box:IsVisible()) then
		return nil
	end
	local scroll = scrollFrameOf(box)
	if not scroll then
		return box
	end
	local top, bottom = box:GetTop(), box:GetBottom()
	local visTop, visBottom = math.min(top, scroll:GetTop()), math.max(bottom, scroll:GetBottom())
	if visTop <= visBottom then
		return nil
	end
	boxProxy:SetParent(scroll)
	boxProxy:ClearAllPoints()
	boxProxy:SetPoint("TOPLEFT", box, "TOPLEFT", 0, visTop - top)
	boxProxy:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, visBottom - top)
	boxProxy:Show()
	return boxProxy
end

-- flips left/right when the box wouldn't fit on that side of the screen
local function fitSide(side, target)
	if side ~= "left" and side ~= "right" then
		return side
	end
	local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local need = (BOX_WIDTH + ARROW_GAP + 10) * callout:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local roomRight = UIParent:GetWidth() - target:GetRight() * scale
	local roomLeft = target:GetLeft() * scale
	if side == "right" and roomRight < need then
		return roomLeft >= need and "left" or "center"
	elseif side == "left" and roomLeft < need then
		return roomRight >= need and "right" or "center"
	end
	return side
end

local function resolveTarget(name, pairProxy)
	pairProxy = pairProxy or proxy
	local target = name and targets[name]
	if type(target) == "function" then
		target = target()
	end
	if type(target) == "table" and target[1] then
		local first, last = target[1], target[2] or target[1]
		if not (first:IsVisible() and last:IsVisible()) then
			return nil
		end
		pairProxy:ClearAllPoints()
		pairProxy:SetPoint("TOPLEFT", first, "TOPLEFT")
		pairProxy:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
		pairProxy:Show()
		return pairProxy
	end
	if target and target.IsVisible and target:IsVisible() then
		return target
	end
	return nil
end

local MARK_PAD = 6
local marks = {}

local function getMark(i)
	if not marks[i] then
		local mark = newOutline()
		mark:SetAlpha(0.35)
		mark.proxy = CreateFrame("Frame", nil, UIParent)
		marks[i] = mark
	end
	return marks[i]
end

local function hideMarks()
	for _, mark in ipairs(marks) do
		mark:Hide()
	end
end

local function placeMarks(step)
	hideMarks()
	for i, name in ipairs(step.marks or {}) do
		local mark = getMark(i)
		local target = resolveTarget(name, mark.proxy)
		if target then
			mark:ClearAllPoints()
			mark:SetPoint("TOPLEFT", target, "TOPLEFT", -MARK_PAD, MARK_PAD)
			mark:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", MARK_PAD, -MARK_PAD)
			mark:SetFrameLevel(callout:GetFrameLevel() - 1)
			mark:Show()
		end
	end
end

-- the arrow sits on `side` of the target, pointing at it
local ALSO_ARROW_DIR = { left = "right", right = "left", above = "down", below = "up" }
local ALSO_PAD = 8

local function placeAlso(step)
	alsoArrow:Hide()
	alsoGlow:Hide()
	alsoHighlight:Hide()
	local target = step.also and resolveTarget(step.also, alsoProxy)
	if not target then
		return
	end
	alsoHighlight:ClearAllPoints()
	alsoHighlight:SetPoint("TOPLEFT", target, "TOPLEFT", -ALSO_PAD, ALSO_PAD)
	alsoHighlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", ALSO_PAD, -ALSO_PAD)
	alsoHighlight:SetFrameLevel(callout:GetFrameLevel() - 1)
	alsoHighlight:Show()

	local side = step.alsoSide or "left"
	local dir = ALSO_ARROW_DIR[side] or "right"
	rotate(alsoArrow, ROTATION[dir])
	rotate(alsoGlow, ROTATION[dir])
	alsoArrow:ClearAllPoints()
	local gap = ALSO_PAD + 3
	if side == "left" then
		alsoArrow:SetPoint("RIGHT", target, "LEFT", -gap, 0)
	elseif side == "right" then
		alsoArrow:SetPoint("LEFT", target, "RIGHT", gap, 0)
	elseif side == "above" then
		alsoArrow:SetPoint("BOTTOM", target, "TOP", 0, gap)
	else
		alsoArrow:SetPoint("TOP", target, "BOTTOM", 0, -gap)
	end
	alsoArrow:Show()
	alsoGlow:Show()
end

local function placeUnsafe(step)
	callout.title:SetText(step.title or "")
	callout.body:SetText(step.text or "")
	callout.counter:SetText(stepIndex .. " / " .. #tour)
	callout.back:SetEnabled(stepIndex > 1)
	callout.next:SetText(stepIndex < #tour and "Next" or "Finish")
	local height = PAD + callout.title:GetStringHeight() + 8 + callout.body:GetStringHeight() + 14 + 22 + PAD
	callout:SetHeight(height)

	local target
	if step.box then
		target = boxTarget(step.box)
	else
		target = resolveTarget(step.target)
	end
	local side = target and fitSide(step.side or "center", target) or "center"
	callout:ClearAllPoints()
	arrow:Hide()
	glow:Hide()
	highlight:Hide()

	if not target then
		local anchor = ns.IsMainWindowShown() and ns.EnsureMainFrame() or UIParent
		callout:SetPoint("CENTER", anchor, "CENTER")
	else
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT", target, "TOPLEFT", -4, 4)
		highlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -4)
		highlight:SetFrameLevel(callout:GetFrameLevel() - 1)
		highlight:Show()

		if side == "below" then
			callout:SetPoint("TOP", target, "BOTTOM", 0, -ARROW_GAP)
		elseif side == "above" then
			callout:SetPoint("BOTTOM", target, "TOP", 0, ARROW_GAP)
		elseif side == "right" then
			callout:SetPoint("LEFT", target, "RIGHT", ARROW_GAP, 0)
		elseif side == "left" then
			callout:SetPoint("RIGHT", target, "LEFT", -ARROW_GAP, 0)
		else
			callout:SetPoint("CENTER", target, "CENTER")
		end

		local dir = ARROW_DIR[side]
		if dir then
			rotate(arrow, ROTATION[dir])
			rotate(glow, ROTATION[dir])
			arrow:ClearAllPoints()
			if dir == "up" then
				arrow:SetPoint("BOTTOM", callout, "TOP", 0, 2)
			elseif dir == "down" then
				arrow:SetPoint("TOP", callout, "BOTTOM", 0, -2)
			elseif dir == "left" then
				arrow:SetPoint("RIGHT", callout, "LEFT", -2, 0)
			else
				arrow:SetPoint("LEFT", callout, "RIGHT", 2, 0)
			end
			arrow:Show()
			glow:Show()
		end
	end
	callout:Show()
	callout:Raise()
	placeAlso(step)
	placeMarks(step)
	runHook(step, "onPlaced", callout)
end

-- a failed placement still leaves a usable, centered box instead of a stuck one
local function place(step)
	local ok, err = pcall(placeUnsafe, step)
	if not ok then
		ns.Print("Tour step failed to place: " .. tostring(err))
		callout:ClearAllPoints()
		callout:SetPoint("CENTER", UIParent, "CENTER")
		arrow:Hide()
		glow:Hide()
		highlight:Hide()
		alsoHighlight:Hide()
		hideMarks()
		callout:Show()
	end
end

local function leaveStep()
	local step = tour and stepIndex and tour[stepIndex]
	if step then
		runHook(step, "onLeave")
	end
end

-- presenter steps leave it up between them; anything else puts it back as it was
local function restorePresenter(nextStep)
	if nextStep and nextStep.hook == "presenter" then
		return
	end
	local settings = ns.GetSettings().presenter
	if saved.rehearse ~= nil then
		settings.rehearse = saved.rehearse
		saved.rehearse = nil
	end
	if saved.presented ~= nil then
		local state = ns.GetPlaybackState()
		if not state.playing then
			if saved.presented then
				ns.LoadSpeech(saved.presented, {})
			else
				ns.LoadSpeech(nil, {})
			end
		end
		saved.presented = nil
	end
	if saved.presenterShown ~= nil then
		ns.SetPresenterMinimized(saved.presenterMini and true or false)
		if not saved.presenterShown then
			ns.HidePresenter()
		end
		saved.presenterShown, saved.presenterMini = nil, nil
	end
	ns.RefreshAll()
end

function ns.ShowTourStep(index)
	if not tour or not tour[index] then
		return
	end
	local step = tour[index]
	leaveStep()
	restorePresenter(step)
	stepIndex = index
	local tab = step.tab or (step.box and "options")
	if tab and TAB_SELECTORS[tab] then
		TAB_SELECTORS[tab]()
	end
	runHook(step, "onEnter")
	-- tab switches and editor loads settle on the next frame; a box is scrolled to
	-- first, then measured a frame later
	C_Timer.After(0, function()
		if not (tour and stepIndex == index) then
			return
		end
		if step.box then
			scrollToBox(step.box)
			C_Timer.After(0, function()
				if tour and stepIndex == index then
					place(step)
				end
			end)
		else
			place(step)
		end
	end)
end

function ns.StartTour(id)
	local steps = ns.TOURS[id or "basics"]
	if not steps then
		return
	end
	if not callout then
		buildCallout()
	end
	if tour then
		leaveStep()
		restorePresenter()
	else
		saved = { selected = ns.selectedSpeechId }
	end
	tour = steps
	ns.ShowMainWindow()
	ns.ShowTourStep(1)
end

function ns.EndTour()
	if not tour then
		return
	end
	leaveStep()
	restorePresenter()
	tour, stepIndex = nil, nil
	if saved and saved.selected ~= ns.selectedSpeechId and ns.GetSpeech(saved.selected) then
		ns.SelectSpeech(saved.selected)
	end
	saved = nil
	if callout then
		callout:Hide()
		highlight:Hide()
		alsoHighlight:Hide()
		hideMarks()
	end
end

StaticPopupDialogs["WS_TOUR_OFFER"] = {
	text = "Welcome to Worth Saying!\n\nWant a quick tour? It takes about two minutes.",
	button1 = "Take the tour",
	button2 = "No thanks",
	OnAccept = function()
		ns.StartTour("basics")
	end,
	OnCancel = function(_, _, reason)
		if reason == "clicked" then
			ns.Print("No problem. You can take the tour any time from the About tab.")
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- offered once per account, the first time the main window opens
function ns.OfferTourOnce()
	if ns.WasTourOffered() then
		return
	end
	ns.MarkTourOffered()
	C_Timer.After(0.3, function()
		StaticPopup_Show("WS_TOUR_OFFER")
	end)
end
