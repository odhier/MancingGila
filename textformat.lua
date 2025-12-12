local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local replaced = false
local clonedFor = {}    -- [userId] = clonedInstance
local connections = {}  -- [userId] = connection

local function formatNumber(n)
    local formatted = tostring(n)
    while true do
        local updated, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
        formatted = updated
        if k == 0 then break end
    end
    return formatted
end

-- cari root PlayerList yang tersedia (pakai Children kalau ada)
local function getPlayerListRoot()
    local pl = CoreGui:FindFirstChild("PlayerList")
    if not pl then return nil end
    local children = pl:FindFirstChild("Children")
    if children then
        return children
    end
    return pl
end

-- cari instance GameStat_Caught yang 'berasosiasi' dengan userId
-- strategi: iterasi semua descendant yang punya nama "GameStat_Caught" (atau punya PlayerStatDisplay),
-- lalu naik beberapa level ke atas untuk cek apakah ada ancestor yang mengandung userId di namanya
local function findGameStatForUser(root, userId)
    if not root then return nil end
    local uidStr = tostring(userId)
    for _, inst in ipairs(root:GetDescendants()) do
        local hasStat = inst.Name == "GameStat_Caught"
        if not hasStat then
            local maybe = inst:FindFirstChild("GameStat_Caught")
            if maybe then
                inst = maybe
                hasStat = true
            end
        end
        if hasStat then
            local display = inst:FindFirstChild("PlayerStatDisplay")
            if display then
                -- naik sampai 8 tingkat mencari nama yang mengandung uid
                local ancestor = inst
                for i = 1, 8 do
                    ancestor = ancestor.Parent
                    if not ancestor then break end
                    if string.find(ancestor.Name, uidStr, 1, true) then
                        return inst, ancestor -- kembalikan GameStat_Caught dan ancestor yang match
                    end
                end
                -- fallback: kadang struktur tidak menyertakan uid di nama ancestor.
                -- coba cek bila ancestor mengandung "PlayerEntry" atau "Player_" dll + memiliki PlayerEntryContentFrame
                ancestor = inst.Parent
                for i = 1, 8 do
                    if not ancestor then break end
                    if ancestor:FindFirstChild("PlayerEntryContentFrame") or string.find(ancestor.Name, "PlayerEntry", 1, true) or string.find(ancestor.Name, "Player_", 1, true) or string.find(ancestor.Name, "p_", 1, true) then
                        -- coba cari di antara anak-anaknya nama yang mengandung uid
                        for _, sub in ipairs(ancestor:GetDescendants()) do
                            if string.find(sub.Name, uidStr, 1, true) then
                                return inst, sub
                            end
                        end
                    end
                    ancestor = ancestor.Parent
                end
            end
        end
    end
    return nil
end

local function clearAllClonesAndConns()
    for userId, conn in pairs(connections) do
        pcall(function() conn:Disconnect() end)
        connections[userId] = nil
    end
    for userId, inst in pairs(clonedFor) do
        pcall(function()
            if inst and inst.Parent then
                inst:Destroy()
            end
        end)
        clonedFor[userId] = nil
    end
end

local function ensureCloneForStat(player, statFrame, entryAncestor)
    if not player or not statFrame then return nil end
    local userId = player.UserId
    if clonedFor[userId] and clonedFor[userId].Parent then
        return clonedFor[userId]
    end
    -- jika sudah ada custom di overlay, gunakan itu
    if statFrame.Parent and statFrame.Parent:FindFirstChild("GameStat_Caught_Custom") then
        clonedFor[userId] = statFrame.Parent:FindFirstChild("GameStat_Caught_Custom")
        return clonedFor[userId]
    end
    -- clone statFrame
    local originalStat = statFrame
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
    -- parent ke tempat yang benar: utamakan entryAncestor (kalau relevan), kalau tidak parent ke original parent
    local parentTarget = entryAncestor
    if parentTarget and parentTarget:FindFirstChild("PlayerEntryContentFrame") then
        parentTarget = parentTarget:FindFirstChild("PlayerEntryContentFrame"):FindFirstChild("OverlayFrame") or parentTarget
    else
        parentTarget = originalStat.Parent or parentTarget
    end
    cloned.Parent = parentTarget
    cloned.Visible = true
    -- sembunyikan original
    pcall(function() originalStat.Visible = false end)
    clonedFor[userId] = cloned
    return cloned
end

local function bindCaught(player, cloned)
    if not player or not cloned then return end
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
        if not cloned.Parent then return end
        local disp = cloned:FindFirstChild("PlayerStatDisplay_Custom") or cloned:FindFirstChild("PlayerStatDisplay")
        if disp then
            disp.Text = formatNumber(caught.Value)
        end
    end)
    connections[userId] = conn
end

local function processAllPlayers(root)
    for _, p in ipairs(Players:GetPlayers()) do
        local statFrame, ancestor = findGameStatForUser(root, p.UserId)
        if statFrame then
            local cloned = ensureCloneForStat(p, statFrame, ancestor)
            if cloned then
                bindCaught(p, cloned)
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        local root = getPlayerListRoot()
        if not root then
            if replaced then
                replaced = false
                clearAllClonesAndConns()
            end
        else
            if not replaced then
                processAllPlayers(root)
                replaced = true
            end
        end
    end
end)
