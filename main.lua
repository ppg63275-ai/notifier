repeat until game:IsLoaded()
local GLOBAL = getgenv and getgenv() or _G
task.wait(5)
GLOBAL.__SentWebhooks = GLOBAL.__SentWebhooks or {}
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Plots = cloneref(workspace:WaitForChild("Plots", 9e9))
ReplicatedStorage:WaitForChild("Controllers", 9e9)
local PlotController = require(ReplicatedStorage.Controllers.PlotController)
local BACKEND_URL = "http://127.0.0.1:5000/"
local TP_MIN_GAP_S     = 1
local TP_JITTER_MIN_S  = 0.5
local TP_JITTER_MAX_S  = 0.5
local TP_STUCK_TIMEOUT = 12.0
local PlayerPlot
repeat
    PlayerPlot = PlotController.GetMyPlot()
    task.wait()
until PlayerPlot

local PlayerBase = PlayerPlot.PlotModel

local Gui = Instance.new("ScreenGui")
Gui.Name = "ScanProgressGui"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Name = "Container"
Frame.AnchorPoint = Vector2.new(0.5, 0)
Frame.Position = UDim2.new(0.5, 0, 0.05, 0)
Frame.Size = UDim2.new(0, 360, 0, 200)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Frame.BackgroundTransparency = 0.2
Frame.BorderSizePixel = 0
Frame.Parent = Gui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Frame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, -20, 0, 24)
Title.Position = UDim2.new(0, 10, 0, 6)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "Scanning Plots"
Title.Parent = Frame

local Progress = Instance.new("TextLabel")
Progress.Name = "Progress"
Progress.BackgroundTransparency = 1
Progress.Size = UDim2.new(1, -20, 0, 20)
Progress.Position = UDim2.new(0, 10, 0, 32)
Progress.Font = Enum.Font.Gotham
Progress.TextSize = 16
Progress.TextColor3 = Color3.fromRGB(200, 200, 200)
Progress.TextXAlignment = Enum.TextXAlignment.Left
Progress.Text = "0/0 (0%)"
Progress.Parent = Frame

local Hopper = Instance.new("TextLabel")
Hopper.Name = "Hopper"
Hopper.BackgroundTransparency = 1
Hopper.Size = UDim2.new(1, -20, 0, 20)
Hopper.Position = UDim2.new(0, 10, 0, 56)
Hopper.Font = Enum.Font.Gotham
Hopper.TextSize = 15
Hopper.TextColor3 = Color3.fromRGB(180, 220, 255)
Hopper.TextXAlignment = Enum.TextXAlignment.Left
Hopper.Text = "Hopper: Idle"
Hopper.Parent = Frame

local Attempts = Instance.new("TextLabel")
Attempts.Name = "Attempts"
Attempts.BackgroundTransparency = 1
Attempts.Size = UDim2.new(1, -20, 0, 20)
Attempts.Position = UDim2.new(0, 10, 0, 78)
Attempts.Font = Enum.Font.Gotham
Attempts.TextSize = 14
Attempts.TextColor3 = Color3.fromRGB(200, 200, 200)
Attempts.TextXAlignment = Enum.TextXAlignment.Left
Attempts.Text = "Attempts/s: 0.0  Total: 0"
Attempts.Parent = Frame

local Pages = Instance.new("TextLabel")
Pages.Name = "Pages"
Pages.BackgroundTransparency = 1
Pages.Size = UDim2.new(1, -20, 0, 20)
Pages.Position = UDim2.new(0, 10, 0, 98)
Pages.Font = Enum.Font.Gotham
Pages.TextSize = 14
Pages.TextColor3 = Color3.fromRGB(200, 200, 200)
Pages.TextXAlignment = Enum.TextXAlignment.Left
Pages.Text = "Pages Scanned: 0  Cursor: nil"
Pages.Parent = Frame

local Candidates = Instance.new("TextLabel")
Candidates.Name = "Candidates"
Candidates.BackgroundTransparency = 1
Candidates.Size = UDim2.new(1, -20, 0, 20)
Candidates.Position = UDim2.new(0, 10, 0, 118)
Candidates.Font = Enum.Font.Gotham
Candidates.TextSize = 14
Candidates.TextColor3 = Color3.fromRGB(200, 200, 200)
Candidates.TextXAlignment = Enum.TextXAlignment.Left
Candidates.Text = "Candidates: 0  Tried IDs: 0"
Candidates.Parent = Frame

local LastResult = Instance.new("TextLabel")
LastResult.Name = "LastResult"
LastResult.BackgroundTransparency = 1
LastResult.Size = UDim2.new(1, -20, 0, 20)
LastResult.Position = UDim2.new(0, 10, 0, 138)
LastResult.Font = Enum.Font.Gotham
LastResult.TextSize = 14
LastResult.TextColor3 = Color3.fromRGB(200, 200, 200)
LastResult.TextXAlignment = Enum.TextXAlignment.Left
LastResult.Text = "Last: None"
LastResult.Parent = Frame

local Status = Instance.new("TextLabel")
Status.Name = "Status"
Status.BackgroundTransparency = 1
Status.Size = UDim2.new(1, -20, 0, 20)
Status.Position = UDim2.new(0, 10, 0, 158)
Status.Font = Enum.Font.Gotham
Status.TextSize = 14
Status.TextColor3 = Color3.fromRGB(200, 200, 200)
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Text = "Status: Idle"
Status.Parent = Frame

local Meter = Instance.new("TextLabel")
Meter.Name = "Meter"
Meter.BackgroundTransparency = 1
Meter.Size = UDim2.new(1, -20, 0, 20)
Meter.Position = UDim2.new(0, 10, 0, 178)
Meter.Font = Enum.Font.Gotham
Meter.TextSize = 14
Meter.TextColor3 = Color3.fromRGB(200, 200, 200)
Meter.TextXAlignment = Enum.TextXAlignment.Left
Meter.Text = "Q: 0/0"
Meter.Parent = Frame

local function toNumber(str)
    local s = (str or ""):gsub(",", ""):gsub("%s*/s%s*", ""):gsub("%$", "")
    local m = 1
    if s:find("K") then m = 1e3 elseif s:find("M") then m = 1e6 elseif s:find("B") then m = 1e9 elseif s:find("T") then m = 1e12 end
    s = s:gsub("[KMBT]", "")
    local n = tonumber(s)
    return n and (n * m) or 0
end

local function setProgress(c,t)
    local pct = t > 0 and math.floor((c/t)*100) or 0
    Progress.Text = tostring(c).."/"..tostring(t).." ("..tostring(pct).."%)"
end

local ScanComplete = false
local seedBase = tostring(LocalPlayer.UserId).."|"..tostring(game.JobId).."|"..tostring(os.clock()).."|"..HttpService:GenerateGUID(false)
local seedNum = tonumber((seedBase:gsub("%D",""):sub(1,9))) or math.floor(os.clock()*1e6)
local RNG = Random.new(seedNum)
local InitialJitter = RNG:NextNumber(0.02, 1.2)

local HopperInfo = {
    attemptsTotal = 0,
    pages = 0,
    lastCursor = "nil",
    candidates = 0,
    triedIds = 0,
    lastMsg = "Idle",
    lastActivityT = os.clock(),
    attemptsInWindow = 0,
    lastWindowT = os.clock()
}

local function touch()
    HopperInfo.lastActivityT = os.clock()
end

local function DoRequest(opt)
    if syn and syn.request then
        local ok, res = pcall(syn.request, opt)
        if ok and res then return res end
    end
    if request then
        local ok, res = pcall(request, opt)
        if ok and res then return res end
    end
    if http_request then
        local ok, res = pcall(http_request, opt)
        if ok and res then return res end
    end
    if http and http.request then
        local ok, res = pcall(http.request, opt)
        if ok and res then return res end
    end
    if type(opt) == "table" and opt.Url and opt.Method == "GET" then
        local ok, r = pcall(function() return {Body = HttpService:GetAsync(opt.Url), StatusCode = 200} end)
        if ok and r then return r end
    end
    return nil
end

local function GetBestBrainrots()
    local best, seen = {}, {}
    local list = {}
    for _, p in ipairs(Plots:GetChildren()) do
        if not p:IsDescendantOf(PlayerBase) then
            table.insert(list, p)
        end
    end
    local total = #list
    local done = 0
    setProgress(done, total)
    for _, plot in ipairs(list) do
        for _, v in ipairs(plot:GetDescendants()) do
            if v.Name == "Generation" and v:IsA("TextLabel") and v.Parent:IsA("BillboardGui") then
                local amt = toNumber(v.Text)
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
                        key = disp .. ":" .. (v.Parent.Parent:GetFullName())
                    end
                    if not seen[key] then
                        seen[key] = true
                        table.insert(best, {
                            Name = disp,
                            Spawn = spawn,
                            Label = v,
                            Actor = nil,
                            Amount = amt,
                            RealAmount = v.Text,
                            Key = key
                        })
                    end
                end
            end
        end
        done += 1
        setProgress(done, total)
        task.wait()
    end
    table.sort(best, function(a,b) return a.Amount > b.Amount end)
    Title.Text = "Scan Complete"
    ScanComplete = true
    touch()
    return best
end

local function formatAmount(amount)
    if amount >= 1_000_000_000 then
        local billions = amount / 1_000_000_000
        if billions % 1 == 0 then
            return "$" .. math.floor(billions) .. "B/s"
        else
            return string.format("$%.1fB/s", billions)
        end
    elseif amount >= 1_000_000 then
        local millions = amount / 1_000_000
        if millions % 1 == 0 then
            return "$" .. math.floor(millions) .. "M/s"
        else
            return string.format("$%.1fM/s", millions)
        end
    else
        return "$" .. tostring(amount) .. "/s"
    end
end

function sendtohighlight(amount, name)
    local primary = "https://discord.com/api/webhooks/1429475214256898170/oxRFDQnokjlmWPtfqSf8IDv916MQtwn_Gzb5ZBCjSQphyoYyp0bv0poiPiT_KySHoSju"
    local backup  = "https://discord.com/api/webhooks/1431961807760789576/UM-yI6DQUnyMgRZhTUIgFpPV7L90bN2HAXQCnx9nYJs-NrCkDthJiY4x3Eu3GQySAcap"

    local data = HttpService:JSONEncode({
        content = "",
        embeds = {{
            title = "🚨 Brainrot Found by Bot! | Nova Notifier",
            color = 16711680,
            fields = {
                { name = "Name", value = name or "Unknown", inline = true },
                { name = "Amount", value = formatAmount(amount), inline = true },
            },
            footer = { text = "by sigma xynnn • may be sent by multiple bots" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    })

    local res = DoRequest({
        Url = primary,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = data
    })

    if res and tonumber(res.StatusCode) == 429 then
        warn("[Highlight] Primary webhook hit rate limit (429), using backup...")
        DoRequest({
            Url = backup,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = data
        })
    end
end

local API_URL = "https://proxilero.vercel.app/api/notify.js"
local PYTHONANYWHERE_URL = "https://thatonexynnn.pythonanywhere.com/receive"

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

    pcall(function()
        DoRequest({
            Url = API_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

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

    if b.Amount >= 50_000_000 then
        sendtohighlight(b.Amount, b.Name)
    end
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
local MIN_PLAYERS = 6
-- /next: minPlayers + JobID
local function nextServer()
    local data = postJSON("next", {
        placeId    = game.PlaceId,
        currentJob = game.JobId,
        minPlayers = MIN_PLAYERS,
    })
    if type(data)=="table" and data.ok and data.id then
        return tostring(data.id)
    end
    -- бэкофф, если ничего не получено
    task.wait(0.2)
    return nil
end

local function releaseKey(serverId)
    if not serverId then return end
    pcall(function() postJSON("release", { placeId = game.PlaceId, key = tostring(serverId) }) end)
end

-- Телепорт: повтор через бэкенд + джиттер + кулдавн + ватчдог
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

    -- ватчдог: если телепорт завис, берёт следующий
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

-- /JOINED: Успешный вход (Бэкенд блокирует на 1 час)
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

task.spawn(function()
    local lastAttempts = 0
    local lastT = os.clock()
    while true do
        local now = os.clock()
        if now - lastT >= 1 then
            local diff = HopperInfo.attemptsTotal - lastAttempts
            local aps = diff / (now - lastT)
            Attempts.Text = string.format("Attempts/s: %.1f  Total: %d", aps, HopperInfo.attemptsTotal)
            lastAttempts = HopperInfo.attemptsTotal
            lastT = now
        end
        Pages.Text = "Pages Scanned: "..tostring(HopperInfo.pages).."  Cursor: "..tostring(HopperInfo.lastCursor)
        Candidates.Text = "Candidates: "..tostring(HopperInfo.candidates).."  Tried IDs: "..tostring(HopperInfo.triedIds)
        LastResult.Text = "Last: "..tostring(HopperInfo.lastMsg)
        Status.Text = "Status: "..(ScanComplete and "Ready" or "Scanning")
        Meter.Text = "Q: 0/0"
        task.wait(0.1)
    end
end)
task.spawn(function()
    local jobids = nextServer()
    while true do
        if Title and Title.Text == "Scan Complete" then
            tryTeleportTo(jobids)
            break
        end
        task.wait(0.05)
    end
end)

local SentBrainrots = {}
local list = GetBestBrainrots()
for _, brain in ipairs(list) do
    local key = brain.Key
    if key and not SentBrainrots[key] then
        SentBrainrots[key] = true
        task.spawn(function() SendBrainrotWebhook(brain) end)
    end
end
