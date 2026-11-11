local ns = WorthSaying

function ns.FindSpeechByName(query)
	query = ns.Trim(query):lower()
	if query == "" then
		return nil
	end
	local all = ns.GetAllSpeeches()
	table.sort(all, function(a, b) return a.name:lower() < b.name:lower() end)
	for _, speech in ipairs(all) do
		if speech.name:lower() == query then
			return speech
		end
	end
	local prefixHit, prefixCount = nil, 0
	for _, speech in ipairs(all) do
		if speech.name:lower():sub(1, #query) == query then
			prefixHit = prefixHit or speech
			prefixCount = prefixCount + 1
		end
	end
	if prefixHit then
		return prefixHit
	end
	for _, speech in ipairs(all) do
		if speech.name:lower():find(query, 1, true) then
			return speech
		end
	end
end

local function printUsage()
	ns.Print("commands:")
	print("  /ws                 - open or close the main window")
	print("  /ws present [name]  - open the presenter, optionally with a speech")
	print("  /ws play <name>     - load a speech and start auto-play")
	print("  /ws next            - send the next line (works in macros)")
	print("  /ws back | skip     - step back one line, or skip one")
	print("  /ws pause | stop    - pause auto-play, or stop and rewind")
	print("  /ws quip <name>     - send one random line from a speech (works in macros)")
	print("  /ws rehearse        - toggle rehearse mode (lines print only to you)")
	print("  /ws options         - open Options")
end

local function withSpeech(name, fn)
	local speech = ns.FindSpeechByName(name or "")
	if not speech then
		ns.Print("No speech named \"" .. ns.Trim(name or "") .. "\".")
		return
	end
	fn(speech)
end

local function handler(msg)
	local cmd, rest = ns.Trim(msg):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()

	if cmd == "" then
		ns.ToggleMainWindow()
	elseif cmd == "help" or cmd == "?" then
		printUsage()
	elseif cmd == "present" or cmd == "presenter" then
		if rest ~= "" then
			withSpeech(rest, function(speech)
				ns.LoadSpeech(speech.id, {})
				ns.ShowPresenter()
			end)
		else
			ns.TogglePresenter()
		end
	elseif cmd == "play" then
		withSpeech(rest, function(speech)
			ns.LoadSpeech(speech.id, {})
			ns.ShowPresenter()
			ns.Play()
		end)
	elseif cmd == "next" or cmd == "n" then
		ns.Next()
	elseif cmd == "back" or cmd == "b" then
		ns.Back()
	elseif cmd == "skip" then
		ns.Skip()
	elseif cmd == "pause" then
		ns.Pause()
	elseif cmd == "stop" then
		ns.Stop()
	elseif cmd == "quip" or cmd == "random" then
		withSpeech(rest, ns.SendRandomLine)
	elseif cmd == "rehearse" then
		local presenter = ns.GetSettings().presenter
		presenter.rehearse = not presenter.rehearse
		ns.Print("Rehearse mode " .. (presenter.rehearse and "on: lines only print to your chat window." or "off."))
		if ns.RefreshPresenter then
			ns.RefreshPresenter()
		end
	elseif cmd == "options" or cmd == "config" then
		ns.SelectOptionsTab()
	else
		printUsage()
	end
end

SLASH_WORTHSAYING1 = "/ws"
SLASH_WORTHSAYING2 = "/worthsaying"
SlashCmdList.WORTHSAYING = handler
