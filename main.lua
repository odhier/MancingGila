local base = "QXV0byBUZWxlIOKAkyBTZWNyZXQgU2Nhbm5lciB8IE9kaGllcg=="
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TextChatService    = game:GetService("TextChatService")
local HttpService        = game:GetService("HttpService")
local LP = Players.LocalPlayer
local TARGET_EVENT_NAME = "RE/ReplicateTextEffect"
local _b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function b64decode(data)
	data = data:gsub('[^'.._b64chars..'=]', '')
	local bits = data:gsub('.', function(x)
		if x == '=' then return '' end
		local v = _b64chars:find(x) - 1
		local b = ''
		for i = 6, 1, -1 do
			b = b .. ((v % 2^i - v % 2^(i-1) > 0) and '1' or '0')
		end
		return b
	end)

	return (bits:gsub('%d%d%d?%d?%d?%d?%d?%d?', function(chunk)
		if #chunk < 8 then return '' end
		local c = 0
		for i = 1, 8 do
			if chunk:sub(i, i) == '1' then
				c = c + 2^(8 - i)
			end
		end
		return string.char(c)
	end))
end
local decodedName = b64decode(base)
local TARGETS = {
	["Sacred Temple"] = CFrame.new(
		1489.33118, -21.9847832, -637.773376,
        0.484614819, 8.05178058e-09, -0.874727666,
        -5.36718083e-08, 1, -2.05302442e-08,
        0.874727666, 5.68974734e-08, 0.484614819
	),
    ["Sisyphus Statue"] = CFrame.new(
        -3777.43433, -135.074417, -975.198975, -0.284491211, 1.09240688e-08, -0.958678663, 5.78678048e-08, 1, -5.77754911e-09, 0.958678663, -5.71202925e-08, -0.284491211
    ),

}
local function firstKey(t)
	for k,_ in pairs(t) do return k end
	return nil
end
local SelectedTargetName = firstKey(TARGETS) 
local AutoTeleportEnabled = false
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
local function safeTeleport(cframeTarget)
	if not cframeTarget then return end
	local char = LP.Character or LP.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = cframeTarget
	end
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
			local myNick = (LP.DisplayName ~= "" and LP.DisplayName) or LP.Name
			if nick == myNick then
				if AutoTeleportEnabled then
					local targetCF = TARGETS[SelectedTargetName]
					safeTeleport(targetCF)
				end
			end
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
local OrionLib
do
	local ok, lib = pcall(function()
		return loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()
	end)
	if ok then
		OrionLib = lib
	else
		warn("Gagal memuat Orion:", lib)
		return
	end
end

local window = OrionLib:MakeWindow({
	Name = decodedName,
	HidePremium = false,
	SaveConfig = true,
	ConfigFolder = "AutoTeleSecretCfg",
	IntroEnabled = false
})

local mainTab = window:MakeTab({
	Name = "Main",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})
local targetNames = {}
for name,_ in pairs(TARGETS) do
	table.insert(targetNames, name)
end
table.sort(targetNames)

mainTab:AddDropdown({
	Name = "Choose Target",
	Default = SelectedTargetName or targetNames[1],
	Options = targetNames,
	Callback = function(val)
		if TARGETS[val] then
			SelectedTargetName = val
			OrionLib:MakeNotification({
				Name = "Target Selected",
				Content = "Tujuan: " .. tostring(val),
				Time = 2
			})
		else
			OrionLib:MakeNotification({
				Name = "Invalid Target",
				Content = "Pilihan tidak ada di daftar.",
				Time = 2
			})
		end
	end
})
mainTab:AddToggle({
	Name = "Enable Auto Tele",
	Default = false,
	Callback = function(state)
		AutoTeleportEnabled = state
		OrionLib:MakeNotification({
			Name = "Auto Teleport",
			Content = state and "Enabled" or "Disabled",
			Time = 2
		})
	end
})

OrionLib:Init()
