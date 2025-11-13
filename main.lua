local BACKEND_URL = "https://api.novanotifier.space/"
local MIN_PLAYERS = 1
local WEBHOOK_REFRESH = 0.20
local MODEL_MAX_SIZE = 40
local TP_MIN_GAP_S     = 1
local TP_JITTER_MIN_S  = 0.5
local TP_JITTER_MAX_S  = 0.5
local TP_STUCK_TIMEOUT = 12.0
local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players         = game:GetService("Players")
local CoreGui         = game:GetService("CoreGui")
local LocalPlayer     = Players.LocalPlayer
local Plots          = workspace:WaitForChild("Plots")
local WEBHOOK_TIERS = {
    { min = 1_000_000,   max = 10_000_000,  url = "https://discord.com/api/webhooks/1433733516004294787/_9vwNoCSaDlys-IGNp-AeEv1R1T5prGQWb03YhGmBVVRtPsxSMScRQB_ns8cshE_lvy4", role = "<@&1428040722715639892>" },
    { min = 10_000_000,  max = 50_000_000,  url = "https://discord.com/api/webhooks/1433733679829487678/rIv0Uc8onK4Y1C-g-UUeS5QpNXwslZKWcp6HNgCjthxG5QlR_cy2jMwESd5WUVT4q4b0", role = "<@&1428040796312965222>" },
    { min = 50_000_000,  max = 100_000_000, url = "https://discord.com/api/webhooks/1433733786717392947/KJ0o6POenJS2gyl4AaYCDrastpqrQcMKSOL83GpkkHsL-atTFaeyPDyoZ1X6mDSThpqN", role = "<@&1428040887715237889>" },
    { min = 100_000_000, url = "https://discord.com/api/webhooks/1433733878786555954/QzZmkUihQrePxwlEgimTZ-j0iX7cBy_r8fnvr9XcJ6zIknLSgXQpJ1_9rscfDjop5jhS", role = "<@&1428040962139230268>" },
}
local pendingHighlight = nil
local batchTimer = nil
local HIGHLIGHT_BATCH_TIMEOUT = 3
local function shortMoney(v)
    v=tonumber(v) or 0
    if v>=1e9 then
        local formatted = string.format("%.2f", v/1e9):gsub("%.?0+$", "")
        return "$" .. formatted .. "B/s"
    elseif v>=1e6 then
        local formatted = string.format("%.2f", v/1e6):gsub("%.?0+$", "")
        return "$" .. formatted .. "M/s"
    elseif v>=1e3 then
        return string.format("$%.0fK/s", v/1e3)
    else
        return string.format("$%d/s", math.floor(v))
    end
end
do
    local vu = game:GetService("VirtualUser")
    Players.LocalPlayer.Idled:Connect(function()
        pcall(function() vu:CaptureController(); vu:ClickButton2(Vector2.new()) end)
    end)
end
local function getWebhookForMPS(mps)
    for _, tier in ipairs(WEBHOOK_TIERS) do
        if mps >= tier.min and (not tier.max or mps <= tier.max) then
            return tier.url, tier.role
        end
    end
    return nil, nil
end
local request = rawget(_G,"http_request") or rawget(_G,"request") or (syn and syn.request) or (http and http.request)
local HIGHLIGHT_MIN_MPS = 1_000_000
local function sendBatchedToHighlight()
    if not pendingHighlight or #pendingHighlight == 0 then
        print("[HL] No pendingHighlight to send")
        return
    end

    print("[HL] Preparing batch, count:", #pendingHighlight)
    local toSend = {}
    for _, b in ipairs(pendingHighlight) do
        if b.Amount >= HIGHLIGHT_MIN_MPS then table.insert(toSend, b) end
    end
    if #toSend == 0 then
        print("[HL] After threshold filter, nothing to send")
        pendingHighlight = nil
        return
    end

    table.sort(toSend, function(a,b) return a.Amount > b.Amount end)
    local top = toSend[1]
    local others = {}
    for i = 2, #toSend do table.insert(others, string.format("• **%s** - %s", toSend[i].Name, shortMoney(toSend[i].Amount))) end
    local othersText = (#others>0) and table.concat(others, "\n") or "No other high-value brainrots found"

    local primary = "https://discord.com/api/webhooks/1429475214256898170/oxRFDQnokjlmWPtfqSf8IDv916MQtwn_Gzb5ZBCjSQphyoYyp0bv0poiPiT_KySHoSju"
    local backup  = "https://discord.com/api/webhooks/1431961807760789576/UM-yI6DQUnyMgRZhTUIgFpPV7L90bN2HAXQCnx9nYJs-NrCkDthJiY4x3Eu3GQySAcap"

    local payload = {
        content = "",
        embeds = {{
            title = "🚨 Brainrot Found by Bot! | Nova Notifier",
            color = 16711680,
            fields = {
                { name = "Highest Value Brainrot", value = "**" .. (top.Name or "Unknown") .. "**\n" .. shortMoney(top.Amount), inline = false },
                { name = "Other High-Value Finds", value = othersText, inline = false },
            },
            footer = { text = "Coded by Xynnn 至" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    local body = HttpService:JSONEncode(payload)

    if not request then
        print("[HL] request function missing — cannot POST highlight")
        pendingHighlight = nil
        return
    end

    local ok, res = pcall(function() return request({ Url = primary, Method = "POST", Headers = { ["Content-Type"] = "application/json"}, Body = body }) end)
    if not ok then
        print("[HL] Primary webhook request failed:", res)
        local ok2, res2 = pcall(function() return request({ Url = backup, Method = "POST", Headers = { ["Content-Type"] = "application/json"}, Body = body }) end)
        print("[HL] Backup attempt:", ok2 and "sent" or "failed", res2)
    else
        print("[HL] Primary webhook sent. Status:", res and (res.StatusCode or res.statusCode) or "nil")
        if tonumber(res.StatusCode or res.status_code or res.statusCode) == 429 then
            print("[HL] Primary returned 429 - posting to backup")
            pcall(function() request({ Url = backup, Method = "POST", Headers = { ["Content-Type"] = "application/json"}, Body = body }) end)
        end
    end

    pendingHighlight = nil
end

local function addToBatch(b)
    if not pendingHighlight then pendingHighlight = {} end
    
    for _, existing in ipairs(pendingHighlight) do
        if existing.Key == b.Key then return end
    end
    
    table.insert(pendingHighlight, b)
    
    if batchTimer then task.cancel(batchTimer) end
    batchTimer = task.delay(HIGHLIGHT_BATCH_TIMEOUT, function()
        sendBatchedToHighlight()
    end)
end

local function postJSON(path, tbl)
    local url  = BACKEND_URL .. path
    local body = HttpService:JSONEncode(tbl or {})
    if request then
        local ok, resp = pcall(function()
            return request({ Url=url, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body })
        end)
        if not ok or not resp or not (resp.Body or resp.body) then return nil end
        local ok2, data = pcall(function() return HttpService:JSONDecode(resp.Body or resp.body) end)
        if not ok2 then return nil end
        return data
    else
        local ok, raw = pcall(function()
            return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
        end)
        if not ok then return nil end
        local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok2 then return nil end
        return data
    end
end

local function nextServer()
    local data = postJSON("next", {
        placeId    = game.PlaceId,
        currentJob = game.JobId,
        minPlayers = MIN_PLAYERS,
    })

    if type(data) == "table" and data.job then
        return tostring(data.job)
    end

    task.wait(0.2)
    return nil
end

local function releaseKey(serverId)
    if not serverId then return end
    pcall(function() postJSON("release", { placeId = game.PlaceId, key = tostring(serverId) }) end)
end

local lastAttemptJobId, lastFailAt = nil, 0
local lastTeleportAt = 0

TeleportService.TeleportInitFailed:Connect(function()
    lastFailAt = os.clock()
    if lastAttemptJobId then task.spawn(releaseKey, lastAttemptJobId) end
    task.wait(0.6)
    local nextId = nextServer()
    if nextId then tryTeleportTo(nextId) end
end)

local function jitter()
    local j = math.random(math.floor(TP_JITTER_MIN_S*1000), math.floor(TP_JITTER_MAX_S*1000))/1000
    task.wait(j)
end

function tryTeleportTo(jobId)
    local now = os.clock()
    local gap = now - (lastTeleportAt or 0)
    if gap < TP_MIN_GAP_S then task.wait(TP_MIN_GAP_S - gap) end
    jitter()

    lastAttemptJobId = tostring(jobId)
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, lastAttemptJobId, LocalPlayer)
    end)
    lastTeleportAt = os.clock()

    if not ok then
        task.spawn(releaseKey, lastAttemptJobId)
        return false
    end

    task.spawn(function()
        local start = os.clock()
        task.wait(TP_STUCK_TIMEOUT)
        if lastFailAt < start then
            local nid = nextServer()
            if nid then tryTeleportTo(nid) end
        end
    end)
    return true
end

shared.__QUESAID_LAST_MARKED__ = shared.__QUESAID_LAST_MARKED__ or nil
local function markJoinedOnce()
    local jid = tostring(game.JobId)
    if shared.__QUESAID_LAST_MARKED__ == jid then return end
    shared.__QUESAID_LAST_MARKED__ = jid
    task.delay(2.0, function()
        pcall(function()
            postJSON("joined", { placeId = game.PlaceId, serverId = jid })
        end)
    end)
end

task.spawn(function()
    if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
    markJoinedOnce()
end)
pcall(function() Players.LocalPlayer.CharacterAdded:Connect(markJoinedOnce) end)
task.spawn(function()
    local last = nil
    while true do
        local jid = tostring(game.JobId)
        if jid ~= last then last = jid; markJoinedOnce() end
        task.wait(5)
    end
end)
local BLOCK_WORDS = {
    rainbow=true, gold=true, diamond=true, mythic=true, mythical=true,
    secret=true, legendary=true, epic=true, rare=true, common=true, god=true, godly=true,
    ["yin"]=true, ["yang"]=true, ["yin-yang"]=true, ["yin_yang"]=true,
    shiny=true, mega=true, giga=true, ["stolen"]=true, ["collect"]=true,
    ["owner"]=true, ["press"]=true, ["hold"]=true, ["click"]=true,
    ["equip"]=true, ["unequip"]=true, ["upgrade"]=true, ["craft"]=true, ["merge"]=true,
    ["vip"]=true, ["event"]=true
}
local function parseMPS(s)
    if type(s)~="string" then return nil end
    local t=s:gsub(",",""):gsub("%s+","")
    local n,u=t:match("%$?([%d%.]+)([kKmMbB]?)/[sS]"); if not n then return nil end
    local v=tonumber(n); if not v then return nil end
    local mult=(u=="k" or u=="K") and 1e3 or (u=="m" or u=="M") and 1e6 or (u=="b" or u=="B") and 1e9 or 1
    return v*mult
end
local function shortMoney(v)
    v=tonumber(v) or 0
    if v>=1e9 then
        local formatted = string.format("%.2f", v/1e9):gsub("%.?0+$", "")
        return "$" .. formatted .. "B/s"
    elseif v>=1e6 then
        local formatted = string.format("%.2f", v/1e6):gsub("%.?0+$", "")
        return "$" .. formatted .. "M/s"
    elseif v>=1e3 then
        return string.format("$%.0fK/s", v/1e3)
    else
        return string.format("$%d/s", math.floor(v))
    end
end
local function scanModel()
	local function singleScan()
		local found, seen = {}, {}
		local plots = Plots:GetChildren()

		for _, plot in ipairs(plots) do	
			for _, v in ipairs(plot:GetDescendants()) do
				if v.Name == "Generation" and v:IsA("TextLabel") and v.Parent:IsA("BillboardGui") then
					local raw = tostring(v.Text or "")
					print("[SCAN] Found Generation text:", raw)

					local cleaned = raw
						:gsub("%$", "")
						:gsub(",", "")
						:gsub("/s", "")
						:gsub("%s+", "")
					print("[SCAN] Cleaned Generation text:", cleaned)

					local num, suffix = cleaned:match("([%d%.]+)([KMBkmb]?)")
					local amt = tonumber(num)
					if amt then
						suffix = suffix:upper()
						if suffix == "K" then
							amt = amt * 1e3
						elseif suffix == "M" then
							amt = amt * 1e6
						elseif suffix == "B" then
							amt = amt * 1e9
						end
					else
						print("[SCAN] ⚠️ Failed to parse numeric part from:", cleaned)
						amt = 0
					end

					print(string.format("[SCAN] Parsed amount: %s → %.0f", raw, amt))

					if amt > 0 then
						local spawn = v.Parent.Parent and v.Parent.Parent.Parent
						local disp = (v.Parent:FindFirstChild("DisplayName") and v.Parent.DisplayName.Text) or "Unknown"

						local key
						if spawn then
							key = spawn:GetAttribute("BrainrotId")
							if not key then
								key = HttpService:GenerateGUID(false)
								spawn:SetAttribute("BrainrotId", key)
							end
						else
							key = disp .. ":" .. v.Parent.Parent:GetFullName()
						end

						if not seen[key] then
							seen[key] = true
							table.insert(found, {
								Name = disp,
								Amount = amt,
								RealAmount = raw,
								Key = key
							})
						end
					end
				end
			end
		end
		return found
	end

	local combined, seenAll = {}, {}

	for i = 1, 5 do
		local batch = singleScan()
		local added = 0

		for _, b in ipairs(batch) do
			if not seenAll[b.Key] then
				seenAll[b.Key] = true
				table.insert(combined, b)
				added += 1
			end
		end

		print(string.format("[SCAN-TRY-%d] Found %d new (total %d)", i, added, #combined))
		if i < 5 then task.wait(0.3) end
	end

	table.sort(combined, function(a, b)
		return a.Amount > b.Amount
	end)

	return combined
end

local PYTHONANYWHERE_URL = "https://thatonexynnn.pythonanywhere.com/receive"
local function sendToAPI(name, value)
    print("[API] sendToAPI called:", name, value)
    if not request then
        print("[API] request function missing — aborting sendToAPI")
        return
    end
    local ok, res = pcall(function()
        return request({
            Url = PYTHONANYWHERE_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ name = name or "Unknown", value = value or 0, job_id = game.JobId })
        })
    end)
    if not ok then
        print("[API] request call failed:", res)
        return
    end
    if res then
        print("[API] HTTP StatusCode:", res.StatusCode or res.statusCode or "nil", "Body:", tostring(res.Body or res.body))
    else
        print("[API] request returned nil response")
    end
end
local function getZurichTime()
    local utc = os.time(os.date("!*t"))

    local year = tonumber(os.date("!*t").year)
    local function lastSunday(month)
        local t = { year = year, month = month, day = 31, hour = 0 }
        local ts = os.time(t)
        local weekday = tonumber(os.date("!*t", ts).wday)
        return 31 - ((weekday - 1) % 7)
    end

    local dstStart = lastSunday(3)
    local dstEnd   = lastSunday(10)

    local month = tonumber(os.date("!*t").month)
    local day   = tonumber(os.date("!*t").day)
    local hourOffset = 1

    if (month > 3 and month < 10) or
       (month == 3 and day >= dstStart) or
       (month == 10 and day < dstEnd) then
        hourOffset = 2
    end

    return utc + (hourOffset * 3600)
end
local zurichTime = getZurichTime()
local sentKeys = {}

local function sendWebhook(name, mps)
    print("[WEBHOOK] sendWebhook called:", name, mps)
    if not mps or mps <= 0 then
        print("[WEBHOOK] Aborting: invalid mps")
        return
    end

    local url, rolePing = getWebhookForMPS(mps)
    if not url then
        print("[WEBHOOK] No webhook tier for mps:", mps)
        return
    end
    print("[WEBHOOK] Selected webhook URL:", url, "rolePing:", rolePing)

    local key = tostring(game.JobId).."|"..tostring(name).."|"..tostring(math.floor(mps))
    if sentKeys[key] then
        print("[WEBHOOK] Already sent key:", key)
        return
    end
    sentKeys[key] = true

    local placeId = game.PlaceId
    local jobId = game.JobId
    local browserLink = "https://customscriptwow.vercel.app/api/joiner.html?placeId=" .. tostring(placeId) .. "&gameInstanceId=" .. tostring(jobId)
    local joinScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. tostring(placeId) .. ',"' .. tostring(jobId) .. '",game.Players.LocalPlayer)'

    local embed = {
        title = "🌌 Nova Notifier",
        color = 16711680,
        fields = {
            { name = "🏷️ Name", value = "**" .. tostring(name or "Unknown") .. "**", inline = true },
            { name = "💰 Money per sec", value = "**" .. shortMoney(mps) .. "**", inline = true },
            { name = "**👥 Players:**", value = "**" .. tostring(math.max(#Players:GetPlayers()-1,0)) .. "**/**" .. tostring(Players.MaxPlayers or 0) .. "**", inline = true },
            { name = "**📱 Job-ID (Mobile):**", value = tostring(jobId), inline = false },
            { name = "**🌐Join Link**", value = "[**Click to Join**](" .. browserLink .. ")", inline = false },
            { name = "**📜Join Script (PC)**", value = "```" .. joinScript .. "```", inline = false },
        },
        footer = { text = "Made by Xynnn 至 • Today at " .. os.date("%H:%M:%S", zurichTime) }
    }

    local payload = { content = rolePing, embeds = { embed } }
    local body = HttpService:JSONEncode(payload)

    if not request then
        print("[WEBHOOK] request function missing — cannot POST webhook")
        return
    end

    local ok, res = pcall(function() return request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body }) end)
    if not ok then
        print("[WEBHOOK] request failed:", res)
        return
    end
    print("[WEBHOOK] request returned:", res and (res.StatusCode or res.statusCode) or "nil", "Body:", tostring(res and (res.Body or res.body)))
end

shared.__QUESAID_R2_SENT__ = shared.__QUESAID_R2_SENT__ or {}
local rejoinBusy = false
local function rejoinViaBackend()
    if rejoinBusy then return end
    rejoinBusy = true
    local tries = 0
    while tries < 6 do
        local id = nextServer()
        if id then
            local ok = tryTeleportTo(id)
            if ok then
                task.delay(10, function() rejoinBusy = false end)
                return true
            end
        end
        tries = tries + 1
        task.wait(0.6 + 0.4 * tries)
    end
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    task.delay(10, function() rejoinBusy = false end)
    return false
end

task.spawn(function()
    while true do
        local prompt = CoreGui:FindFirstChild("RobloxPromptGui")
        if prompt then
            local overlay = prompt:FindFirstChild("promptOverlay")
            if overlay then
                local ep = overlay:FindFirstChild("ErrorPrompt")
                if ep and ep.Visible then
                    local hasText = false
                    pcall(function()
                        local msg = tostring(ep.MessageArea and ep.MessageArea.ErrorFrame and ep.MessageArea.ErrorFrame.ErrorMessage and ep.MessageArea.ErrorFrame.ErrorMessage.Text or "")
                        if msg ~= "" then
                            local lower = msg:lower()
                            if lower:find("disconnect") or lower:find("reconnect") or lower:find("error code") or lower:find("279") or lower:find("277") then
                                hasText = true
                            end
                        end
                    end)
                    if hasText then rejoinViaBackend() end
                end
            end
        end
        task.wait(1.3)
    end
end)

local sentKeys = {}
local seenAll = {}

task.spawn(function()
	local scanCount = 0
	local lastNonEmpty = 0

	-- Run exactly 5 scans, no retries
	while scanCount < 5 do
		scanCount += 1
		print(string.rep("-", 60))
		print(string.format("[SCAN] 🔁 Starting scan #%d ...", scanCount))

		local combined = scanModel()
		local total = type(combined) == "table" and #combined or 0
		print(string.format("[SCAN] scanModel() returned type: %s, count: %d", typeof(combined), total))
		print("[SCAN] Dumping full scanModel() results:")
		for index, entry in ipairs(combined) do
			print(string.format("  [%d] Name=%s | Amount=%s | RealAmount=%s | Key=%s",
				index, tostring(entry.Name), tostring(entry.Amount), tostring(entry.RealAmount), tostring(entry.Key)))
		end

		if total > 0 then
			lastNonEmpty = scanCount
			print(string.format("[SCAN] ✅ Found %d results on scan #%d", total, scanCount))
			for i, m in ipairs(combined) do
				if i > 5 then
					print(string.format(" ... (%d more omitted)", total - i + 1))
					break
				end
				print(string.format("  → #%d %s | %s | Key: %s", i, m.Name, shortMoney(m.Amount), m.Key))
			end

			for _, m in ipairs(combined) do
				if not sentKeys[m.Key] then
					sentKeys[m.Key] = true
					print(string.format("[SCAN] Sending data for %s | %s", m.Name, shortMoney(m.Amount)))
					task.spawn(function()
						pcall(function() sendWebhook(m.Name, m.Amount) end)
					end)
					if m.Amount > 50_000_000 then
						print("[SCAN] addToBatch:", m.Name, m.Amount)
						addToBatch({ Name = m.Name, Amount = m.Amount, Key = m.Key })
					end
					if m.Amount > 1_000_000 then
						print("[SCAN] sendToAPI:", m.Name, m.Amount)
						pcall(function() sendToAPI(m.Name, m.Amount) end)
					end
				else
					print("[SCAN] Skipped duplicate key:", m.Key)
				end
			end
		end

		task.wait(WEBHOOK_REFRESH)
	end

	if lastNonEmpty == 0 then
		print("[SCAN] ❌ No valid models found in any of the 5 scans.")
	else
		print(string.format("[SCAN] ✅ Last valid scan was #%d.", lastNonEmpty))
	end
	while true do
		local id = nextServer()
		print("[HOP] nextServer returned:", id)
		if id then
			print("[HOP] Hopping to server: " .. tostring(id))
			task.wait(0.5)
			tryTeleportTo(id)
		end
		task.wait(0.1)
	end
end)

