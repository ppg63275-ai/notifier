repeat task.wait() until game:IsLoaded()
local workspace = game:WaitForChild("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local plots = workspace:WaitForChild("Plots")
-- upd 0.2
local req = request or http_request or http and http.request
local HttpService = game:GetService("HttpService")
local api = "https://api.novanotifier.space/"
local brainrots = {}
local guidMap = {}
local Results = { set = {}, list = {} }

local Highest = { name = nil, moni = 0 }
local Others = {}
function nowts()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end
local TeleportService = game:GetService("TeleportService")
local tpFailed = false

TeleportService.TeleportInitFailed:Connect(function(_, result)
    tpFailed = true
end)

function next()
    local response = req({
        Url = api.."next",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({
            currentJob = tostring(game.JobId),
            minPlayers = 1
        })
    })
    if not response then
        return nil 
    end

    local success, data = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)

    if success and data and data.job then
        return tostring(data.job)
    end
    return nil
end

function release()
    local response = req({
        Url = api.."release",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({
            jobId = tostring(game.JobId)
        })
    })
end

local function tryTeleportTo(jobId)
    tpFailed = false
    local ok = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId)
    end)

    if not ok then
        return false
    end

    local start = os.clock()
    while os.clock() - start < 5 do
        if tpFailed then
            return false
        end
        task.wait(0.1)
    end
    return true
end


function hop()
    local id = next()
    if not id then 
        return 
    end

    coroutine.wrap(function()
        while true do

            if not id or #id <= 10 or id == game.JobId then
                task.wait(1 + math.random() * 0.2)
                id = next()
                continue
            end

            local d = 2.3 + math.random() * 0.3
            task.wait(d)

            local success = tryTeleportTo(id)
            if success then
                break
            end
        end
    end)()
end

local function parseGeneration(str)
    str = string.gsub(str, "[%$,/s,]", "")
    str = string.gsub(str, "%s+", "")
    local number, suffix = string.match(str, "([%d%.]+)([KMBT]?)")
    number = tonumber(number)
    if not number then return nil end
    local multipliers = { K = 1e3, M = 1e6, B = 1e9, T = 1e12, [""] = 1 }
    return number * (multipliers[suffix] or 1)
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

            local brainrotKey = name
            if not guidMap[brainrotKey] then
                guidMap[brainrotKey] = HttpService:GenerateGUID(false)
            end
            local key = guidMap[brainrotKey]
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
                req({
                    Url = "https://thatonexynnn.pythonanywhere.com/receive",
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode({
                        name = name or "Unknown",
                        value = moni or 0,
                        job_id = game.JobId
                    })
                })

                req({
                    Url = "https://prexy-psi.vercel.app/api/notify",
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode({
                        id = sig,
                        name = name,
                        amount = moni,
                        realAmount = rawGen,
                        jobId = game.JobId,
                        placeId = game.PlaceId,
                        players = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers),
                        timestamp = os.time(),
                    })
                })
            end
        end
    end
end

local function sendHighlights()
    table.sort(Others, function(a,b) return a.moni > b.moni end)
    local lines = {}
    for i, entry in ipairs(Others) do
        table.insert(lines, string.format("%d   %s   %s", i, entry.name, formatAmount(entry.moni)))
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

for i = 1, 10 do
    scanBrainrots()
    task.wait(0.5)
end
sendHighlights()
task.wait(0.1)
hop()
