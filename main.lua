local L_1_ = game:GetService("HttpService")
local L_2_ = game:GetService("TeleportService")
local L_3_ = game:GetService("Players")
local L_4_ = L_3_.LocalPlayer
local L_5_ = workspace:WaitForChild("Plots")
local L_6_ = getgenv and getgenv() or _G
local function L_7_func()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function L_8_func(L_30_arg0)
	local function L_31_func(L_32_arg0, L_33_arg1)
		local L_34_, L_35_ = pcall(L_32_arg0, L_33_arg1)
		if L_34_ and L_35_ then
			return L_35_
		end
		return nil
	end
	if request then
		local L_37_ = L_31_func(request, L_30_arg0)
		if L_37_ then
			return L_37_
		end
	end
	if http_request then
		local L_38_ = L_31_func(http_request, L_30_arg0)
		if L_38_ then
			return L_38_
		end
	end
	if http and http.request then
		local L_39_ = L_31_func(http.request, L_30_arg0)
		if L_39_ then
			return L_39_
		end
	end
	if type(L_30_arg0) == "table" and L_30_arg0.Url and L_30_arg0.Method == "GET" then
		local L_40_, L_41_ = pcall(function()
			return {
				Body = L_1_:GetAsync(L_30_arg0.Url),
				StatusCode = 200
			}
		end)
		if L_40_ and L_41_ then
			print("[HTTP-RSP] fallback", L_41_.StatusCode, L_7_func())
			return L_41_
		end
	end
	print("[HTTP-ERR] no method", L_7_func())
	return nil
end

local function L_9_func(L_42_arg0)
	local L_43_ = (L_42_arg0 or ""):gsub(",", ""):gsub("%s*/s%s*", ""):gsub("%$", "")
	local L_44_ = 1
	if L_43_:find("K") then
		L_44_ = 1e3
	elseif L_43_:find("M") then
		L_44_ = 1e6
	elseif L_43_:find("B") then
		L_44_ = 1e9
	elseif L_43_:find("T") then
		L_44_ = 1e12
	end
	L_43_ = L_43_:gsub("[KMBT]", "")
	local L_45_ = tonumber(L_43_)
	return L_45_ and (L_45_ * L_44_) or 0
end

	local L_47_, L_48_ = {}, {}
	local L_49_ = math.random(5, 10)
	local function L_10_func()
    print("[SCAN-START]", L_7_func())
    local function L_46_func()
        local L_52_, L_53_ = {}, {}
        for L_54_forvar0, L_55_forvar1 in ipairs(L_5_:GetChildren()) do
            for L_56_forvar0, L_57_forvar1 in ipairs(L_55_forvar1:GetDescendants()) do
                if L_57_forvar1.Name == "Generation" and L_57_forvar1:IsA("TextLabel") and L_57_forvar1.Parent:IsA("BillboardGui") then
                    local L_58_ = L_57_forvar1.Text
                    local L_59_ = L_9_func(L_58_)
                    if L_59_ > 0 then
                        local L_60_ = L_57_forvar1.Parent.Parent.Parent
                        local L_61_ = (L_57_forvar1.Parent:FindFirstChild("DisplayName") and L_57_forvar1.Parent.DisplayName.Text) or "Unknown"
                        local L_62_
                        if L_60_ then
                            L_62_ = L_60_:GetAttribute("BrainrotId")
                            if not L_62_ then
                                L_62_ = L_1_:GenerateGUID(false)
                                L_60_:SetAttribute("BrainrotId", L_62_)
                            end
                        else
                            L_62_ = L_61_ .. ":" .. L_57_forvar1.Parent.Parent:GetFullName()
                        end
                        if not L_53_[L_62_] then
                            L_53_[L_62_] = true
                            table.insert(L_52_, {
                                Name = L_61_,
                                Amount = L_59_,
                                RealAmount = L_58_,
                                Key = L_62_
                            })
                            print("[SCAN-FIND]", L_61_, L_58_, L_59_, L_62_, L_7_func())
                        end
                    end
                  task.wait(0.2)
                end
            end
        end
        return L_52_
    end
    local L_50_ = os.clock()
	local L_51_ = 0
	while os.clock() - L_50_ < L_49_ do
		local L_63_ = L_46_func()
		L_51_ += 1
		local L_64_ = 0
		for L_65_forvar0, L_66_forvar1 in ipairs(L_63_) do
			if not L_48_[L_66_forvar1.Key] then
				L_48_[L_66_forvar1.Key] = true
				table.insert(L_47_, L_66_forvar1)
				L_64_ += 1
			end
		end
		print(string.format("[SCAN-%d] %d new (total %d)", L_51_, L_64_, # L_47_))
		task.wait(0.1)
	end
	table.sort(L_47_, function(L_67_arg0, L_68_arg1)
		return L_67_arg0.Amount > L_68_arg1.Amount
	end)
	print("[SCAN-END]", # L_47_, L_7_func())
	return L_47_
end

local function L_11_func(L_69_arg0)
	if L_69_arg0 >= 1e9 then
		local L_70_ = L_69_arg0 / 1e9
		return (L_70_ % 1 == 0) and ("$" .. math.floor(L_70_) .. "B/s") or ("$" .. string.format("%.1fB/s", L_70_))
	elseif L_69_arg0 >= 1e6 then
		local L_71_ = L_69_arg0 / 1e6
		return (L_71_ % 1 == 0) and ("$" .. math.floor(L_71_) .. "M/s") or ("$" .. string.format("%.1fM/s", L_71_))
	else
		return "$" .. L_69_arg0 .. "/s"
	end
end

function sendtohighlight(L_72_arg0, L_73_arg1)
	print("[HL-SEND]", L_72_arg0, L_73_arg1, L_7_func())
	local L_74_ = "https://discord.com/api/webhooks/1429475214256898170/oxRFDQnokjlmWPtfqSf8IDv916MQtwn_Gzb5ZBCjSQphyoYyp0bv0poiPiT_KySHoSju"
	local L_75_ = "https:/ /discord.com/api/webhooks/1431961807760789576/UM-yI6DQUnyMgRZhTUIgFpPV7L90bN2HAXQCnx9nYJs-NrCkDthJiY4x3Eu3GQySAcap"
	local L_76_ = L_1_:JSONEncode({
		content = "",
		embeds = {
			{
				title = "🚨 Brainrot Found by Bot! | Nova Notifier",
				color = 16711680,
				fields = {
					{
						name = "Name",
						value = L_73_arg1 or "Unknown",
						inline = true
					},
					{
						name = "Amount",
						value = L_11_func(L_72_arg0),
						inline = true
					},
				},
				footer = {
					text = "Coded by Xynnn 至"
				},
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
			}
		}
	})
	local L_77_ = L_8_func({
		Url = L_74_,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json"
		},
		Body = L_76_
	})
	if L_77_ and tonumber(L_77_.StatusCode) == 429 then
		print("[HL-RATE-LIMIT]", L_7_func())
		L_8_func({
			Url = L_75_,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = L_76_
		})
	end
end

local L_12_ = "https://prexy-psi.vercel.app/api/notify"
local L_13_ = "https://thatonexynnn.pythonanywhere.com/receive"

local L_14_ = getgenv and getgenv() or _G
L_14_.__SentWebhooks = L_14_.__SentWebhooks or {}

local function L_15_func(L_78_arg0)
	if not L_78_arg0 or not L_78_arg0.Key then
		return
	end
	if L_78_arg0.Amount < 1000000 then
		return
	end
	local L_79_ = tostring(game.JobId) .. "|" .. tostring(L_78_arg0.Key) .. "|" .. tostring(L_78_arg0.RealAmount) .. "|" .. tostring(L_78_arg0.Name)
	if L_14_.__SentWebhooks[L_79_] then
		return
	end
	L_14_.__SentWebhooks[L_79_] = true
	local L_80_ = {
		id = L_79_,
		name = L_78_arg0.Name or "Unknown",
		amount = L_78_arg0.Amount or 0,
		realAmount = L_78_arg0.RealAmount or "",
		jobId = game.JobId,
		placeId = game.PlaceId,
		players = tostring(# L_3_:GetPlayers()) .. "/" .. tostring(L_3_.MaxPlayers),
		timestamp = os.time(),
	}
	coroutine.wrap(function()
		pcall(function()
			L_8_func({
				Url = L_12_,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json"
				},
				Body = L_1_:JSONEncode(L_80_)
			})
		end)
	end)()
	coroutine.wrap(function()
		pcall(function()
			L_8_func({
				Url = L_13_,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json"
				},
				Body = L_1_:JSONEncode({
					name = L_78_arg0.Name or "Unknown",
					value = L_78_arg0.Amount or 0,
					job_id = game.JobId
				})
			})
		end)
	end)()
	if L_78_arg0.Amount >= 50000000 then
		sendtohighlight(L_78_arg0.Amount, L_78_arg0.Name)
	end
end

local L_16_ = "https://api.novanotifier.space"

local function L_17_func()
	local L_81_ = L_8_func({
		Url = L_16_ .. "/next",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json"
		},
		Body = L_1_:JSONEncode({
			currentJob = game.JobId,
			minPlayers = 6
		})
	})
	if not L_81_ then
		return nil
	end
	local L_82_, L_83_ = pcall(function()
		return L_1_:JSONDecode(L_81_.Body)
	end)
	if L_82_ and L_83_ and L_83_.job then
		print("[API-NEXT]", L_83_.job, L_7_func())
		return tostring(L_83_.job)
	end
	print("[API-NEXT-NIL]", L_7_func())
	return nil
end

local function L_18_func(L_84_arg0)
	print("[API-REL]", L_84_arg0, L_7_func())
	L_8_func({
		Url = L_16_ .. "/release",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json"
		},
		Body = L_1_:JSONEncode({
			jobId = L_84_arg0
		})
	})
end

local function L_19_func(L_85_arg0)
	print("[API-JOIN]", L_85_arg0, L_7_func())
	L_8_func({
		Url = L_16_ .. "/joined",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json"
		},
		Body = L_1_:JSONEncode({
			jobId = L_85_arg0
		})
	})
end

local function L_20_func()
	local L_86_ = math.random(math.floor(0.5), math.floor(0.5)) / 1000
	task.wait(L_86_)
end

local L_21_, L_22_ = nil, 0
local L_23_ = 0
local L_24_ = 1
local L_25_ = 0.5
local L_26_ = 0.5
local L_27_ = 12.0

local function L_28_func(L_87_arg0)
	print("[TP] Attempting:", L_87_arg0, L_7_func())
	local L_88_, L_89_ = pcall(function()
		return L_2_:TeleportToPlaceInstance(game.PlaceId, L_87_arg0)
	end)
	if L_88_ then
		print("[TP] Teleport started", L_7_func())
		return true
	end
	warn("[TP-FAIL]", L_89_, L_7_func())
	return false
end

L_2_.TeleportInitFailed:Connect(function()
	print("[TP-FAIL-EVENT]", L_7_func())
	L_22_ = os.clock()
	if L_21_ then
		L_18_func(L_21_)
	end
	task.wait(0.6)
	local L_90_ = L_17_func()
	if L_90_ then
		L_28_func(L_90_)
	end
end)

shared.__QUESAID_LAST_MARKED__ = shared.__QUESAID_LAST_MARKED__ or nil
local function L_29_func()
	local L_91_ = tostring(game.JobId)
	if shared.__QUESAID_LAST_MARKED__ == L_91_ then
		return
	end
	shared.__QUESAID_LAST_MARKED__ = L_91_
	task.delay(2, function()
		print("[JOIN-MARK]", L_91_, L_7_func())
		L_8_func({
			Url = L_16_ .. "/joined",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = L_1_:JSONEncode({
				placeId = game.PlaceId,
				serverId = L_91_
			})
		})
	end)
end
coroutine.wrap(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	L_29_func()
end)()

L_3_.LocalPlayer.CharacterAdded:Connect(L_29_func)

coroutine.wrap(function()
	local L_92_ = nil
	while true do
		local L_93_ = tostring(game.JobId)
		if L_93_ ~= L_92_ then
			L_92_ = L_93_;
			L_29_func()
		end
		task.wait(5)
	end
end)()

coroutine.wrap(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	task.wait(1)
	print("[MAIN-SCAN]", L_7_func())
	local L_94_ = L_10_func()
	if L_94_ and L_94_[1] then
		print("[MAIN-BEST]", L_94_[1].Name, L_94_[1].RealAmount, L_94_[1].Amount, L_7_func())
		L_15_func(L_94_[1])
	else
		print("[MAIN-NONE]", L_7_func())
	end
	coroutine.wrap(function()
		coroutine.wrap(function()
			while task.wait(2.5 + math.random() * 0.5) do
				local L_95_
				L_95_ = L_17_func()
				if not L_95_ or # L_95_ <= 10 or L_95_ == game.JobId then
					task.wait(1.0 + math.random() * 0.4)
				end
				local L_96_ = 0.25 + math.random() * 0.75
				task.wait(L_96_)
				local L_97_ = L_28_func(L_95_)
				if L_97_ then
					break
				else
					task.wait(2.0 + math.random() * 0.5)
				end
			end
		end)()
	end)()
end)()
