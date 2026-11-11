local ns = WorthSaying

local exportPopup, importPopup

local function buildExport()
	exportPopup = ns.CreatePopupFrame("WSExportPopup", 480, 300, "Export", "export")
	exportPopup.info = ns.CreateLabel(exportPopup, "", "GameFontHighlightSmall")
	exportPopup.info:SetPoint("TOPLEFT", 20, -46)
	exportPopup.info:SetPoint("RIGHT", -20, 0)
	exportPopup.info:SetWordWrap(true)

	local holder = ns.CreateMultiLineEditBox(exportPopup, GameFontHighlightSmall)
	holder:SetPoint("TOPLEFT", 16, -76)
	holder:SetPoint("BOTTOMRIGHT", -16, 46)
	exportPopup.holder = holder
	holder.editBox:HookScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(exportPopup.payload or "")
			self:HighlightText()
		end
	end)
	holder.editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

	local closeButton = ns.CreateButton(exportPopup, "Close", 80, 22, function() exportPopup:Hide() end)
	closeButton:SetPoint("BOTTOMRIGHT", -16, 16)
end

function ns.ShowExport(speeches)
	if not exportPopup then
		buildExport()
	end
	local payload = ns.ExportSpeeches(speeches)
	exportPopup.payload = payload
	local names = {}
	for i, speech in ipairs(speeches) do
		if i > 5 then
			names[#names + 1] = "and " .. (#speeches - 5) .. " more"
			break
		end
		names[#names + 1] = speech.name
	end
	exportPopup.info:SetText((#speeches == 1 and "1 speech: " or (#speeches .. " speeches: ")) .. table.concat(names, ", ")
		.. "\nPress Ctrl+C to copy, then share it anywhere.")
	exportPopup:Show()
	local edit = exportPopup.holder.editBox
	edit:SetText(payload)
	edit:SetFocus()
	edit:HighlightText()
end

local function updateImportPreview()
	local text = importPopup.holder.editBox:GetText()
	if ns.Trim(text) == "" then
		importPopup.info:SetText("Paste a Worth Saying export string below (Ctrl+V).")
		importPopup.info:SetTextColor(0.8, 0.8, 0.8)
		importPopup.importButton:SetEnabled(false)
		importPopup.decoded = nil
		return
	end
	local list, err = ns.DecodeImport(text)
	importPopup.decoded = list
	if not list then
		importPopup.info:SetText(err)
		importPopup.info:SetTextColor(1, 0.4, 0.4)
		importPopup.importButton:SetEnabled(false)
		return
	end
	local names = {}
	for i, speech in ipairs(list) do
		if i > 5 then
			names[#names + 1] = "and " .. (#list - 5) .. " more"
			break
		end
		names[#names + 1] = speech.name
	end
	importPopup.info:SetText("Ready to import " .. (#list == 1 and "1 speech: " or (#list .. " speeches: ")) .. table.concat(names, ", "))
	importPopup.info:SetTextColor(0.55, 0.9, 0.55)
	importPopup.importButton:SetEnabled(true)
end

local function buildImport()
	importPopup = ns.CreatePopupFrame("WSImportPopup", 480, 300, "Import", "import")
	importPopup.info = ns.CreateLabel(importPopup, "", "GameFontHighlightSmall")
	importPopup.info:SetPoint("TOPLEFT", 20, -46)
	importPopup.info:SetPoint("RIGHT", -20, 0)
	importPopup.info:SetWordWrap(true)

	local holder = ns.CreateMultiLineEditBox(importPopup, GameFontHighlightSmall)
	holder:SetPoint("TOPLEFT", 16, -76)
	holder:SetPoint("BOTTOMRIGHT", -16, 46)
	holder.editBox:HookScript("OnTextChanged", updateImportPreview)
	importPopup.holder = holder

	importPopup.importButton = ns.CreateButton(importPopup, "Import", 80, 22, function()
		local list = importPopup.decoded
		if not list then
			return
		end
		local last
		for _, fields in ipairs(list) do
			last = ns.ImportSpeech(fields)
		end
		ns.Print("Imported " .. #list .. (#list == 1 and " speech." or " speeches."))
		importPopup:Hide()
		if last then
			ns.SelectSpeech(last.id)
		end
		ns.RefreshAll()
	end)
	importPopup.importButton:SetPoint("BOTTOMRIGHT", -16, 16)
	local cancel = ns.CreateButton(importPopup, "Cancel", 80, 22, function() importPopup:Hide() end)
	cancel:SetPoint("RIGHT", importPopup.importButton, "LEFT", -6, 0)
end

function ns.ShowImport()
	if not importPopup then
		buildImport()
	end
	importPopup:Show()
	importPopup.holder.editBox:SetText("")
	importPopup.holder.editBox:SetFocus()
	updateImportPreview()
end
