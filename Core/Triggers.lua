local ns = WorthSaying

local lastSeen = { instance = nil, zone = nil, subzone = nil }
local pending

local function lower(s)
	return s and s:lower() or nil
end

function ns.CurrentInstanceInfo()
	if not IsInInstance() then
		return nil
	end
	local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
	if not name or instanceType == "none" then
		return nil
	end
	return { name = name, id = instanceID, instanceType = instanceType }
end

function ns.CurrentLocationTrigger(triggerType)
	if triggerType == "instance" then
		local info = ns.CurrentInstanceInfo()
		return info and { type = "instance", name = info.name, id = info.id }
	elseif triggerType == "zone" then
		local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
		return zone and zone ~= "" and { type = "zone", name = zone } or nil
	elseif triggerType == "subzone" then
		local sub = GetSubZoneText()
		return sub and sub ~= "" and { type = "subzone", name = sub } or nil
	elseif triggerType == "group" then
		return { type = "group" }
	end
end

local function kindFromType(instanceType)
	if instanceType == "raid" then
		return "raid"
	elseif instanceType == "party" then
		return "dungeon"
	end
	return "other"
end

-- group finder category IDs: 2 dungeons everywhere; raids are 114 on Forever, 3 on retail
local INSTANCE_CATEGORIES = { [2] = "dungeon", [114] = "raid", [3] = "raid" }

local function addGroupFinderInstances(byId)
	if not (C_LFGList and C_LFGList.GetAvailableActivities and C_LFGList.GetActivityInfoTable) then
		return
	end
	for categoryID, kind in pairs(INSTANCE_CATEGORIES) do
		pcall(function()
			for _, activityID in ipairs(C_LFGList.GetAvailableActivities(categoryID) or {}) do
				local info = C_LFGList.GetActivityInfoTable(activityID)
				local mapID = info and info.mapID
				if mapID and mapID > 0 and info.categoryID == categoryID and not info.isPvpActivity and not byId[mapID] then
					local name = GetRealZoneText(mapID)
					if not name or name == "" then
						name = info.fullName ~= "" and info.fullName or info.shortName
					end
					byId[mapID] = { id = mapID, name = name, kind = kind }
				end
			end
		end)
	end
end

-- group finder activities plus anywhere the player has been
function ns.GetInstanceList()
	local byId = {}
	addGroupFinderInstances(byId)
	for id, known in pairs(ns.GetRememberedInstances()) do
		if not byId[id] then
			byId[id] = { id = id, name = known.name, kind = kindFromType(known.instanceType) }
		end
	end
	local list = {}
	for _, entry in pairs(byId) do
		list[#list + 1] = entry
	end
	table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
	return list
end

function ns.TriggerText(trigger)
	if trigger.type == "group" then
		return "Joining a group"
	end
	return ns.TriggerTypeLabel(trigger.type) .. ": " .. (trigger.name or "?")
end

local function triggerMatches(trigger, triggerType, where)
	if trigger.type ~= triggerType then
		return false
	end
	if triggerType == "group" then
		return true
	end
	if not where then
		return false
	end
	if triggerType == "instance" and trigger.id and where.id and trigger.id == where.id then
		return true
	end
	return lower(trigger.name) == lower(where.name)
end

function ns.FindTriggeredSpeeches(triggerType, where)
	local found = {}
	for _, speech in ipairs(ns.GetAllSpeeches()) do
		for _, trigger in ipairs(speech.triggers) do
			if triggerMatches(trigger, triggerType, where) then
				found[#found + 1] = speech
				break
			end
		end
	end
	table.sort(found, function(a, b) return a.name:lower() < b.name:lower() end)
	return found
end

-- higher wins; ties are broken at random
local PICK_SCORES = {
	mostUsed = function(s) return s.uses or 0 end,
	leastUsed = function(s) return -(s.uses or 0) end,
	lastUsed = function(s) return s.lastUsed or 0 end,
	longestUnused = function(s) return -(s.lastUsed or 0) end,
}

local function randomFrom(list)
	return list[math.random(#list)]
end

local function pickSpeech(list)
	local mode = ns.GetSettings().triggers.pick
	if mode == "randomFavorite" then
		local favorites = {}
		for _, speech in ipairs(list) do
			if speech.favorite then
				favorites[#favorites + 1] = speech
			end
		end
		return randomFrom(#favorites > 0 and favorites or list)
	end
	local score = PICK_SCORES[mode]
	if not score then
		return randomFrom(list)
	end
	local best, tied = nil, {}
	for _, speech in ipairs(list) do
		local value = score(speech)
		if not best or value > best then
			best, tied = value, { speech }
		elseif value == best then
			tied[#tied + 1] = speech
		end
	end
	return randomFrom(tied)
end

local function fire(triggerType, where)
	local settings = ns.GetSettings().triggers
	if not settings.enabled or not settings[triggerType] then
		return
	end
	local list = ns.FindTriggeredSpeeches(triggerType, where)
	if #list == 0 then
		return
	end
	if settings.skipInCombat and InCombatLockdown() then
		pending = { triggerType = triggerType, where = where }
		return
	end
	local state = ns.GetPlaybackState()
	if state.playing then
		return
	end
	local ids = {}
	for i, speech in ipairs(list) do
		ids[i] = speech.id
	end
	local chosen = pickSpeech(list)
	local place = where and where.name or "your group"
	local label = (#list > 1 and (#list .. " speeches for ") or "Speech for ") .. place
	ns.LoadSpeech(chosen.id, { candidates = ids, source = "trigger", label = label })
	if ns.ShowPresenter then
		ns.ShowPresenter()
	end
	if settings.sound then
		ns.PlayUISound("IG_QUEST_LIST_OPEN", 875)
	end
	if settings.autoPlay and chosen.kind ~= "quip" then
		ns.Play()
	end
end

local function leftTriggeredPlace()
	local state = ns.GetPlaybackState()
	if state.source == "trigger" and not state.playing and ns.GetSettings().triggers.closeOnLeave and ns.HidePresenter then
		ns.HidePresenter()
		state.source = nil
		state.candidates = nil
		state.triggerLabel = nil
	end
end

local function checkInstance()
	local info = ns.CurrentInstanceInfo()
	local key = info and (tostring(info.id) .. ":" .. info.name) or nil
	if key == lastSeen.instance then
		return
	end
	local hadInstance = lastSeen.instance ~= nil
	lastSeen.instance = key
	if info then
		ns.RememberInstance(info)
		fire("instance", info)
	elseif hadInstance then
		leftTriggeredPlace()
	end
end

local function checkZone()
	local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
	if not zone or zone == "" or zone == lastSeen.zone then
		return
	end
	lastSeen.zone = zone
	if not ns.CurrentInstanceInfo() then
		fire("zone", { name = zone })
	end
end

local function checkSubzone()
	local sub = GetSubZoneText()
	if sub == lastSeen.subzone then
		return
	end
	lastSeen.subzone = sub
	if sub and sub ~= "" then
		fire("subzone", { name = sub })
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("GROUP_JOINED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(_, event, _, isReload)
	if not ns.GetSettings then
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		-- zone data can lag a moment behind the loading screen
		C_Timer.After(1, function()
			if isReload then
				lastSeen.instance = (function()
					local info = ns.CurrentInstanceInfo()
					return info and (tostring(info.id) .. ":" .. info.name) or nil
				end)()
				lastSeen.zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
				lastSeen.subzone = GetSubZoneText()
				return
			end
			checkInstance()
			checkZone()
			checkSubzone()
		end)
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		C_Timer.After(0.5, function()
			checkInstance()
			checkZone()
			checkSubzone()
		end)
	elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
		checkSubzone()
	elseif event == "GROUP_JOINED" then
		C_Timer.After(1, function() fire("group", nil) end)
	elseif event == "PLAYER_REGEN_ENABLED" and pending then
		local p = pending
		pending = nil
		C_Timer.After(1, function() fire(p.triggerType, p.where) end)
	end
end)
