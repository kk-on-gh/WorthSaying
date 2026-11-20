local ns = WorthSaying

local db

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end
ns.DeepCopy = deepCopy

-- array defaults are only filled when missing, never merged by index
local function isArrayLike(t)
	return t[1] ~= nil
end

local function applyDefaults(target, defaults)
	for k, v in pairs(defaults) do
		if target[k] == nil then
			target[k] = deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and not isArrayLike(v) and next(v) ~= nil then
			applyDefaults(target[k], v)
		end
	end
end

local function migrate(savedDb)
	local from = savedDb.schemaVersion or 0
	if from < 1 then
		savedDb.schemaVersion = 1
	end
	local playback = savedDb.settings and savedDb.settings.playback
	if playback then
		playback.countUses = nil
	end
	savedDb.schemaVersion = ns.CURRENT_SCHEMA_VERSION
end

local ORIGINAL_SAMPLE_TOUR = table.concat({
	"// Lines starting with // are notes to yourself and are never sent.",
	"## Welcome",
	"Welcome, everyone, to %z!",
	"/e gestures broadly at the surroundings.",
	"/bow",
	"/wait 5",
	"## The Tour",
	"If you'll follow me, %t, the first stop is just ahead.",
	"/p Party only: stay close, the guards here bite.",
	"/pause",
	"And here we are. Questions? No? Wonderful.",
}, "\n")

-- earlier sample texts, upgraded in place only while untouched
local OLD_SAMPLE_TOURS = {
	[ORIGINAL_SAMPLE_TOUR] = true,
	[table.concat({
		"// Lines starting with // are notes to yourself and are never sent.",
		"// Plain lines go to this speech's default channel (Say). Turn on Rehearse to try it safely.",
		"## Welcome",
		"Welcome, welcome! Gather round, everyone. I'm %p, and I'll be your guide through %z today.",
		"/e straightens their collar and clears their throat importantly.",
		"/bow",
		"A few ground rules: stay with the group, keep your hands inside the tour, and please do not feed the guards.",
		"/wait 4",
		"## First Stop",
		"/pause Wait here until everyone catches up.",
		"If you'll follow me, %t, our first stop is %sz.",
		"/e gestures grandly at the nearest building.",
		"Built long ago by people who were, frankly, very good at building things.",
		"/p Party only: if anyone asks, the gift shop is closed.",
		"## Questions",
		"Now, are there any questions? Yes, you in the back. No? Just stretching? Lovely.",
		"/pause Answer any questions, then press Play.",
		"## The Grand Finale",
		"/y And THAT concludes our tour of %z!",
		"/cheer",
		"Thank you all for coming. Tips are appreciated. Gold is appreciated more.",
		"/wave",
	}, "\n")] = true,
}

local OLD_SAMPLE_QUIPS = {
	[table.concat({
		"// A quip sends one random line each time. Try a macro with: /ws quip Sample Quip",
		"Here we go. Stay behind me and try not to stand in anything glowing.",
		"/y For glory! Or at least for loot!",
		"I have a plan. It's mostly running at them.",
		"Healer, I apologize in advance.",
		"/e cracks their knuckles and charges in.",
		"Everyone ready? Doesn't matter, I'm going!",
		"Pull now, think later.",
	}, "\n")] = true,
	[table.concat({
		"// A quip sends one random line each time. Try a macro with: /ws quip Sample Quip",
		"// {roar} and friends do the emote along with the line.",
		"Here we go. Stay behind me and try not to stand in anything glowing.",
		"/y {roar} For glory! Or at least for loot!",
		"{flex} I have a plan. It's mostly running at them.",
		"{nervous} Healer, I apologize in advance.",
		"/e cracks their knuckles and charges in.",
		"{cheer} Everyone ready? Doesn't matter, I'm going!",
		"Pull now, think later.",
	}, "\n")] = true,
}

local SAMPLE_TOUR = table.concat({
	"// Lines starting with // are notes to yourself and are never sent.",
	"// Plain lines go to this speech's default channel (Say). Turn on Rehearse to try it safely.",
	"// An emote in {braces} happens along with its line, like the {wave} below.",
	"## Welcome",
	"Welcome, welcome! {wave} Gather round, everyone. I'm %p, and I'll be your guide through %z today.",
	"/e straightens their collar and clears their throat importantly.",
	"/bow",
	"A few ground rules: stay with the group, keep your hands inside the tour, and please do not feed the guards.",
	"/wait 4",
	"## First Stop",
	"/pause Wait here until everyone catches up.",
	"If you'll follow me, %t, our first stop is %sz. {point}",
	"/e gestures grandly at the nearest building.",
	"Built long ago by people who were, frankly, very good at building things.",
	"/p Party only: if anyone asks, the gift shop is closed.",
	"## Questions",
	"Now, are there any questions? Yes, you in the back. No? Just stretching? Lovely.",
	"/pause Answer any questions, then press Play.",
	"## The Grand Finale",
	"/y {cheer} And THAT concludes our tour of %z!",
	"Thank you all for coming. {bow} Tips are appreciated. Gold is appreciated more.",
	"/wave",
}, "\n")

local SAMPLE_QUIP = table.concat({
	"// A quip sends one random line each time. Try a macro with: /ws quip Sample Quip",
	"// {roar} and friends do the emote along with the line.",
	"// %tank, %healer and %dps name your group by role. %rhealer and friends pick one at random.",
	"Here we go. Stay behind me and try not to stand in anything glowing.",
	"/y {roar} For glory! Or at least for loot!",
	"{flex} I have a plan. It's mostly running at them.",
	"{nervous} %rhealer, I apologize in advance.",
	"%tank, you go first. I'll be right behind you. Way behind you.",
	"%dps, save the big cooldowns for the boss. Or don't, I'm not your mom.",
	"/e cracks their knuckles and charges in.",
	"{cheer} Everyone ready? Doesn't matter, I'm going!",
	"{point} %rdps, you're on interrupts. Congratulations.",
	"Pull now, think later.",
}, "\n")

-- each sample is added once, so deleting one keeps it deleted
local function seedSamples()
	if not db.seeded then
		db.seeded = true
		ns.CreateSpeech({ name = "Sample Tour", tags = { "Example", "Tour" }, text = SAMPLE_TOUR })
	end
	if not db.seededQuip then
		db.seededQuip = true
		ns.CreateSpeech({
			name = "Sample Quip: Pull Lines",
			tags = { "Example", "Dungeon" },
			kind = "quip",
			text = SAMPLE_QUIP,
		})
	end
	for _, speech in pairs(db.speeches) do
		if OLD_SAMPLE_TOURS[speech.text] then
			speech.text = SAMPLE_TOUR
		elseif OLD_SAMPLE_QUIPS[speech.text] then
			speech.text = SAMPLE_QUIP
		end
	end
end

function ns.InitDatabase()
	WorthSayingDB = WorthSayingDB or {}
	db = WorthSayingDB
	migrate(db)
	applyDefaults(db, ns.Defaults)
	seedSamples()
	return db
end

function ns.GetSettings()
	return db.settings
end

function ns.GetLastSeenVersion()
	return db.lastSeenVersion
end

function ns.SetLastSeenVersion(version)
	db.lastSeenVersion = version
end

local function normalizeSpeech(speech)
	speech.name = speech.name and ns.Trim(speech.name) ~= "" and ns.Trim(speech.name) or "Untitled"
	speech.text = speech.text or ""
	speech.tags = speech.tags or {}
	speech.kind = speech.kind == "quip" and "quip" or "speech"
	speech.channel = ns.CHAT_TYPES[speech.channel] and speech.channel or "SAY"
	speech.triggers = speech.triggers or {}
	speech.uses = speech.uses or 0
	return speech
end

function ns.CreateSpeech(fields)
	local id = db.nextId
	db.nextId = id + 1
	local speech = deepCopy(fields or {})
	speech.id = id
	speech.created = time()
	speech.modified = speech.created
	speech.uses = 0
	speech.lastUsed = nil
	db.speeches[id] = normalizeSpeech(speech)
	return db.speeches[id]
end

function ns.GetSpeech(id)
	return id and db.speeches[id]
end

function ns.GetAllSpeeches()
	local list = {}
	for _, speech in pairs(db.speeches) do
		list[#list + 1] = speech
	end
	return list
end

function ns.CountSpeeches()
	local n = 0
	for _ in pairs(db.speeches) do
		n = n + 1
	end
	return n
end

function ns.TouchSpeech(speech)
	speech.modified = time()
	ns.InvalidateParse(speech.id)
end

function ns.DeleteSpeech(id)
	db.speeches[id] = nil
	ns.InvalidateParse(id)
	if ns.OnSpeechDeleted then
		ns.OnSpeechDeleted(id)
	end
end

function ns.DuplicateSpeech(id)
	local source = db.speeches[id]
	if not source then
		return
	end
	local copy = deepCopy(source)
	copy.name = source.name .. " (copy)"
	return ns.CreateSpeech(copy)
end

-- the tour is offered once per account
function ns.WasTourOffered()
	return db.tourOffered == true
end

function ns.MarkTourOffered()
	db.tourOffered = true
end

-- a version's "what's new" tour button glows until it's been shown once
function ns.WasFeatureTourSeen(version)
	return db.seenFeatureTours ~= nil and db.seenFeatureTours[version] == true
end

function ns.MarkFeatureTourSeen(version)
	db.seenFeatureTours = db.seenFeatureTours or {}
	db.seenFeatureTours[version] = true
end

function ns.MarkSpeechUsed(speech)
	speech.uses = (speech.uses or 0) + 1
	speech.lastUsed = time()
end

function ns.GetAllTags()
	local byLower, list = {}, {}
	for _, speech in pairs(db.speeches) do
		for _, tag in ipairs(speech.tags) do
			local lower = tag:lower()
			if not byLower[lower] then
				byLower[lower] = tag
				list[#list + 1] = tag
			end
		end
	end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

function ns.SpeechHasTag(speech, tag)
	local want = tag:lower()
	for _, t in ipairs(speech.tags) do
		if t:lower() == want then
			return true
		end
	end
	return false
end

function ns.ImportSpeech(fields)
	local clean = {
		name = fields.name,
		text = fields.text,
		tags = fields.tags,
		kind = fields.kind,
		channel = fields.channel,
		delay = tonumber(fields.delay),
		playHidden = fields.playHidden == true or nil,
		triggers = fields.triggers,
	}
	return ns.CreateSpeech(clean)
end

function ns.RememberInstance(info)
	if info and info.id then
		db.knownInstances[info.id] = { name = info.name, instanceType = info.instanceType }
	end
end

function ns.GetRememberedInstances()
	return db.knownInstances
end

local UI_SETTING_KEYS = {
	"windowAlpha", "uiScale", "columnWidths", "columnVisibility", "columnOrder", "windowPositions",
	"minimapIcon", "listSplit",
}

function ns.ResetUISettings()
	local settings, defaults = db.settings, ns.Defaults.settings
	for _, key in ipairs(UI_SETTING_KEYS) do
		settings[key] = deepCopy(defaults[key])
	end
	settings.windowPoint, settings.windowRelativePoint, settings.windowX, settings.windowY = nil, nil, nil, nil
	settings.windowWidth, settings.windowHeight = nil, nil
	settings.presenter.scale = defaults.presenter.scale
	settings.presenter.alpha = defaults.presenter.alpha
	settings.presenter.locked = false
end

function ns.ResetAllSettings()
	db.settings = deepCopy(ns.Defaults.settings)
end

function ns.DeleteAllSpeeches()
	wipe(db.speeches)
	ns.InvalidateParse()
end
