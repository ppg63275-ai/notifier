local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local webhooks = {
    ["1_10m"] = "https://discord.com/api/webhooks/1428040124305903748/UVy0zNqrGVs9FBNOF4Kwz-iYYXIiKXSd7k2a9o-57BsoStBLNkA5JXMZYtYpIzwIEUfw",
    ["10_50m"] = "https://discord.com/api/webhooks/1428040239573897368/6wq30kOfV5UpvvTaMYtWS4XexS_WVMnS7A4_RGFGkmaEryqcxzvFNPR-ZlQGlh2vHpTM",
    ["50_100m"] = "https://discord.com/api/webhooks/1428040311447486474/sX2oyfRr0VOKcP_126njlI0BM_L2YnfFHFQ6G2xGWULv0KiTYvipXFNXhfWX_amWon-T",
    ["100m_plus"] = "https://discord.com/api/webhooks/1428040400119271536/PyoYUl6lDs0E5IDOByHR6K6nQrwVks1x7l_VngXrR4wCpyXKcIJFdvUTwIyXY11GLK-p",
    ["fallback"] = "https://discord.com/api/webhooks/1428040521506357340/uyM_lBa8nXE1jDjicysnnd2EK4hxa6Qk6Y-JEC4ou6rMFufwkG61MSrWkV4Nv0xuWpnC"
}

local roles = {
    ["1_10m"] = "<@&1428040722715639892>",
    ["10_50m"] = "<@&1428040796312965222>",
    ["50_100m"] = "<@&1428040887715237889>",
    ["100m_plus"] = "<@&1428040962139230268>",
    ["fallback"] = nil
}

local MONEY_RANGES = {
    TIER_1 = 1000000,
    TIER_2 = 10000000,
    TIER_3 = 50000000,
    TIER_4 = 100000000
}

local MIN_MONEY_THRESHOLD = 1000000
local placeId = 109983668079237
local timeout = 2

local visitedServers = {}
local busy = false
local lastJob = nil
local notified = {}
local cachedServers = {}
local eligibleServers = {}
local lastFetch = 0
local CACHE_DURATION = 1
local MAX_PAGES = 3
local hopping = false

local webhook_fallback_shadow = webhooks["fallback"]

local function parseMoney(text)
    if not text or text == "" then
        return 0
    end
    local t = string.upper(tostring(text)):gsub("[%s$,/]", ""):gsub(",", "")
    local num = tonumber(t:match("([%d%.]+)")) or 0
    if t:find("B") then
        return num * 1000000000
    elseif t:find("M") then
        return num * 1000000
    elseif t:find("K") then
        return num * 1000
    end
    return num
end

local function formatMoneyDisplay(moneyNum)
    if moneyNum >= 1000000000 then
        return "$" .. string.format("%.1f", moneyNum / 1000000000) .. "b/s"
    elseif moneyNum >= 1000000 then
        return "$" .. string.format("%.1f", moneyNum / 1000000) .. "m/s"
    elseif moneyNum >= 1000 then
        return "$" .. string.format("%.1f", moneyNum / 1000) .. "k/s"
    else
        return "$" .. tostring(moneyNum) .. "/s"
    end
end

local function getPlayerCount()
    local count = #Players:GetPlayers()
    local max = 8
    return string.format("%d/%d", count, max)
end

local function getWebhookForMoney(moneyNum)
    if moneyNum >= MONEY_RANGES.TIER_4 then
        return { webhooks["100m_plus"] }, roles["100m_plus"]
    elseif moneyNum >= MONEY_RANGES.TIER_3 then
        return { webhooks["50_100m"] }, roles["50_100m"]
    elseif moneyNum >= MONEY_RANGES.TIER_2 then
        return { webhooks["10_50m"] }, roles["10_50m"]
    elseif moneyNum >= MONEY_RANGES.TIER_1 then
        return { webhooks["1_10m"] }, roles["1_10m"]
    else
        return { webhooks["fallback"] }, roles["fallback"]
    end
end

local function sendMessage(msg, webhookUrl)
    local payload = HttpService:JSONEncode({ content = msg })
    local targetWebhook = webhookUrl or webhook_fallback_shadow
    request({
        Url = targetWebhook,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = payload
    })
end

local function sendDiscordEmbed(title, desc, color, fields, webhookUrl, shouldPing)
    local embed = {
        title = title,
        description = desc,
        color = color or 0xAB8AF2,
        fields = fields,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        footer = { text = "Made by xynnn sigma :)" }
    }
    local data = { embeds = { embed } }
    if shouldPing then
        data.content = "@everyone"
    end
    local targetWebhook = webhookUrl or webhook_fallback_shadow
    task.spawn(function()
        pcall(function()
            request({
                Url = targetWebhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(data)
            })
        end)
    end)
end

local function sendNotification(title, desc, color, fields, webhookUrls, rolePing)
    local embed = {
        title = title,
        description = desc,
        color = color or 0x9EE6B8,
        fields = fields,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        footer = { text = "Made by xynnn sigma :)" }
    }
    local data = { embeds = { embed } }
    if rolePing and rolePing ~= "" then
        data.content = rolePing
    end
    for _, webhookUrl in pairs(webhookUrls) do
        task.spawn(function()
            pcall(function()
                request({
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(data)
                })
            end)
        end)
    end
end

local function sendEmbeds(embeds, webhookUrl)
    local data = { embeds = embeds }
    local targetWebhook = webhookUrl or webhook_fallback_shadow
    request({
        Url = targetWebhook,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode(data)
    })
end

local function processBrainrotOverhead(overhead, playerCount, best)
    if not overhead then
        return best
    end
    local name, mpsText, valueText = "Unknown", "$0/s", "$0"
    for _, label in ipairs(overhead:GetChildren()) do
        if label:IsA("TextLabel") then
            local t = label.Text or ""
            if t:find("/s") then
                mpsText = t
            elseif t:match("^%$") and not t:find("/s") then
                valueText = t
            else
                name = t
            end
        end
    end
    local numericMPS = parseMoney(mpsText)
    if numericMPS >= MIN_MONEY_THRESHOLD and numericMPS > (best.bestValue or 0) then
        best.bestValue = numericMPS
        best.bestBrainrot = {
            name = name,
            moneyPerSec = mpsText,
            value = valueText,
            playerCount = playerCount,
            numericMPS = numericMPS
        }
    end
    return best
end

local function searchBonesForOverhead(root, best, depth, maxDepth)
    depth = depth or 0
    if not root or depth > (maxDepth or 10) then
        return
    end
    for _, node in ipairs(root:GetChildren()) do
        local n = node.Name or ""
        if n:find("Bone") then
            local hatAttachment = node:FindFirstChild("HatAttachment")
            if hatAttachment then
                local overheadAttachment = hatAttachment:FindFirstChild("OVERHEAD_ATTACHMENT")
                if overheadAttachment then
                    local animalOverhead = overheadAttachment:FindFirstChild("AnimalOverhead")
                    if animalOverhead then
                        processBrainrotOverhead(animalOverhead, #Players:GetPlayers(), best)
                    end
                end
            end
        end
        searchBonesForOverhead(node, best, depth + 1, maxDepth)
    end
end

local function findBestBrainrot()
    if not workspace then
        return nil
    end
    local playerCount = #Players:GetPlayers()
    local best = { bestValue = 0, bestBrainrot = nil }

    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local podiums = plot:FindFirstChild("AnimalPodiums")
            if podiums then
                for _, podium in ipairs(podiums:GetChildren()) do
                    local base = podium:FindFirstChild("Base")
                    if base then
                        local spawn = base:FindFirstChild("Spawn")
                        if spawn then
                            local attachment = spawn:FindFirstChild("Attachment")
                            if attachment then
                                local overhead = attachment:FindFirstChild("AnimalOverhead")
                                if overhead then
                                    processBrainrotOverhead(overhead, playerCount, best)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") then
            local frp = child:FindFirstChild("FakeRootPart")
            if frp then
                searchBonesForOverhead(frp, best, 0, 10)
            end
        end
    end

    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            for _, child in ipairs(plot:GetChildren()) do
                if child:IsA("Model") then
                    local frp = child:FindFirstChild("FakeRootPart")
                    if frp then
                        searchBonesForOverhead(frp, best, 0, 10)
                    end
                end
            end
        end
    end

    local knownBrainrotNames = { "Nuclearo Dinossauro", "Dragon Cannelloni" }
    for _, brainrotName in ipairs(knownBrainrotNames) do
        local brainrotModel = workspace:FindFirstChild(brainrotName)
        if brainrotModel then
            local frp = brainrotModel:FindFirstChild("FakeRootPart")
            if frp then
                searchBonesForOverhead(frp, best, 0, 10)
            end
        end
    end

    return best.bestBrainrot
end

local function fetchServers()
    if #eligibleServers > 0 and (tick() - lastFetch) <= CACHE_DURATION then
        return
    end
    lastFetch = tick()
    cachedServers = {}
    eligibleServers = {}
    local cursor = nil
    for _page = 1, MAX_PAGES do
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then
            url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
        end
        local response
        local ok1, res1 = pcall(function()
            return HttpService:GetAsync(url)
        end)
        if ok1 and res1 then
            response = res1
        else
            local ok2, res2 = pcall(function()
                return game:HttpGet(url)
            end)
            if ok2 and res2 then
                response = res2
            else
                break
            end
        end
        local okDecode, result = pcall(function()
            return HttpService:JSONDecode(response)
        end)
        if not okDecode or not result then
            break
        end
        if result.data then
            for _, server in ipairs(result.data) do
                table.insert(cachedServers, server)
                local playing = tonumber(server.playing) or 0
                local maxPlayers = tonumber(server.maxPlayers) or 0
                if server.id and playing < maxPlayers and playing <= 6 and not visitedServers[server.id] then
                    table.insert(eligibleServers, { id = server.id, playing = playing })
                end
            end
        end
        cursor = result.nextPageCursor
        if not cursor or #eligibleServers >= 10 then
            break
        end
        task.wait(0.05)
    end
    table.sort(eligibleServers, function(a, b)
        return (a.playing or 0) < (b.playing or 0)
    end)
end

local function getNextServer()
    if #eligibleServers == 0 or (tick() - lastFetch) > CACHE_DURATION then
        fetchServers()
    end
    
    if #eligibleServers > 0 then
        local randomRange = math.min(3, #eligibleServers)
        local randomIdx = math.random(1, randomRange)
        local entry = table.remove(eligibleServers, randomIdx)
        if entry and entry.id and not visitedServers[entry.id] then
            visitedServers[entry.id] = true
            return entry.id
        end
    end
    
    fetchServers()
    if #eligibleServers > 0 then
        local randomRange = math.min(3, #eligibleServers)
        local randomIdx = math.random(1, randomRange)
        local entry = table.remove(eligibleServers, randomIdx)
        if entry and entry.id then
            visitedServers[entry.id] = true
            return entry.id
        end
    end
    return nil
end

local function hopServer()
    if hopping then
        return
    end
    hopping = true
    fetchServers()
    local attempts, maxAttempts = 0, 5
    while attempts < maxAttempts do
        local nextServer = getNextServer()
        if nextServer then
            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, nextServer, Players.LocalPlayer)
            end)
            if ok then
                return
            end
            attempts += 1
            task.wait(0.1)
        else
            attempts += 1
            task.wait(0.15)
            fetchServers()
        end
    end
    hopping = false
    task.delay(1, function()
        hopServer()
    end)
end

local function notifyBrainrot()
    if busy then
        return
    end
    busy = true
    local ok, bestBrainrot = pcall(findBestBrainrot)
    if not ok then
        task.spawn(function()
            task.wait(0.01)
            busy = false
        end)
        return
    end
    if bestBrainrot then
        local players = getPlayerCount()
        local jobId = game.JobId or "Unknown"
        local brainrotKey = jobId .. "_" .. bestBrainrot.name .. "_" .. bestBrainrot.moneyPerSec
        if not notified[brainrotKey] then
            notified[brainrotKey] = true
            lastJob = jobId
            local targetWebhooks, rolePing = getWebhookForMoney(bestBrainrot.numericMPS)
            local fields = {
                { name = "🏷️ Name", value = bestBrainrot.name, inline = true },
                { name = "💰 Money per sec", value = bestBrainrot.moneyPerSec, inline = true },
                { name = "👥 Players", value = players, inline = true },
                { name = "🔗 Join Link", value = "[Click to Join](https://testing5312.github.io/joiner/?placeId=109983668079237&gameInstanceId=" .. jobId .. ")", inline = false },
                { name = "Job ID (Mobile)", value = "`" .. jobId .. "`", inline = false },
                { name = "Job ID (PC)", value = "```" .. jobId .. "```", inline = false },
                { name = "Join Script (PC)", value = "```game:GetService(\"TeleportService\"):TeleportToPlaceInstance(109983668079237,\"" .. jobId .. "\",game.Players.LocalPlayer)```", inline = false }
            }
            sendNotification("Hamburger Wings Notifier", "", 0x9EE6B8, fields, targetWebhooks, rolePing)
        end
    end
    task.spawn(function()
        task.wait(0.01)
        busy = false
    end)
end

local function retryLoop()
    while true do
        task.wait(0.1)
        local ok = pcall(notifyBrainrot)
        if not ok then
            task.wait(0.1)
        end
    end
end

task.spawn(retryLoop)
pcall(function()
    notifyBrainrot()
end)

local randomStartDelay = math.random(1, 10) / 10
task.wait(randomStartDelay)

local start = tick()
local timeoutConn
timeoutConn = RunService.Heartbeat:Connect(function()
    if tick() - start > timeout then
        timeoutConn:Disconnect()
        hopServer()
    end
end)

TeleportService.TeleportInitFailed:Connect(function(_, _, _)
    hopping = false
    task.wait(0.1)
    hopServer()
end)

Players.LocalPlayer.OnTeleport:Connect(function(teleportState)
    if teleportState == Enum.TeleportState.Started then
        if timeoutConn then
            timeoutConn:Disconnect()
        end
    end
end)

hopServer()
queue_on_teleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/ppg63275-ai/notifier/refs/heads/main/main.lua"))()')
