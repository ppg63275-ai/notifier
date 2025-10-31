local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Plots = workspace:WaitForChild("Plots")
local GLOBAL = getgenv and getgenv() or _G

local function nowts() return os.date("!%Y-%m-%dT%H:%M:%SZ") end

local function DoRequest(opt)
    local function _safe_call(fn, arg)
        local ok, res = pcall(fn, arg)
        if ok and res then return res end
        return nil
    end
    if syn and syn.request then
        local res = _safe_call(syn.request, opt)
        if res then return res end
    end
    if request then
        local res = _safe_call(request, opt)
        if res then return res end
    end
    if http_request then
        local res = _safe_call(http_request, opt)
        if res then return res end
    end
    if http and http.request then
        local res = _safe_call(http.request, opt)
        if res then return res end
    end
    if type(opt) == "table" and opt.Url and opt.Method == "GET" then
        local ok, r = pcall(function() return {Body = HttpService:GetAsync(opt.Url), StatusCode = 200} end)
        if ok and r then return r end
    end
    return nil
end

local function toNumber(str)
    local s = (str or ""):gsub(",", ""):gsub("%s*/s%s*", ""):gsub("%$", "")
    local m = 1
    if s:find("K") then m = 1e3 elseif s:find("M") then m = 1e6 elseif s:find("B") then m = 1e9 elseif s:find("T") then m = 1e12 end
    s = s:gsub("[KMBT]", "")
    local n = tonumber(s)
    return n and (n * m) or 0
end

local function GetBestBrainrots()
    local best, seen = {}, {}
    local list = {}
    for _, p in ipairs(Plots:GetChildren()) do table.insert(list, p) end
    for _, plot in ipairs(list) do
        for _, v in ipairs(plot:GetDescendants()) do
            if v.Name == "Generation" and v:IsA("TextLabel") and v.Parent:IsA("BillboardGui") then
                local raw = v.Text
                local amt = toNumber(raw)
                if amt > 0 then
                    local spawn = v.Parent.Parent.Parent
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
                        table.insert(best, {Name = disp, Amount = amt, RealAmount = raw, Key = key})
                    end
                end
            end
        end
    end
    table.sort(best, function(a,b) return a.Amount > b.Amount end)
    return best
end

local function formatAmount(amount)
    if amount >= 1e9 then
        local v = amount/1e9
        return (v%1==0) and ("$"..math.floor(v).."B/s") or ("$"..string.format("%.1fB/s",v))
    elseif amount >= 1e6 then
        local v = amount/1e6
        return (v%1==0) and ("$"..math.floor(v).."M/s") or ("$"..string.format("%.1fM/s",v))
    else
        return "$"..amount.."/s"
    end
end

function sendtohighlight(amount, name)
    local primary = "https://discord.com/api/webhooks/1429475214256898170/oxRFDQnokjlmWPtfqSf8IDv916MQtwn_Gzb5ZBCjSQphyoYyp0bv0poiPiT_KySHoSju"
    local backup  = "https:/ /discord.com/api/webhooks/1431961807760789576/UM-yI6DQUnyMgRZhTUIgFpPV7L90bN2HAXQCnx9nYJs-NrCkDthJiY4x3Eu3GQySAcap"
    local data = HttpService:JSONEncode({
        content = "",
        embeds = {{
            title = "🚨 Brainrot Found by Bot! | Nova Notifier",
            color = 16711680,
            fields = {
                { name = "Name", value = name or "Unknown", inline = true },
                { name = "Amount", value = formatAmount(amount), inline = true },
            },
            footer = { text = "Coded by Xynnn 至" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    })
    local r = DoRequest({ Url = primary, Method = "POST", Headers = { ["Content-Type"] = "application/json"}, Body = data })
    if r and tonumber(r.StatusCode) == 429 then
        DoRequest({ Url = backup, Method = "POST", Headers = { ["Content-Type"] = "application/json"}, Body = data })
    end
end

local API_URL = "https://proxilero.vercel.app/api/notify.js"
local PYTHONANYWHERE_URL = "https://thatonexynnn.pythonanywhere.com/receive"
local GLOBAL = getgenv and getgenv() or _G
GLOBAL.__SentWebhooks = GLOBAL.__SentWebhooks or {}

local function SendBrainrotWebhook(b)
    if not b or not b.Key then return end
    if b.Amount < 1_000_000 then return end

    local sig = tostring(game.JobId).."|"..tostring(b.Key).."|"..tostring(b.RealAmount).."|"..tostring(b.Name)
    if GLOBAL.__SentWebhooks[sig] then return end
    GLOBAL.__SentWebhooks[sig] = true

    local payload = {
        id = sig,
        name = b.Name or "Unknown",
        amount = b.Amount or 0,
        realAmount = b.RealAmount or "",
        jobId = game.JobId,
        placeId = game.PlaceId,
        players = tostring(#Players:GetPlayers()).."/"..tostring(Players.MaxPlayers),
        timestamp = os.time(),
    }

    coroutine.wrap(function()
        pcall(function()
            DoRequest({
                Url = API_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)()

    coroutine.wrap(function()
        pcall(function()
            DoRequest({
                Url = PYTHONANYWHERE_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    name = b.Name or "Unknown",
                    value = b.Amount or 0,
                    job_id = game.JobId
                })
            })
        end)
    end)()

    if b.Amount >= 50_000_000 then
        sendtohighlight(b.Amount, b.Name)
    end
end

local BASE_URL = "http://127.0.0.1:5000"

local function GetNextJobId()
    local res = DoRequest({
        Url = BASE_URL .. "/next",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            currentJob = game.JobId,
            minPlayers = 6
        })
    })
    if not res then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if ok and data and data.job then
        return tostring(data.job)
    end
    return nil
end

local function ReleaseJobId(jobId)
    DoRequest({ Url = BASE_URL.."/release", Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({ jobId = jobId }) })
end

local function JoinedJobId(jobId)
    DoRequest({ Url = BASE_URL.."/joined", Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({ jobId = jobId }) })
end

local function jitter()
    local j = math.random(math.floor(0.5), math.floor(0.5))/1000
    task.wait(j)
end

local lastAttemptJobId, lastFailAt = nil, 0
local lastTeleportAt = 0
local TP_MIN_GAP_S = 1
local TP_JITTER_MIN_S = 0.5
local TP_JITTER_MAX_S = 0.5
local TP_STUCK_TIMEOUT = 12.0

local function tryTeleportTo(jobId)
    local ok, res = pcall(function()
        return TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId)
    end)
    return ok
end

TeleportService.TeleportInitFailed:Connect(function()
    lastFailAt = os.clock()
    if lastAttemptJobId then ReleaseJobId(lastAttemptJobId) end
    task.wait(0.6)
    local nextId = GetNextJobId()
    if nextId then tryTeleportTo(nextId) end
end)

shared.__QUESAID_LAST_MARKED__ = shared.__QUESAID_LAST_MARKED__ or nil
local function markJoinedOnce()
    local jid = tostring(game.JobId)
    if shared.__QUESAID_LAST_MARKED__ == jid then return end
    shared.__QUESAID_LAST_MARKED__ = jid
    task.delay(2, function()
        DoRequest({ Url = BASE_URL.."/joined", Method = "POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({ placeId=game.PlaceId, serverId=jid }) })
    end)
end

coroutine.wrap(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    markJoinedOnce()
end)()

Players.LocalPlayer.CharacterAdded:Connect(markJoinedOnce)

coroutine.wrap(function()
    local last = nil
    while true do
        local jid = tostring(game.JobId)
        if jid ~= last then last = jid; markJoinedOnce() end
        task.wait(5)
    end
end)()

coroutine.wrap(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    task.wait(1)
    local best = GetBestBrainrots()
    if best and best[1] then
        SendBrainrotWebhook(best[1])
    end
    coroutine.wrap(function()
        coroutine.wrap(function()
            while task.wait(2.5 + math.random() * 0.5) do
                local nid = GetNextJobId()
                if not nid or #nid <= 10 or nid == game.JobId then
                    task.wait(1.0 + math.random() * 0.4)
                end
                local jitterDelay = 0.25 + math.random() * 0.75
                task.wait(jitterDelay)
                local success = tryTeleportTo(nid)
                if success then
                    break
                else
                    task.wait(2.0 + math.random() * 0.5)
                end
            end
        end)()
    end)()
end)()
