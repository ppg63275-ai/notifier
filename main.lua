-- hi
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
	if not req then
		return nil
	end
	local ok,res = pcall(function() return req(opt) end)
	if ok and res then
		return res
	end
	return nil
end

local function shortMoney(v)
	v = tonumber(v) or 0
	if v >= 1e9 then
		return "$"..string.format("%.2f",v/1e9):gsub("%.?0+$","").."B/s"
	elseif v >= 1e6 then
		return "$"..string.format("%.2f",v/1e6):gsub("%.?0+$","").."M/s"
	elseif v >= 1e3 then
		return "$"..string.format("%.0f",v/1e3).."K/s"
	else
		return "$"..math.floor(v).."/s"
	end
end

local function getWebhookForMPS(mps)
	for _, tier in ipairs(WEBHOOK_TIERS) do
		if mps >= tier.min and (not tier.max or mps <= tier.max) then
			return tier.url, tier.role
		end
	end
	return nil, nil
end

local function sendWebhook(b)
	if not b or not b.Key or b.Amount < 1_000_000 then return end
	local url, role = getWebhookForMPS(b.Amount)
	if not url then return end
	local sig = tostring(game.JobId).."|"..tostring(b.Key).."|"..tostring(math.floor(b.Amount))
	if sentKeys[sig] then return end
	sentKeys[sig] = true
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
	local embed = {
		title = "🌌 Nova Notifier",
		color = 16711680,
		fields = {
			{ name = "🏷️ Name", value = "**"..tostring(b.Name or "Unknown").."**", inline = true },
			{ name = "💰 Money per sec", value = "**"..shortMoney(b.Amount).."**", inline = true },
			{ name = "👥 Players", value = tostring(#Players:GetPlayers()).."/"..tostring(Players.MaxPlayers or 0), inline = true },
			{ name = "**📱 Job-ID (Mobile):**", value = tostring(jobId), inline = false },
            { name = "**Job ID (PC)**", value = "```" .. tostring(formattedJobId) .. "```", inline = false },
            { name = "**🌐Join Link**", value = "[**Click to Join**](" .. browserLink .. ")", inline = false },
            { name = "**📜Join Script (PC)**", value = "```" .. joinScript .. "```", inline = false },           
		},
		footer = { text = "Made by  Xynnn 至"..os.date("%H:%M:%S") }
	}

	requestSafe({
		Url = url,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode({ content = role, embeds = { embed } })
	})
	pcall(function()
		requestSafe({
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
end
local function scanModel()
	print("[SCAN-START]", os.time())

	local function singleScan()
		local found, seen = {}, {}
		for _, plot in ipairs(Plots:GetChildren()) do
			for _, v in ipairs(plot:GetDescendants()) do
				if v.Name == "Generation" and v:IsA("TextLabel") and v.Parent:IsA("BillboardGui") then
					local raw = v.Text
					local text = tostring(raw or ""):gsub("[,%$]", ""):gsub("/s", "")
					local amt = tonumber(text) or 0
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
							table.insert(found, {
								Name = disp,
								Amount = amt,
								RealAmount = raw,
								Key = key
							})
							print("[SCAN-FIND]", disp, raw, amt, key, os.time())
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
	print("[SCAN-END]", #combined, os.time())

	return combined
	end
local lastAttemptJobId, lastFailAt = nil, 0
local lastTeleportAt = 0
local function nextServer()
	local ok, res = pcall(function()
		local r = requestSafe({
			Url = BACKEND_URL.."next",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				placeId = game.PlaceId,
				currentJob = game.JobId,
				minPlayers = MIN_PLAYERS
			})
		})
		return r and HttpService:JSONDecode(r.Body)
	end)
	if ok and res and res.job then
		return tostring(res.job)
	else
		print("backend might be not online.")
	end
	return nil
end

local function releaseKey(serverId)
	if not serverId then return end
	pcall(function()
		requestSafe({
			Url = BACKEND_URL.."release",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				placeId = game.PlaceId,
				key = tostring(serverId)
			})
		})
	end)
end
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
	if not game:IsLoaded() then game.Loaded:Wait() end
	local results = scanModel()

	if #results > 0 then
		print(string.rep("-", 50))
		print("results :")
		for i, data in ipairs(results) do
			print(string.format("[%02d] %s — %s", i, data.Name, shortMoney(data.Amount)))
			if not seenAll[data.Key] then
				seenAll[data.Key] = true
				sendWebhook(data)
			end
		end
		print(string.rep("-", 50))
	else
		print("No Brainrots found after 5 scans.")
	end

	task.wait(WEBHOOK_REFRESH)
end)
task.spawn(function()
    if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
    task.wait(0.8 + math.random(200,800)/1000)
    task.spawn(hopLoop)
end)
