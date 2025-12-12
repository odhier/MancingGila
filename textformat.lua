local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local replaced = false
local clonedFor = {}     -- [userId] = clonedInstance
local connections = {}   -- [userId] = connection

local function formatNumber(n)
    local formatted = tostring(n)
    while true do
        local updated, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        formatted = updated
        if k == 0 then break end
    end
    return formatted
end

local function getTeamNeutralIfChildrenPresent()
    local playerList = CoreGui:FindFirstChild("PlayerList")
    if not playerList then return nil end
    local children = playerList:FindFirstChild("Children")
    if not children then return nil end
    local offsetFrame = children:FindFirstChild("OffsetFrame")
    if not offsetFrame then return nil end
    local playerScrollList = offsetFrame:FindFirstChild("PlayerScrollList")
    if not playerScrollList then return nil end
    local sizeOffsetFrame = playerScrollList:FindFirstChild("SizeOffsetFrame")
    if not sizeOffsetFrame then return nil end
    local container = sizeOffsetFrame:FindFirstChild("ScrollingFrameContainer")
    if not container then return nil end
    local clipping = container:FindFirstChild("ScrollingFrameClippingFrame")
    if not clipping then return nil end
    local scrollingFrame = clipping:FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return nil end
    local offsetUndo = scrollingFrame:FindFirstChild("OffsetUndoFrame")
    if not offsetUndo then return nil end
    local teamNeutral = offsetUndo:FindFirstChild("TeamList_Neutral")
    return teamNeutral
end

local function clearAllClonesAndConns()
    for userId, conn in pairs(connections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
        connections[userId] = nil
        clonedFor[userId] = nil
    end
end

local function ensureCloneForEntry(player, overlay)
    if not player or not overlay then return end
    local userId = player.UserId
    if overlay:FindFirstChild("GameStat_Caught_Custom") then
        clonedFor[userId] = overlay.GameStat_Caught_Custom
        return clonedFor[userId]
    end
    local originalStat = overlay:FindFirstChild("GameStat_Caught")
    if not originalStat then return nil end
    local originalDisplay = originalStat:FindFirstChild("PlayerStatDisplay")
    if not originalDisplay then return nil end

    local cloned = originalStat:Clone()
    cloned.Name = "GameStat_Caught_Custom"
    local child = cloned:FindFirstChild("PlayerStatDisplay")
    if child then
        child.Name = "PlayerStatDisplay_Custom"
        local startVal = 0
        if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Caught") then
            startVal = player.leaderstats.Caught.Value
        end
        child.Text = formatNumber(startVal)
    end
    cloned.Parent = overlay
    cloned.Visible = true
    originalStat.Visible = false
    clonedFor[userId] = cloned
    return cloned
end

local function bindCaughtToClone(player, clone)
    if not player or not clone then return end
    local userId = player.UserId
    if connections[userId] then
        pcall(function() connections[userId]:Disconnect() end)
        connections[userId] = nil
    end
    local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 1)
    if not leaderstats then return end
    local caught = leaderstats:FindFirstChild("Caught") or leaderstats:WaitForChild("Caught", 1)
    if not caught then return end

    local conn = caught:GetPropertyChangedSignal("Value"):Connect(function()
        if not clone.Parent then return end
        local disp = clone:FindFirstChild("PlayerStatDisplay_Custom") or clone:FindFirstChild("PlayerStatDisplay")
        if disp then
            disp.Text = formatNumber(caught.Value)
        end
    end)
    connections[userId] = conn
end

local function processAllEntries(teamNeutral)
    if not teamNeutral then return end
    for _, p in ipairs(Players:GetPlayers()) do
        local entry = teamNeutral:FindFirstChild("PlayerEntry_" .. tostring(p.UserId))
        if entry then
            local content = entry:FindFirstChild("PlayerEntryContentFrame")
            if content then
                local overlay = content:FindFirstChild("OverlayFrame")
                if overlay then
                    local clone = ensureCloneForEntry(p, overlay)
                    if clone then
                        bindCaughtToClone(p, clone)
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        local teamNeutral = getTeamNeutralIfChildrenPresent()
        if not teamNeutral then
            if replaced then
                replaced = false
                clearAllClonesAndConns()
            end
        else
            if not replaced then
                processAllEntries(teamNeutral)
                replaced = true
            end
        end
    end
end)
