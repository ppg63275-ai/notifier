local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Plots = workspace:WaitForChild("Plots")
local LocalPlayer = Players.LocalPlayer

local BACKEND_URL = "http://127.0.0.1:5000/"
local MIN_PLAYERS = 1
local WEBHOOK_REFRESH = 0.2
local HIGHLIGHT_BATCH_TIMEOUT = 3
local TP_MIN_GAP_S = 1
local TP_JITTER_MIN_S = 0.5
local TP_JITTER_MAX_S = 0.5
local TP_STUCK_TIMEOUT = 12.0

local pendingHighlight = nil
local batchTimer = nil
local sentKeys = {}
local seenAll = {}

local WEBHOOK_TIERS = {
    { min = 1_000_000,   max = 10_000_000,  url = "https://discord.com/api/webhooks/1433733516004294787/_9vwNoCSaDlys-IGNp-AeEv1R1T5prGQWb03YhGmBVVRtPsxSMScRQB_ns8cshE_lvy4", role = "<@&1428040722715639892>" },
    { min = 10_000_001,  max = 50_000_000,  url = "https://discord.com/api/webhooks/1433733679829487678/rIv0Uc8onK4Y1C-g-UUeS5QpNXwslZKWcp6HNgCjthxG5QlR_cy2jMwESd5WUVT4q4b0", role = "<@&1428040796312965222>" },
    { min = 50_000_001,  max = 100_000_000, url = "https://discord.com/api/webhooks/1433733786717392947/KJ0o6POenJS2gyl4AaYCDrastpqrQcMKSOL83GpkkHsL-atTFaeyPDyoZ1X6mDSThpqN", role = "<@&1428040887715237889>" },
    { min = 100_000_001, url = "https://discord.com/api/webhooks/1433733878786555954/QzZmkUihQrePxwlEgimTZ-j0iX7cBy_r8fnvr9XcJ6zIknLSgXQpJ1_9rscfDjop5jhS", role = "<@&1428040962139230268>" },
}

local PYTHONANYWHERE_URL = "https://thatonexynnn.pythonanywhere.com/receive"

local function requestSafe(opt)
    local req = rawget(_G,"http_request") or rawget(_G,"request") or (syn and syn.request) or (http and http.request)
    if req then
        local ok,res = pcall(function() return req(opt) end)
        if ok then return res end
    end
    return nil
end

local function shortMoney(v)
    v=tonumber(v) or 0
    if v>=1e9 then return "$"..string.format("%.2f",v/1e9):gsub("%.?0+$","").."B/s"
    elseif v>=1e6 then return "$"..string.format("%.2f",v/1e6):gsub("%.?0+$","").."M/s"
    elseif v>=1e3 then return "$"..string.format("%.0fK/s",v/1e3)
    else return "$"..math.floor(v).."/s" end
end

local function getWebhookForMPS(mps)
    for _, tier in ipairs(WEBHOOK_TIERS) do
        if mps >= tier.min and (not tier.max or mps <= tier.max) then
            return tier.url, tier.role
        end
    end
    return nil, nil
end

local function sendBatchedToHighlight()
    if not pendingHighlight or #pendingHighlight==0 then return end
    table.sort(pendingHighlight,function(a,b) return a.Amount>b.Amount end)
    local top=pendingHighlight[1]
    local others={}
    for i=2,#pendingHighlight do table.insert(others,string.format("• **%s** - %s",pendingHighlight[i].Name,shortMoney(pendingHighlight[i].Amount))) end
    local othersText=(#others>0) and table.concat(others,"\n") or "No other high-value brainrots found"
    local primary="https://discord.com/api/webhooks/1429475214256898170/oxRFDQnokjlmWPtfqSf8IDv916MQtwn_Gzb5ZBCjSQphyoYyp0bv0poiPiT_KySHoSju"
    local backup="https://discord.com/api/webhooks/1431961807760789576/UM-yI6DQUnyMgRZhTUIgFpPV7L90bN2HAXQCnx9nYJs-NrCkDthJiY4x3Eu3GQySAcap"
    local data=HttpService:JSONEncode({content="",embeds={{title="Nova Notifier Highlights",color=16711680,fields={{name="Results Found:",value="**"..(top.Name or "Unknown").."**\n"..shortMoney(top.Amount),inline=false},{name="Other High-Value Finds",value=othersText,inline=false}},footer={text="Coded by Xynnn 至"},timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ")}}})
    local r=requestSafe({Url=primary,Method="POST",Headers={["Content-Type"]="application/json"},Body=data})
    if r and tonumber(r.StatusCode)==429 then requestSafe({Url=backup,Method="POST",Headers={["Content-Type"]="application/json"},Body=data}) end
    pendingHighlight=nil
end

local function addToBatch(b)
    if not pendingHighlight then pendingHighlight={} end
    for _,e in ipairs(pendingHighlight) do if e.Key==b.Key then return end end
    table.insert(pendingHighlight,b)
    if batchTimer then task.cancel(batchTimer) end
    batchTimer=task.delay(HIGHLIGHT_BATCH_TIMEOUT,sendBatchedToHighlight)
end

local function sendWebhook(b)
    if not b or not b.Key or b.Amount<1_000_000 then return end
    local url,role=getWebhookForMPS(b.Amount)
    if not url then return end
    local sig=tostring(game.JobId).."|"..tostring(b.Key).."|"..tostring(math.floor(b.Amount))
    if sentKeys[sig] then return end
    sentKeys[sig]=true
    local embed={title="🌌 Nova Notifier",color=16711680,fields={{name="🏷️ Name",value="**"..tostring(b.Name or "Unknown").."**",inline=true},{name="💰 Money per sec",value="**"..shortMoney(b.Amount).."**",inline=true},{name="**👥 Players:**",value="**"..tostring(#Players:GetPlayers()-1).."**/**"..tostring(Players.MaxPlayers or 0).."**",inline=true}},footer={text="Made by Xynnn 至 • Today at "..os.date("%H:%M:%S",os.time())}}
    requestSafe({Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({content=role,embeds={embed}})})
    if b.Amount>=50_000_000 then addToBatch(b) end
    pcall(function() requestSafe({Url=PYTHONANYWHERE_URL,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({name=b.Name or "Unknown",value=b.Amount or 0,job_id=game.JobId})}) end)
end

local function singleScan()
    local results, seen = {}, {}
    for _,plot in ipairs(Plots:GetChildren()) do
        for _,v in ipairs(plot:GetDescendants()) do
            if v.Name=="Generation" and v:IsA("TextLabel") and v.Parent:IsA("BillboardGui") then
                local amt=tonumber(v.Text:gsub(",",""):gsub("%$",""):gsub("/s","")) or 0
                if amt>0 then
                    local spawn=v.Parent.Parent.Parent
                    local disp=(v.Parent:FindFirstChild("DisplayName") and v.Parent.DisplayName.Text) or "Unknown"
                    local key=spawn and (spawn:GetAttribute("BrainrotId") or HttpService:GenerateGUID(false)) or (disp..":"..v.Parent.Parent:GetFullName())
                    if spawn and not spawn:GetAttribute("BrainrotId") then spawn:SetAttribute("BrainrotId",key) end
                    if not seen[key] then seen[key]=true table.insert(results,{Name=disp,Amount=amt,Key=key}) end
                end
            end
        end
    end
    return results
end

local function scanModel()
    local combined={},seenAll={}
    for i=1,5 do
        local batch=singleScan()
        local added=0
        for _,b in ipairs(batch) do
            if not seenAll[b.Key] then
                seenAll[b.Key]=true
                table.insert(combined,b)
                added+=1
            end
        end
        task.wait(0.3)
    end
    table.sort(combined,function(a,b) return a.Amount>b.Amount end)
    return combined
end

task.spawn(function()
    while true do
        local results=scanModel()
        for _,data in ipairs(results) do
            if not seenAll[data.Key] then
                seenAll[data.Key]=true
                sendWebhook(data)
            end
        end
        task.wait(WEBHOOK_REFRESH)
    end
end)

local lastAttemptJobId,lastFailAt,lastTeleportAt=nil,0,0

local function nextServer()
    local ok,res=pcall(function()
        return HttpService:JSONDecode(requestSafe({Url=BACKEND_URL.."next",Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({placeId=game.PlaceId,currentJob=game.JobId,minPlayers=MIN_PLAYERS})}).Body)
    end)
    if ok and res and res.job then return tostring(res.job) end
    return nil
end

local function releaseKey(serverId)
    if not serverId then return end
    pcall(function() requestSafe({Url=BACKEND_URL.."release",Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({placeId=game.PlaceId,key=tostring(serverId})}) end)
end

local function tryTeleportTo(jobId)
    lastAttemptJobId=tostring(jobId)
    local ok,_=pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId,lastAttemptJobId,LocalPlayer) end)
    lastTeleportAt=os.clock()
    if not ok then releaseKey(lastAttemptJobId) return false end
    task.spawn(function()
        local start=os.clock()
        task.wait(TP_STUCK_TIMEOUT)
        if lastFailAt<start then
            local nid=nextServer()
            if nid then tryTeleportTo(nid) end
        end
    end)
    return true
end

TeleportService.TeleportInitFailed:Connect(function()
    lastFailAt=os.clock()
    if lastAttemptJobId then releaseKey(lastAttemptJobId) end
    task.wait(0.6)
    local nextId=nextServer()
    if nextId then tryTeleportTo(nextId) end
end)

local function markJoinedOnce()
    local jid=tostring(game.JobId)
    if shared.__QUESAID_LAST_MARKED__==jid then return end
    shared.__QUESAID_LAST_MARKED__=jid
    task.delay(2,function()
        pcall(function() requestSafe({Url=BACKEND_URL.."joined",Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({placeId=game.PlaceId,serverId=jid})}) end)
    end)
end

task.spawn(function() if not game:IsLoaded() then game.Loaded:Wait() end markJoinedOnce() end)
Players.LocalPlayer.CharacterAdded:Connect(markJoinedOnce)
