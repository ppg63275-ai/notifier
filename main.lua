local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
getgenv().MinGeneration = "1M/S"
local PlaceID, JobId = game.PlaceId, game.JobId
local tried, foundCursor = {}, ""
local fileName = "NotSameServers.json"
local AllIDs = {}
local hourNow = os.date("!*t").hour
if not isfile(fileName) then
    AllIDs = { hourNow }
    writefile(fileName, HttpService:JSONEncode(AllIDs))
else
    AllIDs = HttpService:JSONDecode(readfile(fileName))
    if AllIDs[1] ~= hourNow then
        AllIDs = { hourNow }
        writefile(fileName, HttpService:JSONEncode(AllIDs))
    end
end
local function cleanGenText(t)
    local s = tostring(t or ""):upper()
    s = s:gsub("%$", ""):gsub(",", ""):gsub("%s+", "")
    if not s:find("/S") and s:match("^%d+%.?%d*[KMB]$") then s = s.."/S" end
    return s
end

local function getPlotOwner(plot)
    for _, d in ipairs(plot:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text and d.Text:find("'s Base") then
            return d.Text:gsub("'s Base", "")
        end
    end
    return "Unknown"
end

local function isValidGenerationText(text)
    local s = cleanGenText(text)
    return s:match("^%d+%.?%d*[KMB]/S$") ~= nil
end

local function parseGeneration(genStr)
    local s = cleanGenText(genStr):gsub("/S", "")
    local mult = 1
    if s:find("K") then mult, s = 1e3, s:gsub("K", "")
    elseif s:find("M") then mult, s = 1e6, s:gsub("M", "")
    elseif s:find("B") then mult, s = 1e9, s:gsub("B", "")
    end
    local num = tonumber(s) or 0
    return num * mult
end

local function findGroupedBrainrots()
    local grouped = {}
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return grouped end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = getPlotOwner(plot)
        if owner ~= LocalPlayer.DisplayName then
            local seen = {}
            for _, gen in ipairs(plot:GetDescendants()) do
                if gen:IsA("TextLabel") and gen.Name == "Generation" then
                    local raw = tostring(gen.Text or "")
                    if isValidGenerationText(raw) then
                        local podium = gen.Parent
                        if podium and not seen[podium] then
                            local skip = false
                            for _, v in ipairs(podium:GetDescendants()) do
                                if v:IsA("TextLabel") then
                                    local lname = tostring(v.Name or ""):lower()
                                    local ltext = tostring(v.Text or ""):upper()
                                    if (lname:find("ready!") or ltext:find("READY!")) and ltext:find("IN MACHINE") then
                                        skip = true
                                        break
                                    end
                                end
                            end
                            if not skip then
                                local displayName = "Unknown"
                                for _, v in ipairs(podium:GetDescendants()) do
                                    if v:IsA("TextLabel") and v.Name == "DisplayName" then
                                        displayName = v.Text or displayName
                                        break
                                    end
                                end
                                seen[podium] = true
                                grouped[owner] = grouped[owner] or {}
                                table.insert(grouped[owner], {
                                    displayName = displayName,
                                    generationRaw = raw,
                                    generationClean = cleanGenText(raw),
                                    instance = podium
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    return grouped
end

local function getNextServer()
    local url = "https://games.roblox.com/v1/games/"..PlaceID.."/servers/Public?sortOrder=Asc&limit=100"
    if foundCursor ~= "" then url ..= "&cursor="..foundCursor end
    local ok, data = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if not ok or not data or not data.data then return end
    foundCursor = data.nextPageCursor or ""
    for _, s in ipairs(data.data) do
        local id = tostring(s.id or "")
        if id ~= "" and s.playing and s.maxPlayers and s.playing < s.maxPlayers and id ~= JobId and not tried[id] then
            if not table.find(AllIDs, id) then
                table.insert(AllIDs, id)
                writefile(fileName, HttpService:JSONEncode(AllIDs))
                tried[id] = true
                return id
            end
        end
    end
end
local function hopServer()
    local id = getNextServer()
    if id and id ~= "" then
        TeleportService:TeleportToPlaceInstance(PlaceID, id)
    else
        task.wait(2)
    end
end
local role1to10m = "<@1428040722715639892>"
local role10to50m = "<@1428040796312965222>"
local role50to100m = "<@1428040887715237889>"
local role100mplus = "<@1428040962139230268>"

local webhook1to10m = "https://discord.com/api/webhooks/1428040124305903748/UVy0zNqrGVs9FBNOF4Kwz-iYYXIiKXSd7k2a9o-57BsoStBLNkA5JXMZYtYpIzwIEUfw"
local webhook10to50m = "https://discord.com/api/webhooks/1428040239573897368/6wq30kOfV5UpvvTaMYtWS4XexS_WVMnS7A4_RGFGkmaEryqcxzvFNPR-ZlQGlh2vHpTM"
local webhook50to100m = "https://discord.com/api/webhooks/1428040311447486474/sX2oyfRr0VOKcP_126njlI0BM_L2YnfFHFQ6G2xGWULv0KiTYvipXFNXhfWX_amWon-T"
local webhook100mplus = "https://discord.com/api/webhooks/1428040400119271536/PyoYUl6lDs0E5IDOByHR6K6nQrwVks1x7l_VngXrR4wCpyXKcIJFdvUTwIyXY11GLK-p"
local VERCEL_URL = "https://proxilero.vercel.app/api/notify"
local API_KEY = "xynnnwashere!"

local function forwardToProxy(displayName, genRaw, genVal, placeId, jobId, mentionRole)
    local f = syn and syn.request or http_request or request or http and http.request
    if typeof(f) ~= "function" then return false end

    local body = HttpService:JSONEncode({
        displayName = displayName,
        genRaw = genRaw,
        genVal = genVal,
        placeId = placeId,
        jobId = jobId,
        mentionRole = mentionRole
    })

    local ok, res = pcall(function()
        return f({
            Url = VERCEL_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["x-api-key"] = API_KEY
            },
            Body = body
        })
    end)

    return ok and res and res.Success
end

local function sendNotify(grouped)
    local minRequired = parseGeneration(getgenv().MinGeneration)
    local sentSomething = false

    for owner, items in pairs(grouped) do
        for _, b in ipairs(items) do
            local val = parseGeneration(b.generationClean)
            if val >= minRequired then
                local mentionRole = ""
                if val >= 1e6 and val < 1e7 then
                    mentionRole = role1to10m
                elseif val >= 1e7 and val < 5e7 then
                    mentionRole = role10to50m
                elseif val >= 5e7 and val < 1e8 then
                    mentionRole = role50to100m
                elseif val >= 1e8 then
                    mentionRole = role100mplus
                end

                local ok = pcall(function()
                    forwardToProxy(b.displayName, b.generationRaw, val, PlaceID, JobId, mentionRole)
                end)

                if ok then
                    sentSomething = true
                    task.wait(0.1)
                end
            end
        end
    end

    return sentSomething
end
local function startFinder()
    while true do
        local grouped = findGroupedBrainrots()
        if not grouped then
            repeat local ok = pcall(hopServer) until ok
            continue
        end

        local minReq = parseGeneration(getgenv().MinGeneration)
        local notifyGrouped = {}
        local instancesToMark = {}
        local foundAny = false

        for owner, list in pairs(grouped) do
            if type(list) == "table" and #list > 0 then
                for _, item in ipairs(list) do
                    local inst = item.instance
                    if inst and not inst:GetAttribute("sent") then
                        local val = parseGeneration(item.generationClean)
                        if val >= minReq then
                            notifyGrouped[owner] = notifyGrouped[owner] or {}
                            table.insert(notifyGrouped[owner], {
                                displayName = item.displayName,
                                generationRaw = item.generationRaw,
                                generationClean = item.generationClean
                            })
                            table.insert(instancesToMark, inst)
                            foundAny = true
                        end
                    end
                end
            end
        end

        if foundAny then
    for _, inst in ipairs(instancesToMark) do
        pcall(function() inst:SetAttribute("sent", true) end)
    end
    local sent = pcall(function() return sendNotify(notifyGrouped) end)
    if sent then
        repeat local ok = pcall(hopServer) until ok
    else
        repeat local ok = pcall(hopServer) until ok
    end
else
    repeat local ok = pcall(hopServer) until ok
       end
    end
end

startFinder()
