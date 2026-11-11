local ns = WorthSaying

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, loadedAddon)
	if event == "ADDON_LOADED" and loadedAddon == ns.name then
		ns.InitDatabase()
		return
	end

	if event == "PLAYER_LOGIN" then
		ns.Print("loaded. /ws to open the window, /ws help for commands.")

		local ok, err = pcall(ns.EnsureMinimapButton)
		if not ok then
			ns.Print("Minimap button failed to load: " .. tostring(err))
		end

		local version = ns.GetAddonVersion()
		local lastSeen = ns.GetLastSeenVersion()
		if version and version ~= lastSeen then
			ns.UpdatedFromVersion = lastSeen
			ns.SetLastSeenVersion(version)
			if lastSeen and ns.GetSettings().showPatchNotesOnUpdate then
				C_Timer.After(1, function()
					local shown, showErr = pcall(ns.SelectAboutTab)
					if not shown then
						ns.Print("Patch notes failed to open: " .. tostring(showErr))
					end
				end)
			end
		end
	end
end)
