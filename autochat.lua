local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local TARGET_EVENT_NAME = "RE/ReplicateTextEffect"
local chatMessages = {
    "/givesecret "
}
local function sendRandomChat(nick)
    local rd = math.random(1, #chatMessages)
    local msg = chatMessages[rd]
    
    msg= msg..nick 
	TextChatService.TextChannels.RBXGeneral:SendAsync(msg)
end
local TARGET_CFRAME = CFrame.new(
	1489.33118, -21.9847832, -637.773376,
	0.484614819, 8.05178058e-09, -0.874727666,
	-5.36718083e-08, 1, -2.05302442e-08,
	0.874727666, 5.68974734e-08, 0.484614819
)
local TIER_BY_STRING = {
	["0 0.764706 1.000000 0.333333 1 0.764706 1.000000 0.333333"] = "Uncommon",
	["0 0.333333 0.635294 1.000000 1 0.333333 0.635294 1.000000"] = "Rare",
	["0 0.678431 0.309804 1.000000 1 0.678431 0.309804 1.000000"] = "Unique",
	["0 1.000000 0.721569 0.164706 1 1.000000 0.721569 0.164706"] = "Legend",
	["0 1.000000 0.094118 0.094118 1 1.000000 0.094118 0.094118"] = "Mitos",
	["0 0.090196 1.000000 0.592157 1 0.043137 0.584314 1.000000"] = "Secret",
}

local function getCharacterNickFromAttach(arg1)
	if type(arg1) ~= "table" then return nil end
	local td = arg1.TextData
	if not td or typeof(td.AttachTo) ~= "Instance" then return nil end
	local attach = td.AttachTo
	local model = attach:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		local plr = Players:GetPlayerFromCharacter(model)
		if plr then
			return (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
		end
	end
	return model.Name
end

local function flattenColorSequenceToString(cs)
	if typeof(cs) ~= "ColorSequence" then return nil end
	local parts = {}
	for _, kp in ipairs(cs.Keypoints) do
		table.insert(parts, tostring(kp.Time))
		table.insert(parts, string.format("%.6f", kp.Value.R))
		table.insert(parts, string.format("%.6f", kp.Value.G))
		table.insert(parts, string.format("%.6f", kp.Value.B))
	end
	return table.concat(parts, " ")
end

local function getTierFromTextColor(textColor)
	local flat = flattenColorSequenceToString(textColor)
	if not flat then return nil, nil end
	local tier = TIER_BY_STRING[flat]
	if tier then return tier, flat end
	local normalized = flat:gsub("(%s)1%.000000(%s)", "%11%2")
		:gsub("^1%.000000(%s)", "1%1")
		:gsub("(%s)1%.000000$", "%11")
	tier = TIER_BY_STRING[normalized]
	return tier, flat
end


local function tryLog(evName, ...)
	if evName ~= TARGET_EVENT_NAME then return end

	local a1 = select(1, ...)
	if type(a1) ~= "table" or not a1.TextData then return end

	local nick = getCharacterNickFromAttach(a1) or "Unknown"
	local textColor = a1.TextData.TextColor
	if not textColor then return end

	local tier, flat = getTierFromTextColor(textColor)

	if tier then
		print(("%s mendapatkan %s"):format(nick, tier))

		if tier == "Secret" then
			local lp = Players.LocalPlayer
			local myNick = (lp.DisplayName ~= "" and lp.DisplayName) or lp.Name
            sendRandomChat(nick)
		end
	else
		flat = flat or tostring(textColor)
		print(("%s mendapatkan %s"):format(nick, flat))
	end
end
local function hookEvent(event)
	event.OnClientEvent:Connect(function(...)
		tryLog(event.Name, ...)
	end)
end

local function hookFunction(func)
	func.OnClientInvoke = function(...)
		return nil
	end
end

for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
	if obj:IsA("RemoteEvent") then
		hookEvent(obj)
	elseif obj:IsA("RemoteFunction") then
		hookFunction(obj)
	end
end

ReplicatedStorage.DescendantAdded:Connect(function(obj)
	if obj:IsA("RemoteEvent") then
		hookEvent(obj)
	elseif obj:IsA("RemoteFunction") then
		hookFunction(obj)
	end
end)
