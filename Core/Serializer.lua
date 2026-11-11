local ns = WorthSaying

local EXPORT_PREFIX = "!WS1!"
local MAX_DEPTH = 8

local function serializeValue(value, out, depth)
	local t = type(value)
	if t == "string" then
		out[#out + 1] = "s" .. #value .. ":" .. value
	elseif t == "number" then
		out[#out + 1] = "n" .. tostring(value) .. ";"
	elseif t == "boolean" then
		out[#out + 1] = value and "T" or "F"
	elseif t == "table" then
		if depth > MAX_DEPTH then
			error("table nested too deeply")
		end
		out[#out + 1] = "{"
		for k, v in pairs(value) do
			local kt = type(k)
			if (kt == "string" or kt == "number") and type(v) ~= "function" then
				serializeValue(k, out, depth + 1)
				serializeValue(v, out, depth + 1)
			end
		end
		out[#out + 1] = "}"
	end
end

local function deserialize(text)
	local pos = 1
	local readValue

	function readValue(depth)
		if depth > MAX_DEPTH then
			error("nested too deeply")
		end
		local tag = text:sub(pos, pos)
		pos = pos + 1
		if tag == "s" then
			local colon = text:find(":", pos, true)
			local len = colon and tonumber(text:sub(pos, colon - 1))
			if not len then
				error("bad string length")
			end
			local value = text:sub(colon + 1, colon + len)
			if #value ~= len then
				error("string cut short")
			end
			pos = colon + len + 1
			return value
		elseif tag == "n" then
			local semi = text:find(";", pos, true)
			local value = semi and tonumber(text:sub(pos, semi - 1))
			if not value then
				error("bad number")
			end
			pos = semi + 1
			return value
		elseif tag == "T" then
			return true
		elseif tag == "F" then
			return false
		elseif tag == "{" then
			local tbl = {}
			while text:sub(pos, pos) ~= "}" do
				if pos > #text then
					error("table not closed")
				end
				local k = readValue(depth + 1)
				local v = readValue(depth + 1)
				tbl[k] = v
			end
			pos = pos + 1
			return tbl
		end
		error("unexpected data")
	end

	local value = readValue(0)
	return value
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, 64 do
	B64_INDEX[B64:byte(i)] = i - 1
end

local function encodeBase64(data)
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

local function decodeBase64(data)
	data = data:gsub("[^%w%+/=]", "")
	local out = {}
	for i = 1, #data, 4 do
		local chunk = data:sub(i, i + 3)
		local n, pad = 0, 0
		for j = 1, 4 do
			local ch = chunk:byte(j)
			local v = ch and B64_INDEX[ch]
			if v then
				n = n * 64 + v
			else
				n = n * 64
				pad = pad + 1
			end
		end
		local a = math.floor(n / 65536) % 256
		local b = math.floor(n / 256) % 256
		local c = n % 256
		if pad >= 3 then
			break
		end
		out[#out + 1] = string.char(a)
		if pad < 2 then
			out[#out + 1] = string.char(b)
		end
		if pad < 1 then
			out[#out + 1] = string.char(c)
		end
	end
	return table.concat(out)
end

local EXPORT_FIELDS = { "name", "text", "tags", "kind", "channel", "delay", "triggers" }

function ns.ExportSpeeches(speeches)
	local payload = { v = 1, speeches = {} }
	for i, speech in ipairs(speeches) do
		local copy = {}
		for _, field in ipairs(EXPORT_FIELDS) do
			copy[field] = speech[field]
		end
		payload.speeches[i] = copy
	end
	local out = {}
	serializeValue(payload, out, 0)
	return EXPORT_PREFIX .. encodeBase64(table.concat(out))
end

function ns.DecodeImport(text)
	text = ns.Trim(text)
	if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
		return nil, "That isn't a Worth Saying export string."
	end
	local raw = decodeBase64(text:sub(#EXPORT_PREFIX + 1))
	local ok, payload = pcall(deserialize, raw)
	if not ok or type(payload) ~= "table" or type(payload.speeches) ~= "table" then
		return nil, "That export string is damaged or incomplete."
	end
	local list = {}
	for _, s in ipairs(payload.speeches) do
		if type(s) == "table" and type(s.text) == "string" then
			local tags = {}
			if type(s.tags) == "table" then
				for _, tag in ipairs(s.tags) do
					if type(tag) == "string" then
						tags[#tags + 1] = tag
					end
				end
			end
			local triggers = {}
			if type(s.triggers) == "table" then
				for _, trig in ipairs(s.triggers) do
					if type(trig) == "table" and type(trig.type) == "string" then
						triggers[#triggers + 1] = {
							type = trig.type,
							name = type(trig.name) == "string" and trig.name or nil,
							id = tonumber(trig.id),
						}
					end
				end
			end
			list[#list + 1] = {
				name = type(s.name) == "string" and s.name or "Imported",
				text = s.text,
				tags = tags,
				kind = s.kind,
				channel = s.channel,
				delay = tonumber(s.delay),
				triggers = triggers,
			}
		end
	end
	if #list == 0 then
		return nil, "That export string has no speeches in it."
	end
	return list
end
