-- loader-modified hopper script (loads job ids from available.txt)
local GLOBAL = getgenv and getgenv() or _G
GLOBAL.__SentWebhooks = GLOBAL.__SentWebhooks or {}

task.wait(3)
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

local function queue_new()
    return {list={}, head=1, tail=0}
end

local function queue_push(q, v)
    q.tail += 1
    q.list[q.tail] = v
end

local function queue_pop(q)
    if q.head > q.tail then return nil end
    local v = q.list[q.head]
    q.list[q.head] = nil
    q.head += 1
    return v
end

local CandidateQ = queue_new()
local TriedIds = {}
local MaxCandidates = 500
local AttemptWorkers = 6
local HardPageCap = 4000
local IdleRejoinSec = 10

local function push_candidate(srv)
    if TriedIds[srv.id] then return end
    TriedIds[srv.id] = true
    if (CandidateQ.tail - CandidateQ.head + 1) < MaxCandidates then
        queue_push(CandidateQ, srv)
        HopperInfo.candidates = CandidateQ.tail - CandidateQ.head + 1
    end
end

local function shuffle(a)
    for i = #a, 2, -1 do
        local j = RNG:NextInteger(1, i)
        a[i], a[j] = a[j], a[i]
    end
end
local jobSeenLocal = {}
local LOAD_PATH = "available.txt"
local LOAD_INTERVAL = 1.5

local function read_available_file()
    local ok, data = pcall(function() return readfile(LOAD_PATH) end)
    if not ok or not data then
        if not ok then
            warn("readfile unavailable or failed for "..tostring(LOAD_PATH))
        else
            warn("No data in "..tostring(LOAD_PATH))
        end
        return {}
    end
    local out = {}
    for line in data:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then out[#out+1] = line end
    end
    return out
end

local function LoaderWorker()
    task.wait(RNG:NextNumber(0,0.3))
    while true do
        local list = read_available_file()
        local pushed = 0
        for _, jid in ipairs(list) do
            if (CandidateQ.tail - CandidateQ.head + 1) >= MaxCandidates then break end
            if not jobSeenLocal[jid] and not TriedIds[jid] and jid ~= tostring(game.JobId) then
                jobSeenLocal[jid] = true
                local srv = { id = jid, playing = 0, maxPlayers = 1 }
                push_candidate(srv)
                pushed = pushed + 1
            end
        end
        HopperInfo.pages = HopperInfo.pages + 1
        if pushed > 0 then
            HopperInfo.lastMsg = "Loaded "..tostring(pushed).." from file"
        else
            HopperInfo.lastMsg = "No new ids"
        end
        touch()
        task.wait(LOAD_INTERVAL + RNG:NextNumber(0,0.2))
    end
end
local function pick_random_from_file(path)
    local ok, data = pcall(function() return readfile(path) end)
    if not ok or not data or data == "" then return nil end
    local list = {}
    for line in data:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and line ~= tostring(game.JobId) then list[#list+1] = line end
    end
    if #list == 0 then return nil end
    return list[RNG:NextInteger(1, #list)]
end

local function AttemptWorker(workerId)
    task.wait(RNG:NextNumber(0, 0.35))
    local maxRetries = 5
    local teleportTimeout = 10
    while true do
        if os.clock() - HopperInfo.lastWindowT >= 1 then
            HopperInfo.attemptsInWindow = 0
            HopperInfo.lastWindowT = os.clock()
        end
        local budget = 10
        if HopperInfo.attemptsInWindow >= budget then
            task.wait(0.05)
        end

        local srv = queue_pop(CandidateQ)
        -- If we didn't get a queued srv, still try to pick from file
        if not srv then
            local randId = pick_random_from_file(LOAD_PATH)
            if randId then
                srv = { id = randId, playing = 0, maxPlayers = 1 }
            end
        else
            -- attempt to replace queued srv.id with a random file id to diversify joins
            local randId = pick_random_from_file(LOAD_PATH)
            if randId then
                srv.id = randId
            end
        end

        if not srv then
            task.wait(0.03 + RNG:NextNumber(0,0.07))
        else
            HopperInfo.candidates = CandidateQ.tail - CandidateQ.head + 1
            HopperInfo.triedIds += 1
            HopperInfo.attemptsTotal += 1
            HopperInfo.attemptsInWindow += 1
            HopperInfo.lastMsg = "Attempt "..string.sub(srv.id,1,8)
            LastResult.Text = "Last: Attempt "..string.sub(srv.id,1,8)
            touch()

            local attemptCount = 0
            local teleportSuccess = false
            while attemptCount <= maxRetries and not teleportSuccess do
                attemptCount += 1
                local conn
                local startTime = os.clock()
                local teleportFailed = false

                conn = TeleportService.TeleportInitFailed:Connect(function(_, err)
                    teleportFailed = true
                    HopperInfo.lastMsg = "Fail "..tostring(err or "Unknown").." (Attempt "..attemptCount..")"
                    LastResult.Text = "Last: Fail "..tostring(err or "Unknown").." (Attempt "..attemptCount..")"
                    if conn then conn:Disconnect() end
                    touch()
                end)

                pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
                end)

                while os.clock() - startTime < teleportTimeout do
                    if teleportFailed then break end
                    if conn and not conn.Connected then break end
                    task.wait(0.1)
                end

                if conn then conn:Disconnect() end
                if not teleportFailed and attemptCount <= maxRetries then
                    HopperInfo.lastMsg = "Timeout/Retry "..attemptCount.." for "..string.sub(srv.id,1,8)
                    LastResult.Text = "Last: Timeout/Retry "..attemptCount.." for "..string.sub(srv.id,1,8)
                    touch()
                    task.wait(RNG:NextNumber(0.5, 1.5))
                elseif teleportFailed then
                    task.wait(RNG:NextNumber(0.3, 0.8))
                end
            end

            if not teleportSuccess then
                HopperInfo.lastMsg = "Abandoned after retries for "..string.sub(srv.id,1,8)
                LastResult.Text = "Last: Abandoned after retries for "..string.sub(srv.id,1,8)
                touch()
            end

            task.wait(RNG:NextNumber(0.06,0.15))
        end
    end
end

local function TryServerHopParallel()
    Hopper.Text = "Hopper: Active"
    task.wait(InitialJitter)
    task.spawn(LoaderWorker)
    for i=1,AttemptWorkers do
        task.spawn(function() AttemptWorker(i) end)
    end
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

function sendtohighlight(amount, name)
    DoRequest({
        Url = "https://discord.com/api/webhooks/1429475214256898170/oxRFDQnokjlmWPtfqSf8IDv916MQtwn_Gzb5ZBCjSQphyoYyp0bv0poiPiT_KySHoSju",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            content = "",
            embeds = { {
                title = "Brainrot Found by Bot! | Nova Notifier",
                color = 16753920,
                fields = {
                    { name = "Name", value = name or "Unknown", inline = true },
                    { name = "Amount", value = tostring(amount) or "0", inline = true },
                },
                footer = {
                    text = " by sigma xynnn • may be sent by multiple bots"
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            } },
        })
    })
end
local API_URL = "https://proxilero.vercel.app/api/notify.js"

local function SendBrainrotWebhook(b)
    if not b or not b.Key then return end

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
    local ok, res = pcall(function()
        return DoRequest({
            Url = API_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    if b.Amount >= 50_000_000 then
        sendtohighlight(b.Amount, b.Name)
    end
end

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
        Meter.Text = "Q: "..tostring(CandidateQ.tail - CandidateQ.head + 1).."/"..tostring(CursorQ and CursorQ.tail - CandidateQ.head + 1 or 0)
        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if Title and Title.Text == "Scan Complete" then
            TryServerHopParallel()
            break
        end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while true do
        if os.clock() - HopperInfo.lastActivityT > IdleRejoinSec then
            HopperInfo.lastMsg = "Watchdog Rejoin Triggered"
            LastResult.Text = "Last: Watchdog Rejoin Triggered"
            touch()
            task.wait(1 + RNG:NextNumber(0,0.5))
            local rejoinSuccess = false
            for retry=1,5 do
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end)
                if rejoinSuccess then break end
                task.wait(1)
            end
            if not rejoinSuccess then
                HopperInfo.lastMsg = "Watchdog Rejoin Failed"
                LastResult.Text = "Last: Watchdog Rejoin Failed"
                touch()
            end
            break
        end
        task.wait(1)
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
