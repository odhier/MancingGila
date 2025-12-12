local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local function getTeamNeutral()
    local ok, playerList = pcall(function() return CoreGui:WaitForChild("PlayerList", 10) end)
    if not ok or not playerList then return nil end

    local offsetFrame = playerList:WaitForChild("Children"):FindFirstChild("OffsetFrame")
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

local clonedFor = {}
local connections = {}

local function findPlayerEntry(teamNeutral, userId)
    if not teamNeutral then return nil end
    return teamNeutral:FindFirstChild("PlayerEntry_" .. tostring(userId))
end

local function formatNumber(n)
    local formatted = tostring(n)
    while true do
        local updated, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        formatted = updated
        if k == 0 then break end
    end
    return formatted
end

local function makeCloneAndBind(player, teamNeutral)
    if not player or not teamNeutral then return end
    local userId = player.UserId
    if clonedFor[userId] then return end

    local entry = findPlayerEntry(teamNeutral, userId)
    if not entry then
        return
    end

    local content = entry:FindFirstChild("PlayerEntryContentFrame")
    if not content then return end
    local overlay = content:FindFirstChild("OverlayFrame")
    if not overlay then return end
    local originalStat = overlay:FindFirstChild("GameStat_Caught")
    if not originalStat then return end
    local originalDisplay = originalStat:FindFirstChild("PlayerStatDisplay")
    if not originalDisplay then return end

    if overlay:FindFirstChild("GameStat_Caught_Custom") then
        clonedFor[userId] = true
    else
        local cloned = originalStat:Clone()
        cloned.Name = "GameStat_Caught_Custom"

        local child = cloned:FindFirstChild("PlayerStatDisplay")
        if child then
            child.Name = "PlayerStatDisplay_Custom"
            child.Text = tostring(player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Caught") and player.leaderstats.Caught.Value or 0)
        end

        cloned.Parent = overlay
        cloned.Visible = true

        originalStat.Visible = false

        clonedFor[userId] = true
    end

    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = player:WaitForChild("leaderstats", 5)
    end
    if not leaderstats then return end
    local caught = leaderstats:FindFirstChild("Caught") or leaderstats:WaitForChild("Caught", 5)
    if not caught then return end

    if connections[userId] and connections[userId].caughtConn then
        connections[userId].caughtConn:Disconnect()
    end

    local caughtConn = caught:GetPropertyChangedSignal("Value"):Connect(function()
        local entryNow = findPlayerEntry(teamNeutral, userId)
        if not entryNow then return end
        local contentNow = entryNow:FindFirstChild("PlayerEntryContentFrame")
        if not contentNow then return end
        local overlayNow = contentNow:FindFirstChild("OverlayFrame")
        if not overlayNow then return end
        local clonedStat = overlayNow:FindFirstChild("GameStat_Caught_Custom")
        if not clonedStat then return end
        local display = clonedStat:FindFirstChild("PlayerStatDisplay_Custom")
        if display then
            display.Text = formatNumber(caught.Value)
        end
    end)

    local entryRemovedConn
    entryRemovedConn = entry.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if connections[userId] and connections[userId].caughtConn then
                connections[userId].caughtConn:Disconnect()
            end
            if connections[userId] and connections[userId].entryRemovedConn then
                connections[userId].entryRemovedConn:Disconnect()
            end
            connections[userId] = nil
            clonedFor[userId] = nil
            entryRemovedConn = nil
        end
    end)

    connections[userId] = {caughtConn = caughtConn, entryRemovedConn = entryRemovedConn}
end

local function watchTeamList()
    local teamNeutral = getTeamNeutral()
    if not teamNeutral then
        local tries = 0
        repeat
            tries = tries + 1
            task.wait(0.5)
            teamNeutral = getTeamNeutral()
        until teamNeutral or tries > 20
    end
    if not teamNeutral then
        warn("Tidak menemukan TeamList_Neutral. Pastikan PlayerList custom path benar.")
        return
    end

    for _, p in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            makeCloneAndBind(p, teamNeutral)
        end)
    end

    teamNeutral.ChildAdded:Connect(function(child)
        for _, p in ipairs(Players:GetPlayers()) do
            if child.Name == ("PlayerEntry_" .. tostring(p.UserId)) then
                task.spawn(function()
                    makeCloneAndBind(p, teamNeutral)
                end)
                break
            end
        end
    end)

    Players.PlayerAdded:Connect(function(pl)
        task.spawn(function()
            task.wait(0.2)
            makeCloneAndBind(pl, teamNeutral)
        end)
    end)
end

task.spawn(watchTeamList)
