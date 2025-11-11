local BACKEND_URL = "http://127.0.0.1:3001/"
local MIN_PLAYERS = 0

-- 10-49m/s
local WEBHOOK_URL = "https://discord.com/api/webhooks/1433733679829487678/rIv0Uc8onK4Y1C-g-UUeS5QpNXwslZKWcp6HNgCjthxG5QlR_cy2jMwESd5WUVT4q4b0"
local WEBHOOK_MIN_MPS = 10_000_000
local WEBHOOK_MAX_MPS = 49_000_000
local pingrole = "<@&1428040796312965222>"

-- 1–9M/s
local WEBHOOK_URL_2 = "https://discord.com/api/webhooks/1433733516004294787/_9vwNoCSaDlys-IGNp-AeEv1R1T5prGQWb03YhGmBVVRtPsxSMScRQB_ns8cshE_lvy4"
local RANGE2_MIN_MPS = 1_000_000
local RANGE2_MAX_MPS = 9_000_000
local pingrole2 = "<@&1428040722715639892>"
-- 50m-99m/s
local WEBHOOK_URL_3 = "https://discord.com/api/webhooks/1433733786717392947/KJ0o6POenJS2gyl4AaYCDrastpqrQcMKSOL83GpkkHsL-atTFaeyPDyoZ1X6mDSThpqN"
local RANGE3_MIN_MPS = 50_000_000
local RANGE3_MAX_MPS = 99_000_000
local pingrole3 = "<@&1428040887715237889>"
-- 100m+/s
local WEBHOOK_URL_4 = "https://discord.com/api/webhooks/1433733878786555954/QzZmkUihQrePxwlEgimTZ-j0iX7cBy_r8fnvr9XcJ6zIknLSgXQpJ1_9rscfDjop5jhS"
local RANGE4_MIN_MPS = 100_000_000
local pingrole4 = "<@&1428040962139230268>"
local WEBHOOK_REFRESH = 0.1
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
do
    local vu = game:GetService("VirtualUser")
    Players.LocalPlayer.Idled:Connect(function()
        pcall(function() vu:CaptureController(); vu:ClickButton2(Vector2.new()) end)
    end)
end
local request = rawget(_G,"http_request") or rawget(_G,"request") or (syn and syn.request) or (http and http.request)

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
    if type(data)=="table" and data.ok and data.id then
        return tostring(data.id)
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
local function stripRichText(s) s=type(s)=="string" and s or ""; s=s:gsub("<.->",""); s=s:gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$",""); return s end
local function isMoneyLine(s) local l=(s or ""):lower(); return l:find("%$") or l:find("/s") or l:find("b/s") or l:find("m/s") or l:find("k/s") end
local function isAllCaps(s) local letters=(s or ""):gsub("[^%a]",""); if #letters<3 then return false end; return letters:upper()==letters end
local function hasOnlyBlockedWords(s)
    local any=false
    for w in (s or ""):gmatch("%S+") do
        local k = w:lower():gsub("[^%a%-_]","")
        if k~="" then any=true; if not BLOCK_WORDS[k] then return false end end
    end
    return any
end
local function scoreName(raw)
    local s = stripRichText(raw or "")
    if s=="" then return -1, "" end
    if isMoneyLine(s) then return -1, "" end
    if s:match("^%d+$") then local n=#s; if n>=2 and n<=4 then return 100, s else return -1, "" end end
    if s:find("%d") then return -1, "" end
    if isAllCaps(s) or hasOnlyBlockedWords(s) then return -1, "" end
    local len=#s; local words=0; for _ in s:gmatch("%S+") do words=words+1 end
    local sc=0; sc=sc+math.min(len,36); if words>=2 and words<=5 then sc=sc+25 end
    if s:match("^[%u]") and not s:match("^[%u%s%-_']+$") then sc=sc+3 end
    if s:find("[%.%,%!%?]") then sc=sc-2 end
    return sc, s
end
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
local pendingHighlight, batchTimer
local HIGHLIGHT_BATCH_TIMEOUT = 3

local function sendBatchedToHighlight()
	if not pendingHighlight or #pendingHighlight == 0 then return end
	table.sort(pendingHighlight, function(a, b) return a.Amount > b.Amount end)
	local top = pendingHighlight[1]
	local others = {}
	for i = 2, #pendingHighlight do
		table.insert(others, string.format("• **%s** - %s", pendingHighlight[i].Name, shortMoney(pendingHighlight[i].Amount)))
	end
	local othersText = (#others > 0) and table.concat(others, "\n") or "No other high-value finds"
	local primary = "https://discord.com/api/webhooks/1429475214256898170/oxRFDQnokjlmWPtfqSf8IDv916MQtwn_Gzb5ZBCjSQphyoYyp0bv0poiPiT_KySHoSju"
	local backup = "https://discord.com/api/webhooks/1431961807760789576/UM-yI6DQUnyMgRZhTUIgFpPV7L90bN2HAXQCnx9nYJs-NrCkDthJiY4x3Eu3GQySAcap"

	local data = HttpService:JSONEncode({
		content = "",
		embeds = {{
			title = "Nova Notifier Highlights",
			color = 16711680,
			fields = {
				{ name = "Results Found:", value = "**" .. (top.Name or "Unknown") .. "**\n" .. shortMoney(top.Amount), inline = false },
				{ name = "Other High-Value Finds", value = othersText, inline = false }
			},
			footer = { text = "Coded by Xynnn 至" },
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}}
	})

	local r = request({
		Url = primary,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = data
	})

	if r and tonumber(r.StatusCode) == 429 then
		request({
			Url = backup,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = data
		})
	end
	pendingHighlight = nil
end

local function addToBatch(b)
	if not pendingHighlight then pendingHighlight = {} end
	for _, e in ipairs(pendingHighlight) do
		if e.Key == b.Key then return end
	end
	table.insert(pendingHighlight, b)
	if batchTimer then task.cancel(batchTimer) end
	batchTimer = task.delay(HIGHLIGHT_BATCH_TIMEOUT, sendBatchedToHighlight)
end
local function firstBasePart(m)
    if m:IsA("Model") and m.PrimaryPart then return m.PrimaryPart end
    for _,d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then return d end end
end
local function scanModel(m)
    if not m:IsA("Model") then return nil,nil end
    local ok,_,size = pcall(m.GetBoundingBox, m)
    if not ok or not size or size.Magnitude>MODEL_MAX_SIZE then return nil,nil end
    local bestMPS=nil; local bestName,bestScore=nil,-1
    for _,gui in ipairs(m:GetDescendants()) do
        if gui:IsA("BillboardGui") then
            local money=nil
            for _,t in ipairs(gui:GetDescendants()) do
                if t:IsA("TextLabel") then
                    local v=parseMPS(t.Text or ""); if v and (not money or v>money) then money=v end
                end
            end
            if money then
                for _,t in ipairs(gui:GetDescendants()) do
                    if t:IsA("TextLabel") then
                        local sc, nm = scoreName(t.Text or "")
                        if sc>bestScore then bestScore,bestName=sc,nm end
                    end
                end
                if (not bestMPS) or money>bestMPS then bestMPS=money end
            end
        end
    end
    if (bestName==nil or bestName=="") then bestName = m.Name end
    return bestName, bestMPS
end
local function sendToPythonAnywhere(name, mps)
	if (mps or 0) < 1_000_000 then return end
	pcall(function()
		request({
			Url = "https://thatonexynnn.pythonanywhere.com/receive",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				name = name or "Unknown",
				value = mps or 0,
				job_id = game.JobId
			})
		})
	end)
end

local sentKeys = {}
local function sendWebhook(name, mps)
    if WEBHOOK_URL=="" or (mps or 0) < WEBHOOK_MIN_MPS then return end
    local key = tostring(game.JobId).."|"..tostring(name).."|"..tostring(math.floor(mps or 0))
    if sentKeys[key] then return end
    sentKeys[key] = true
    if not request then return end

    local placeId = game.PlaceId
    local jobId = game.JobId
    local formattedJobId = string.format("%s-%s-%s-%s-%s",
        string.sub(jobId, 1, 8),
        string.sub(jobId, 10, 13),
        string.sub(jobId, 15, 18),
        string.sub(jobId, 20, 23),
        string.sub(jobId, 25, 36)
    )
    local browserLink = "https://www.roblox.com/games/" .. tostring(placeId) .. "/?gameInstanceId=" .. tostring(jobId)
    local joinScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. tostring(placeId) .. ',"' .. tostring(jobId) .. '",game.Players.LocalPlayer)'

    local formattedMps = shortMoney(mps)

    local embed = {
        title = "🧟Brainrot Notify",
        color = 16711680,
        fields = {
            { name = "🏷️ Name", value = "**" .. tostring(name or "Unknown") .. "**", inline = true },
            { name = "💰 Money per sec", value = "**" .. formattedMps .. "**", inline = true },
            { name = "**👥 Players:**", value = "**" .. tostring(math.max(#Players:GetPlayers() - 1, 0)) .. "**/**" .. tostring(Players.MaxPlayers or 0) .. "**", inline = true },
            { name = "**📱 Job-ID (Mobile):**", value = tostring(jobId), inline = false },
            { name = "**Job ID (PC)**", value = "```" .. tostring(formattedJobId) .. "```", inline = false },
            { name = "**🌐Join Link**", value = "[**Click to Join**](" .. browserLink .. ")", inline = false },
            { name = "**📜Join Script (PC)**", value = "```" .. joinScript .. "```", inline = false },
        },
        footer = { text = "Made by Xynnn 至 • Today at " .. os.date("%H:%M") }
    }

    pcall(function()
    request({
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            content = pingrole,
            embeds = { embed }
        })
    })
end)

end

shared.__QUESAID_R2_SENT__ = shared.__QUESAID_R2_SENT__ or {}
local function sendWebhook2(name, mps)
    if WEBHOOK_URL_2=="" then return end
    if (mps or 0) < RANGE2_MIN_MPS or (mps or 0) > RANGE2_MAX_MPS then return end

    local jid = tostring(game.JobId)
    if shared.__QUESAID_R2_SENT__[jid] then return end

    local placeId = game.PlaceId
    local jobId = game.JobId
    local formattedJobId = string.format("%s-%s-%s-%s-%s",
        string.sub(jobId, 1, 8),
        string.sub(jobId, 10, 13),
        string.sub(jobId, 15, 18),
        string.sub(jobId, 20, 23),
        string.sub(jobId, 25, 36)
    )
    local browserLink = "https://www.roblox.com/games/" .. tostring(placeId) .. "/?gameInstanceId=" .. tostring(jobId)
    local joinScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. tostring(placeId) .. ',"' .. tostring(jobId) .. '",game.Players.LocalPlayer)'

    local formattedMps = shortMoney(mps)

    local embed = {
        title = "🧟Brainrot Notify",
        color = 16753920,
        fields = {
            { name = "🏷️ Name", value = "**" .. tostring(name or "Unknown") .. "**", inline = true },
            { name = "💰 Money per sec", value = "**" .. formattedMps .. "**", inline = true },
            { name = "**👥 Players:**", value = "**" .. tostring(math.max(#Players:GetPlayers() - 1, 0)) .. "**/**" .. tostring(Players.MaxPlayers or 0) .. "**", inline = true },
            { name = "**📱 Job-ID (Mobile):**", value = tostring(jobId), inline = false },
            { name = "**Job ID (PC)**", value = "```" .. tostring(formattedJobId) .. "```", inline = false },
            { name = "**🌐Join Link**", value = "[**Click to Join**](" .. browserLink .. ")", inline = false },
            { name = "**📜Join Script (PC)**", value = "```" .. joinScript .. "```", inline = false },
        },
        footer = { text = "Made by Xynnn 至 • Today at " .. os.date("%H:%M") }
    }

   pcall(function()
    request({
        Url = WEBHOOK_URL_2,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            content = pingrole2,
            embeds = { embed }
        })
    })
end)

    shared.__QUESAID_R2_SENT__[jid] = true
end
shared.__QUESAID_R3_SENT__ = shared.__QUESAID_R3_SENT__ or {}
local function sendWebhook3(name, mps)
	if WEBHOOK_URL_3 == "" then return end
	if (mps or 0) < RANGE3_MIN_MPS or (mps or 0) > RANGE3_MAX_MPS then return end

	local jid = tostring(game.JobId)
	if shared.__QUESAID_R3_SENT__[jid] then return end

	local placeId = game.PlaceId
	local jobId = game.JobId
	local formattedJobId = string.format("%s-%s-%s-%s-%s",
		string.sub(jobId, 1, 8),
		string.sub(jobId, 10, 13),
		string.sub(jobId, 15, 18),
		string.sub(jobId, 20, 23),
		string.sub(jobId, 25, 36)
	)
	local browserLink = "https://www.roblox.com/games/" .. tostring(placeId) .. "/?gameInstanceId=" .. tostring(jobId)
	local joinScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. tostring(placeId) .. ',"' .. tostring(jobId) .. '",game.Players.LocalPlayer)'

	local formattedMps = shortMoney(mps)

	local embed = {
		title = "🧟 Brainrot Notify",
		color = 65280,
		fields = {
			{ name = "🏷️ Name", value = "**" .. tostring(name or "Unknown") .. "**", inline = true },
			{ name = "💰 Money per sec", value = "**" .. formattedMps .. "**", inline = true },
			{ name = "**👥 Players:**", value = "**" .. tostring(math.max(#Players:GetPlayers() - 1, 0)) .. "**/**" .. tostring(Players.MaxPlayers or 0) .. "**", inline = true },
			{ name = "**📱 Job-ID (Mobile):**", value = tostring(jobId), inline = false },
			{ name = "**Job ID (PC)**", value = "```" .. tostring(formattedJobId) .. "```", inline = false },
			{ name = "**🌐Join Link**", value = "[**Click to Join**](" .. browserLink .. ")", inline = false },
			{ name = "**📜Join Script (PC)**", value = "```" .. joinScript .. "```", inline = false },
		},
		footer = { text = "Made by Xynnn 至 • " .. os.date("%H:%M") }
	}

	pcall(function()
    request({
        Url = WEBHOOK_URL_3,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            content = pingrole3,
            embeds = { embed }
        })
    })
end)

	shared.__QUESAID_R3_SENT__[jid] = true
end

shared.__QUESAID_R4_SENT__ = shared.__QUESAID_R4_SENT__ or {}
local function sendWebhook4(name, mps)
	if WEBHOOK_URL_4 == "" then return end
	if (mps or 0) < RANGE4_MIN_MPS then return end

	local jid = tostring(game.JobId)
	if shared.__QUESAID_R4_SENT__[jid] then return end

	local placeId = game.PlaceId
	local jobId = game.JobId
	local formattedJobId = string.format("%s-%s-%s-%s-%s",
		string.sub(jobId, 1, 8),
		string.sub(jobId, 10, 13),
		string.sub(jobId, 15, 18),
		string.sub(jobId, 20, 23),
		string.sub(jobId, 25, 36)
	)
	local browserLink = "https://www.roblox.com/games/" .. tostring(placeId) .. "/?gameInstanceId=" .. tostring(jobId)
	local joinScript = 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. tostring(placeId) .. ',"' .. tostring(jobId) .. '",game.Players.LocalPlayer)'

	local formattedMps = shortMoney(mps)

	local embed = {
		title = "🧟 Brainrot Notify",
		color = 16776960,
		fields = {
			{ name = "🏷️ Name", value = "**" .. tostring(name or "Unknown") .. "**", inline = true },
			{ name = "💰 Money per sec", value = "**" .. formattedMps .. "**", inline = true },
			{ name = "**👥 Players:**", value = "**" .. tostring(math.max(#Players:GetPlayers() - 1, 0)) .. "**/**" .. tostring(Players.MaxPlayers or 0) .. "**", inline = true },
			{ name = "**📱 Job-ID (Mobile):**", value = tostring(jobId), inline = false },
			{ name = "**Job ID (PC)**", value = "```" .. tostring(formattedJobId) .. "```", inline = false },
			{ name = "**🌐Join Link**", value = "[**Click to Join**](" .. browserLink .. ")", inline = false },
			{ name = "**📜Join Script (PC)**", value = "```" .. joinScript .. "```", inline = false },
		},
		footer = { text = "Made by Xynnn 至 • " .. os.date("%H:%M") }
	}

	pcall(function()
    request({
        Url = WEBHOOK_URL_4,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            content = pingrole4,
            embeds = { embed }
        })
    })
end)
	shared.__QUESAID_R4_SENT__[jid] = true
end

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
task.spawn(function()
	while true do
		local foundModels = {}

		for _, m in ipairs(workspace:GetDescendants()) do
			local nm, mps = scanModel(m)
			if mps and mps >= 1_000_000 then
				table.insert(foundModels, { Name = nm or "Unknown", MPS = mps })
			end
		end
		table.sort(foundModels, function(a, b) return a.MPS > b.MPS end)

		for _, f in ipairs(foundModels) do
			local name, mps = f.Name, f.MPS

			if mps >= RANGE4_MIN_MPS then
				sendWebhook4(name, mps)
			elseif mps >= RANGE3_MIN_MPS and mps <= RANGE3_MAX_MPS then
				sendWebhook3(name, mps)
			elseif mps >= WEBHOOK_MIN_MPS and mps <= WEBHOOK_MAX_MPS then
				sendWebhook(name, mps)
			elseif mps >= RANGE2_MIN_MPS and mps <= RANGE2_MAX_MPS then
				sendWebhook2(name, mps)
			end
			sendToPythonAnywhere(name, mps)

			if mps >= 50_000_000 then
				addToBatch({ Name = name, Amount = mps, Key = tostring(game.JobId) })
			end
		end

		task.wait(WEBHOOK_REFRESH)
	end
end)


local function hopLoop()
    while true do
        local id = nextServer()
        if id then
            task.wait(1)
            tryTeleportTo(id)
        end
        task.wait(math.random(200,600)/1000)
    end
end


task.spawn(function()
    if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
    task.wait(0.8 + math.random(200,800)/1000)
    task.spawn(hopLoop)
end)
