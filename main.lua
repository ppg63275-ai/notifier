repeat task.wait() until game:IsLoaded()
-- upd 0.3
local workspace = game:WaitForChild("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local plots = workspace:WaitForChild("Plots")
local req = request or http_request or http and http.request
local HttpService = game:GetService("HttpService")
local api = "https://api.novanotifier.space/"
local brainrots = {}
local guidMap = {}
local Results = { set = {}, list = {} }
local Highest = { name = nil, moni = 0 }
local Others = {}
local TeleportService = game:GetService("TeleportService")
local tpFailed = false
local BrainrotQueue = {}
local CURRENT_TS = os.time()

local BrainrotEndpoints = {
    "https://thatonexynnn.pythonanywhere.com/receive",
    "https://prexy-psi.vercel.app/api/notify"
}

local function cleanVFX()
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
            d.Enabled = false
        elseif d:IsA("SurfaceAppearance") or d:IsA("Highlight") then
            d:Destroy()
        end
    end
    for _, cam in ipairs(workspace.CurrentCamera:GetDescendants()) do
        if cam:IsA("PostEffect") then
            cam.Enabled = false
        end
    end
end

cleanVFX()
task.spawn(function()
    while task.wait(3) do
        cleanVFX()
    end
end)

TeleportService.TeleportInitFailed:Connect(function()
    tpFailed = true
end)

local function nextJob()
    local response = req({
        Url = api.."next",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({
            currentJob = tostring(game.JobId),
            minPlayers = 1
        })
    })
    if not response then return nil end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)
    if ok and data and data.job then
        return tostring(data.job), tonumber(data.ts)
    end
    return nil
end

local function releaseJob()
    req({
        Url = api.."release",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            jobId = tostring(game.JobId)
        })
    })
end

local function tryTeleport(jobId)
    tpFailed = false
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId)
    end)
    if not ok then return false end
    local s = os.clock()
    while os.clock() - s < 5 do
        if tpFailed then return false end
        task.wait(0.1)
    end
    return true
end

local function hop()
    local id, ts = nextJob()
    if not id or not ts then return end
    coroutine.wrap(function()
        while true do
            if not id or #id <= 10 or id == game.JobId or ts <= CURRENT_TS then
                task.wait(1 + math.random() * 0.2)
                id, ts = nextJob()
                continue
            end
            task.wait(2.3 + math.random() * 0.3)
            if tryTeleport(id) then break end
            id, ts = nextJob()
        end
    end)()
end

local function parseGeneration(str)
    str = string.gsub(str, "[%$,/s,]", "")
    str = string.gsub(str, "%s+", "")
    local number, suffix = string.match(str, "([%d%.]+)([KMBT]?)")
    number = tonumber(number)
    if not number then return nil end
    local mul = { K = 1e3, M = 1e6, B = 1e9, T = 1e12, [""] = 1 }
    return number * (mul[suffix] or 1)
end

local function formatAmount(amount)
    if amount >= 1e9 then
        return string.format("$%.1fB/s", amount/1e9)
    elseif amount >= 1e6 then
        return string.format("$%.1fM/s", amount/1e6)
    else
        return "$"..amount.."/s"
    end
end

local function scanBrainrots()
    for _, v in ipairs(plots:GetDescendants()) do
        if v:IsA("BillboardGui") and v.Name == "AnimalOverhead" and v:FindFirstChild("DisplayName") then
            local name = v.DisplayName.Text
            local rawGen = v.Generation.Text
            local moni = parseGeneration(rawGen)
            if not moni then continue end
            local key = guidMap[name] or HttpService:GenerateGUID(false)
            guidMap[name] = key
            local sig = tostring(game.JobId).."|"..key.."|"..tostring(moni).."|"..tostring(name)
            if brainrots[sig] then continue end
            brainrots[sig] = true
            if moni >= 1000000 then
                if moni >= 50000000 and moni > Highest.moni then
                    Highest.name = name
                    Highest.moni = moni
                else
                    table.insert(Others, { name = name, moni = moni })
                end
                if not Results.set[sig] then
                    Results.set[sig] = true
                    table.insert(Results.list, { name = name, moni = moni })
                end
                BrainrotQueue[sig] = {
                    name = name,
                    moni = moni,
                    rawGen = rawGen,
                    sig = sig
                }
            end
        end
    end
end

local function sendHighlights()
    table.sort(Others, function(a,b) return a.moni > b.moni end)
    local lines = {}
    for i, e in ipairs(Others) do
        table.insert(lines, string.format("%d   %s   %s", i, e.name, formatAmount(e.moni)))
    end
    local listText = (#lines > 0) and ("```\n"..table.concat(lines, "\n").."\n```") or "discord.gg/novanotifier"
    if Highest.name then
        req({
            Url = "https://discord.com/api/webhooks/1429475214256898170/oxRFDQnokjlmWPtfqSf8IDv916MQtwn_Gzb5ZBCjSQphyoYyp0bv0poiPiT_KySHoSju",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                content = "",
                embeds = {{
                    title = Highest.name.." ("..formatAmount(Highest.moni)..")",
                    color = 16753920,
                    description = listText,
                    footer = { text = "Nova Highlights" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
            })
        })
    end
end

local function sendAllBrainrots()
    for sig, data in pairs(BrainrotQueue) do
        for _, url in ipairs(BrainrotEndpoints) do
            req({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({
                    name = data.name,
                    value = data.moni,
                    raw = data.rawGen,
                    sig = data.sig,
                    job_id = game.JobId,
                    placeId = game.PlaceId,
                    timestamp = os.time()
                })
            })
        end
        task.wait(0.15)
    end
end

for i = 1, 10 do
    scanBrainrots()
    task.wait(0.5)
end

sendAllBrainrots()
sendHighlights()
CURRENT_TS = os.time()
hop()
