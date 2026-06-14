local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
local Camera = workspace.CurrentCamera

local Theme = {
    Bg = Color3.fromRGB(30, 8, 18),
    Panel = Color3.fromRGB(58, 18, 36),
    PanelSoft = Color3.fromRGB(78, 24, 46),
    Accent = Color3.fromRGB(255, 110, 180),
    AccentSoft = Color3.fromRGB(255, 176, 220),
    Text = Color3.fromRGB(255, 245, 250),
    SubText = Color3.fromRGB(242, 206, 226),
    ToggleOn = Color3.fromRGB(255, 130, 190),
    ToggleOff = Color3.fromRGB(82, 34, 56),
    HighlightFill = Color3.fromRGB(255, 180, 230),
    HighlightOutline = Color3.fromRGB(255, 110, 190),
}

local PlayerTextColors = {
    Color3.fromRGB(255, 95, 135),
    Color3.fromRGB(190, 130, 255),
    Color3.fromRGB(255, 180, 95),
    Color3.fromRGB(255, 125, 200),
    Color3.fromRGB(140, 230, 255),
    Color3.fromRGB(235, 105, 255),
    Color3.fromRGB(255, 110, 160),
    Color3.fromRGB(180, 255, 150),
}

local function getPlayerTextColor(player)
    return PlayerTextColors[(player.UserId % #PlayerTextColors) + 1]
end

local BodyParts = {
    "Head",
    "Torso",
    "Left Arm",
    "Right Arm",
    "Left Leg",
    "Right Leg",
    "HumanoidRootPart",
}

local selectedBodyPartIndex = 1
local selectedBodyPart = BodyParts[selectedBodyPartIndex]
local autoAimEnabled = false
local aimHolding = false
local highlightEnabled = false
local dealerEspEnabled = false
local safeAutofarmEnabled = false
local tweenSpeed = 1.0
local tweenSpeedMin = 0.4
local tweenSpeedMax = 2.5
local safeAutofarmLoop = nil
local backpackEnabled = false
local fullbrightEnabled = false
local targetPlayer = nil
local lastKiller = nil
local originalLighting = {}
local highlightCache = {}
local dealerHighlightCache = {}
local gangHighlightCache = {}
local crowbarWarningShown = false
local killerHighlightCache = {}
local gangEnabled = false
local gangClusterStartTimes = {}
local gangDetectedPlayers = {}
local GANG_CLUSTER_RADIUS = 18
local GANG_CLUSTER_DURATION = 60
local gangPalette = {
    Color3.fromRGB(255, 110, 180),
    Color3.fromRGB(140, 255, 190),
    Color3.fromRGB(255, 210, 120),
    Color3.fromRGB(140, 200, 255),
    Color3.fromRGB(255, 150, 210),
}
local backpackBillboards = {}

local function create(className, properties)
    local instance = Instance.new(className)
    for property, value in pairs(properties) do
        if property == "Parent" then
            instance.Parent = value
        else
            instance[property] = value
        end
    end
    return instance
end

local function getMousePosition()
    local mouseLocation = UserInputService:GetMouseLocation()
    local inset = select(1, GuiService:GetGuiInset())
    return Vector2.new(mouseLocation.X, mouseLocation.Y) - inset
end

local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart = Vector2.zero
    local startPos = frame.Position

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = getMousePosition()
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local currentPos = getMousePosition()
            local delta = currentPos - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function updateTargetLabel(label)
    if label and label.Parent then
        if targetPlayer and targetPlayer.Character and targetPlayer.Character.Parent then
            label.Text = "Target: " .. targetPlayer.Name
        else
            targetPlayer = nil
            label.Text = "Target: None"
        end
    end
end

local function updateBodyPartLabel(label)
    if label and label.Parent then
        label.Text = "Body Part: " .. selectedBodyPart
    end
end

local function getNearestPlayerToLocal()
    if not LocalPlayer or not LocalPlayer.Character then
        return nil
    end

    local rootPart = getCharacterRoot(LocalPlayer.Character)
    if not rootPart then
        return nil
    end

    local nearest = nil
    local nearestDistance = math.huge

    local players = Players:GetPlayers()
    if not players then
        return nil
    end

    for _, player in ipairs(players) do
        if player and player ~= LocalPlayer and player.Character then
            local playerRoot = getCharacterRoot(player.Character)
            if playerRoot and playerRoot.Position then
                local distance = (playerRoot.Position - rootPart.Position).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearest = player
                end
            end
        end
    end

    return nearest
end

local function setFullbright(enabled)
    fullbrightEnabled = enabled

    if enabled then
        originalLighting = {
            Brightness = Lighting.Brightness,
            Ambient = Lighting.Ambient,
            ColorShift_Bottom = Lighting.ColorShift_Bottom,
            ColorShift_Top = Lighting.ColorShift_Top,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            ExposureCompensation = Lighting.ExposureCompensation,
            FogColor = Lighting.FogColor,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
        }

        Lighting.Brightness = 2.2
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
        Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.ExposureCompensation = 0.35
        Lighting.FogColor = Color3.fromRGB(255, 255, 255)
        Lighting.FogEnd = 10000
        Lighting.FogStart = 0
    else
        Lighting.Brightness = originalLighting.Brightness or Lighting.Brightness
        Lighting.Ambient = originalLighting.Ambient or Lighting.Ambient
        Lighting.ColorShift_Bottom = originalLighting.ColorShift_Bottom or Lighting.ColorShift_Bottom
        Lighting.ColorShift_Top = originalLighting.ColorShift_Top or Lighting.ColorShift_Top
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient or Lighting.OutdoorAmbient
        Lighting.ExposureCompensation = originalLighting.ExposureCompensation or Lighting.ExposureCompensation
        Lighting.FogColor = originalLighting.FogColor or Lighting.FogColor
        Lighting.FogEnd = originalLighting.FogEnd or Lighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart or Lighting.FogStart
    end
end

local function getTargetPart()
    if not targetPlayer or not targetPlayer.Character then
        return nil
    end
    return targetPlayer.Character:FindFirstChild(selectedBodyPart)
end

local function getCharacterRoot(character)
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character.PrimaryPart)
end

local function getSafeFolder()
    local map = workspace:FindFirstChild("Map")
    if not map then
        return nil
    end
    return map:FindFirstChild("BredMakurz")
end

local function getSafeCenter(safe)
    local primary = safe and safe:FindFirstChild("PrimaryPart") or safe and safe.PrimaryPart
    if not primary then
        return nil
    end

    local size = primary.Size
    return primary.Position + Vector3.new(0, size.Y / 2 + 2, 0)
end

local function isSafeOccupied(safe)
    local primary = safe and (safe:FindFirstChild("PrimaryPart") or safe.PrimaryPart)
    if not primary then
        return false
    end

    local safePos = primary.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = getCharacterRoot(player.Character)
            if root and (root.Position - safePos).Magnitude <= 5 then
                return true
            end
        end
    end
    return false
end

local function moveToPosition(position, speed)
    local character = LocalPlayer.Character
    if not character then
        return
    end

    local root = getCharacterRoot(character)
    if not root then
        warn("No root part found")
        return
    end

    local target = Vector3.new(position.X, position.Y, position.Z)

    local distance = (target - root.Position).Magnitude
    local studsPerSecond = math.max(1, speed or (tweenSpeed * 20))
    local duration = distance / studsPerSecond

    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {
            CFrame = CFrame.new(target)
        }
    )

    tween:Play()
    tween.Completed:Wait()
end

local function pressKey(keyCode, count)
    local function sendPress()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end

    for _ = 1, math.max(1, count or 1) do
        sendPress()
        task.wait(0.08)
    end
end

local function getCrowbar()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end

    local tool = character:FindFirstChildWhichIsA("Tool")
    if tool and tool.Name:lower():find("crowbar") then
        return tool
    end

    local backpack = LocalPlayer.Backpack
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find("crowbar") then
                return item
            end
        end
    end

    return nil
end

local function equipCrowbar()
    local crowbar = getCrowbar()
    if not crowbar then
        return false
    end

    if crowbar.Parent ~= LocalPlayer.Character then
        if crowbar.Parent == LocalPlayer.Backpack then
            local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(crowbar)
            end
        end
    end
    return true
end

local function breakSafe(safe)
    if not safe or not safe.Parent then
        return
    end

    local root = getCharacterRoot(LocalPlayer.Character)
    if not root then
        return
    end

    local safePrimary = safe:FindFirstChild("PrimaryPart") or safe.PrimaryPart
    if not safePrimary then
        return
    end

    local originalLevel = Vector3.new(root.Position.X, root.Position.Y - 8, root.Position.Z)
    local safeCenter = getSafeCenter(safe) or safePrimary.Position

    local moveSpeed = tweenSpeed * 20
    local xAlignedPoint = Vector3.new(safeCenter.X, originalLevel.Y, root.Position.Z)
    local zAlignedPoint = Vector3.new(safeCenter.X, originalLevel.Y, safeCenter.Z)

    moveToPosition(originalLevel, moveSpeed)
    moveToPosition(xAlignedPoint, moveSpeed)
    moveToPosition(zAlignedPoint, moveSpeed)
    moveToPosition(safeCenter, moveSpeed)

    if equipCrowbar() then
        pressKey(Enum.KeyCode.F, 2)
        task.wait(20)
    end

    moveToPosition(originalLevel, moveSpeed)
end

local function startSafeAutofarm()
    if safeAutofarmLoop then
        return
    end

    safeAutofarmLoop = task.spawn(function()
        while safeAutofarmEnabled do
            local safeFolder = getSafeFolder()
            if safeFolder then
                local safes = {}
                for _, obj in ipairs(safeFolder:GetDescendants()) do
                    if obj:IsA("Model") and obj.Name:lower():find("safe") then
                        table.insert(safes, obj)
                    end
                end

                for _, safe in ipairs(safes) do
                    if not safeAutofarmEnabled then
                        break
                    end
                    if isSafeOccupied(safe) then
                        continue
                    end
                    if not getCrowbar() then
                        if not crowbarWarningShown then
                            crowbarWarningShown = true
                            showCrowbarWarning()
                        end
                        task.wait(0.25)
                        continue
                    end

                    crowbarWarningShown = false
                    breakSafe(safe)
                end
            end
            task.wait(0.5)
        end
        safeAutofarmLoop = nil
    end)
end

local function stopSafeAutofarm()
    safeAutofarmEnabled = false
    if safeAutofarmLoop then
        task.cancel(safeAutofarmLoop)
        safeAutofarmLoop = nil
    end
end

local function getLookAtPlayer()
    if not Camera then return nil end

    local cameraPos = Camera.CFrame.Position
    local cameraLook = Camera.CFrame.LookVector

    local bestPlayer = nil
    local bestDot = 0.92 -- tighter = more accurate (0.8–0.95 recommended)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = getCharacterRoot(player.Character)

            if root then
                local direction = (root.Position - cameraPos).Unit
                local dot = cameraLook:Dot(direction)

                if dot > bestDot then
                    -- extra check: ignore players behind walls
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
                    rayParams.FilterType = Enum.RaycastFilterType.Blacklist

                    local result = workspace:Raycast(cameraPos, direction * 500, rayParams)

                    if result and result.Instance and result.Instance:IsDescendantOf(player.Character) then
                        bestPlayer = player
                        bestDot = dot
                    end
                end
            end
        end
    end

    return bestPlayer
end

local function selectTarget(label)
    local player = getLookAtPlayer()
    if player then
        targetPlayer = player
        updateTargetLabel(label)
        return
    end

    local nearest
    local nearestDistance = math.huge
    local rootPart = getCharacterRoot(LocalPlayer.Character)
    if rootPart then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local playerRoot = getCharacterRoot(player.Character)
                if playerRoot then
                    local distance = (playerRoot.Position - rootPart.Position).Magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearest = player
                    end
                end
            end
        end
    end

    targetPlayer = nearest
    updateTargetLabel(label)
end

local function updateLastKillerHighlight()
    if killerHighlightCache[lastKiller] then
        killerHighlightCache[lastKiller]:Destroy()
        killerHighlightCache[lastKiller] = nil
    end

    if not lastKiller or not lastKiller.Character or not lastKiller.Character.Parent then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "PinkAimLastKiller"
    highlight.Adornee = lastKiller.Character
    highlight.FillColor = Color3.fromRGB(255, 70, 70)
    highlight.OutlineColor = Color3.fromRGB(255, 190, 190)
    highlight.FillTransparency = 0.35
    highlight.OutlineTransparency = 0.05
    highlight.Parent = lastKiller.Character
    killerHighlightCache[lastKiller] = highlight
end

local function clearLastKillerHighlight()
    if killerHighlightCache[lastKiller] then
        killerHighlightCache[lastKiller]:Destroy()
        killerHighlightCache[lastKiller] = nil
    end
end

local function applyHighlightToPlayer(player)
    if player == LocalPlayer then return end

    local character = player.Character
    if not character then return end

    local highlight = highlightCache[player]

    -- always recreate if missing OR parent is wrong
    if not highlight or not highlight.Parent or highlight.Adornee ~= character then
        if highlight then
            highlight:Destroy()
        end

        highlight = Instance.new("Highlight")
        highlight.Name = "PinkAimHighlight"
        highlight.FillColor = Theme.HighlightFill
        highlight.OutlineColor = Theme.HighlightOutline
        highlight.FillTransparency = 0.75
        highlight.OutlineTransparency = 0.2
        highlight.Adornee = character
        highlight.Parent = character

        highlightCache[player] = highlight
        return
    end

    -- update binding if character changed
    if highlight.Adornee ~= character then
        highlight.Adornee = character
        highlight.Parent = character
    end
end

local function setHighlightsEnabled(enabled)
    highlightEnabled = enabled
    for _, player in ipairs(Players:GetPlayers()) do
        if enabled then
            applyHighlightToPlayer(player)
        else
            local highlight = highlightCache[player]
            if highlight then
                highlight:Destroy()
                highlightCache[player] = nil
            end
        end
    end
end

local function getDealerFolder()
    local map = workspace:FindFirstChild("Map")
    if not map then
        return nil
    end

    local shopz = map:FindFirstChild("Shopz")
    if not shopz then
        return nil
    end

    return shopz
end

local function getPlayerRoot(player)
    if not player or not player.Character then
        return nil
    end
    return getCharacterRoot(player.Character)
end

local function getGangGroups()
    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character.Parent then
            local root = getPlayerRoot(player)
            if root then
                table.insert(players, {Player = player, Root = root})
            end
        end
    end

    if #players < 3 then
        return {}
    end

    local visited = {}
    local groups = {}

    for i = 1, #players do
        if not visited[i] then
            local stack = {players[i]}
            visited[i] = true
            local cluster = {players[i]}

            while #stack > 0 do
                local current = table.remove(stack)
                for j = 1, #players do
                    if not visited[j] then
                        local distance = (current.Root.Position - players[j].Root.Position).Magnitude
                        if distance <= GANG_CLUSTER_RADIUS then
                            visited[j] = true
                            table.insert(stack, players[j])
                            table.insert(cluster, players[j])
                        end
                    end
                end
            end

            if #cluster >= 3 then
                table.insert(groups, cluster)
            end
        end
    end

    local readyGroups = {}
    local now = os.clock()

    for _, group in ipairs(groups) do
        local members = {}
        for _, entry in ipairs(group) do
            members[entry.Player] = true
        end

        local signature = {}
        for player in pairs(members) do
            table.insert(signature, tostring(player.UserId))
        end
        table.sort(signature)
        local groupKey = table.concat(signature, ",")

        local startTime = gangClusterStartTimes[groupKey]
        if not startTime then
            gangClusterStartTimes[groupKey] = now
        elseif now - startTime >= GANG_CLUSTER_DURATION then
            local result = {}
            for _, entry in ipairs(group) do
                table.insert(result, entry.Player)
            end
            table.insert(readyGroups, {Key = groupKey, Players = result})
        end
    end

    return readyGroups
end

local function updateGangHighlights()
    for _, highlight in ipairs(gangHighlightCache) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    gangHighlightCache = {}

    if not gangEnabled then
        return
    end

    local gangGroups = getGangGroups()
    if #gangGroups == 0 then
        return
    end

    for index, group in ipairs(gangGroups) do
        local color = gangPalette[(index - 1) % #gangPalette + 1]
        for _, player in ipairs(group.Players) do
            if player and player.Character and player.Character.Parent then
                local highlight = Instance.new("Highlight")
                highlight.Name = "GangESP"
                highlight.Adornee = player.Character
                highlight.FillColor = color
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = 0.35
                highlight.OutlineTransparency = 0.08
                highlight.Parent = player.Character
                table.insert(gangHighlightCache, highlight)
            end
        end
    end
end

local function setDealerEspEnabled(enabled)
    local shopz = getDealerFolder()
    if not shopz then
        return
    end

    for _, instance in ipairs(dealerHighlightCache) do
        if instance and instance.Parent then
            instance:Destroy()
        end
    end
    dealerHighlightCache = {}

    if not enabled then
        return
    end

    local function addDealerHighlight(model)
        if not model or not model:IsA("Model") then
            return
        end

        if model.Name:lower():find("dealer") then
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart
            if not root then
                return
            end

            local highlight = Instance.new("Highlight")
            highlight.Name = "DealerESP"
            highlight.Adornee = model
            highlight.FillColor = Color3.fromRGB(180, 120, 255)
            highlight.OutlineColor = Color3.fromRGB(235, 200, 255)
            highlight.FillTransparency = 0.45
            highlight.OutlineTransparency = 0.1
            highlight.Parent = model
            table.insert(dealerHighlightCache, highlight)
        end
    end

    for _, descendant in ipairs(shopz:GetDescendants()) do
        if descendant:IsA("Model") then
            addDealerHighlight(descendant)
        end
    end
end

local function makeBackpackBillboard(player)
    if backpackBillboards[player] then
        backpackBillboards[player].Gui:Destroy()
        backpackBillboards[player] = nil
    end

    if not player.Character then
        return nil
    end

    local head = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
    if not head then
        return nil
    end

    local billboard = create("BillboardGui", {
        Name = "PinkAimBackpackGui",
        Parent = head,
        Adornee = head,
        Size = UDim2.new(0, 220, 0, 84),
        StudsOffset = Vector3.new(0, 2.8, 0),
        AlwaysOnTop = true,
        MaxDistance = 160,
    })
    create("UICorner", {Parent = billboard, CornerRadius = UDim.new(0, 12)})

    local label = create("TextLabel", {
        Parent = billboard,
        Size = UDim2.new(1, 1, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = getPlayerTextColor(player),
        TextStrokeTransparency = 0.75,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "",
    })

    backpackBillboards[player] = {Gui = billboard, Label = label}
    return label
end

local function updateBackpackBillboards()
    if not backpackEnabled then
        for _, entry in pairs(backpackBillboards) do
            if entry.Gui then
                entry.Gui:Destroy()
            end
        end
        backpackBillboards = {}
        return
    end

    local rootPart = getCharacterRoot(LocalPlayer.Character)
    if not rootPart then
        return
    end

    local players = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local playerRoot = getCharacterRoot(player.Character)
            if playerRoot then
                table.insert(players, player)
            end
        end
    end

table.sort(players, function(a, b)
    local aChar = a.Character
    local bChar = b.Character

    local aRoot = aChar and getCharacterRoot(aChar)
    local bRoot = bChar and getCharacterRoot(bChar)

    if not aRoot or not bRoot then
        return false
    end

    return (aRoot.Position - rootPart.Position).Magnitude <
           (bRoot.Position - rootPart.Position).Magnitude
end)

    local maxEntries = 6
    for index, player in ipairs(players) do
        if index <= maxEntries then
            local entry = backpackBillboards[player]
            local label = entry and entry.Label or makeBackpackBillboard(player)
            if label then
                label.TextColor3 = getPlayerTextColor(player)
                local tools = {}
                if player.Backpack then
                    for _, item in ipairs(player.Backpack:GetChildren()) do
                        if item:IsA("Tool") then
                            table.insert(tools, item.Name)
                        end
                    end
                end
                local character = player.Character
if character then
    local equipped = character:FindFirstChildOfClass("Tool")
    if equipped then
        table.insert(tools, 1, equipped.Name .. " (Equipped)")
    end
end
                if #tools == 0 then
                    label.Text = "Backpack:\nNone"
                else
                    local lines = {"Backpack:"}
                    for i = 1, math.min(#tools, 5) do
                        table.insert(lines, string.format("%d. %s", i, tools[i]))
                    end
                    label.Text = table.concat(lines, "\n")
                end
            end
        else
            if backpackBillboards[player] then
                backpackBillboards[player].Gui:Destroy()
                backpackBillboards[player] = nil
            end
        end
    end
end

local function createGui()
    if not PlayerGui then
        warn("[PinkAim] PlayerGui was not available when creating the UI.")
        return nil
    end

    local screenGui = create("ScreenGui", {
        Name = "PinkAimClientGui",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        Parent = PlayerGui,
    })

    local mainFrame = create("Frame", {
        Name = "MainFrame",
        Parent = screenGui,
        Size = UDim2.new(0, 340, 0, 420),
        Position = UDim2.new(0.5, -170, 0.08, 0),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
    })
    create("UICorner", {Parent = mainFrame, CornerRadius = UDim.new(0, 18)})
    create("UIGradient", {
        Parent = mainFrame,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Bg),
            ColorSequenceKeypoint.new(1, Theme.PanelSoft),
        }),
        Rotation = 90,
    })

    local topBar = create("Frame", {
        Name = "TopBar",
        Parent = mainFrame,
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    })
    create("UICorner", {Parent = topBar, CornerRadius = UDim.new(0, 18)})
    create("UIGradient", {
        Parent = topBar,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent),
            ColorSequenceKeypoint.new(1, Theme.Panel),
        }),
        Rotation = 90,
    })

    local titleLabel = create("TextLabel", {
        Name = "TitleLabel",
        Parent = topBar,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "Teh Crimbot Panelz",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local titleGradient = create("UIGradient", {
        Name = "TitleGradient",
        Parent = titleLabel,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 237, 247)),
            ColorSequenceKeypoint.new(0.6, Theme.AccentSoft),
            ColorSequenceKeypoint.new(1, Theme.Accent),
        }),
        Rotation = 0,
    })

    create("TextLabel", {
        Parent = topBar,
        Size = UDim2.new(0, 110, 0, 18),
        Position = UDim2.new(1, -118, 0, 12),
        BackgroundTransparency = 1,
        Text = "Modern • Clean • Fast",
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local content = create("Frame", {
        Parent = mainFrame,
        Size = UDim2.new(1, -20, 1, -58),
        Position = UDim2.new(0, 10, 0, 50),
        BackgroundTransparency = 1,
    })

    local scroll = create("ScrollingFrame", {
        Parent = content,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarImageColor3 = Theme.Accent,
        BottomImage = "rbxassetid://",
        MidImage = "rbxassetid://",
        TopImage = "rbxassetid://",
    })

    create("UIListLayout", {
        Parent = scroll,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Top,
    })

    create("UIPadding", {
        Parent = scroll,
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
    })

    local function makeLabel(text)
        local label = create("TextLabel", {
            Parent = scroll,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = text,
            TextColor3 = Theme.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        return label
    end

    local function makeButton(text)
        local button = create("TextButton", {
            Parent = scroll,
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = Theme.Panel,
            BorderSizePixel = 0,
            Text = text,
            TextColor3 = Theme.Text,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
        })
        create("UICorner", {Parent = button, CornerRadius = UDim.new(0, 10)})
        return button
    end

    makeLabel("Hold Right Mouse Button to lock onto the player you are looking at while Auto Aim is enabled.")
    local targetLabel = makeLabel("Target: None")
    local bodyPartLabel = makeLabel("Body Part: " .. selectedBodyPart)

    local bodyPartDropdown = create("TextButton", {
        Parent = scroll,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Text = "Body Part: " .. selectedBodyPart,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    create("UICorner", {Parent = bodyPartDropdown, CornerRadius = UDim.new(0, 10)})

    local bodyPartMenu = create("Frame", {
        Parent = mainFrame,
        Size = UDim2.new(0, 148, 0, 144),
        Position = UDim2.new(1, 8, 0, 72),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,
    })
    create("UICorner", {Parent = bodyPartMenu, CornerRadius = UDim.new(0, 12)})
    create("UIGradient", {
        Parent = bodyPartMenu,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Panel),
            ColorSequenceKeypoint.new(1, Theme.PanelSoft),
        }),
        Rotation = 90,
    })

    local bodyPartList = create("UIListLayout", {
        Parent = bodyPartMenu,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    })
    create("UIPadding", {
        Parent = bodyPartMenu,
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
    })

    local function createBodyPartOption(name)
        local option = create("TextButton", {
            Parent = bodyPartMenu,
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = Theme.PanelSoft,
            BorderSizePixel = 0,
            Text = name,
            TextColor3 = Theme.Text,
            Font = Enum.Font.Gotham,
            TextSize = 13,
        })
        create("UICorner", {Parent = option, CornerRadius = UDim.new(0, 8)})
        option.MouseButton1Click:Connect(function()
            selectedBodyPartIndex = table.find(BodyParts, name) or 1
            selectedBodyPart = name
            updateBodyPartLabel(bodyPartLabel)
            bodyPartDropdown.Text = "Body Part: " .. selectedBodyPart
            bodyPartMenu.Visible = false
        end)
        return option
    end

    for _, name in ipairs(BodyParts) do
        createBodyPartOption(name)
    end
    local autoAimButton = makeButton("Auto Aim: Off")
    local highlightButton = makeButton("Highlight ESP: Off")
    local backpackButton = makeButton("Backpack ESP: Off")
    local fullbrightButton = makeButton("Fullbright: Off")
    local dealerEspButton = makeButton("Dealer ESP: Off")
    local gangCheckerButton = makeButton("Gang Checker: Off")
    local safeAutofarmButton = makeButton("Safe Autofarm: Off")

    local tweenSpeedLabel = create("TextLabel", {
        Parent = scroll,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "Tween Speed: 1.0",
        TextColor3 = Theme.SubText,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local tweenSliderBg = create("Frame", {
        Parent = scroll,
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundColor3 = Theme.ToggleOff,
        BorderSizePixel = 0,
    })
    create("UICorner", {Parent = tweenSliderBg, CornerRadius = UDim.new(0, 6)})
    local tweenSliderFill = create("Frame", {
        Parent = tweenSliderBg,
        Size = UDim2.new(0.25, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    })
    create("UICorner", {Parent = tweenSliderFill, CornerRadius = UDim.new(0, 6)})
    local tweenSliderHandle = create("TextButton", {
        Parent = tweenSliderBg,
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0.25, -7, 0.5, -7),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    })
    create("UICorner", {Parent = tweenSliderHandle, CornerRadius = UDim.new(1, 0)})

    local function updateTweenSpeedDisplay(value)
        tweenSpeed = math.clamp(value, tweenSpeedMin, tweenSpeedMax)
        local percent = (tweenSpeed - tweenSpeedMin) / (tweenSpeedMax - tweenSpeedMin)
        tweenSpeedLabel.Text = string.format("Tween Speed: %.1f", tweenSpeed)
        tweenSliderFill.Size = UDim2.new(percent, 0, 1, 0)
        tweenSliderHandle.Position = UDim2.new(percent, -7, 0.5, -7)
    end

    local function setTweenSpeedFromMouse()
        local absPos = tweenSliderBg.AbsolutePosition
        local absSize = tweenSliderBg.AbsoluteSize
        local mouseX = UserInputService:GetMouseLocation().X - absPos.X
        local percent = math.clamp(mouseX / math.max(absSize.X, 1), 0, 1)
        updateTweenSpeedDisplay(tweenSpeedMin + percent * (tweenSpeedMax - tweenSpeedMin))
    end

    tweenSliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            setTweenSpeedFromMouse()
            local connection
            connection = UserInputService.InputChanged:Connect(function(change)
                if change.UserInputType == Enum.UserInputType.MouseMovement then
                    setTweenSpeedFromMouse()
                end
            end)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    connection:Disconnect()
                end
            end)
        end
    end)

    updateTweenSpeedDisplay(tweenSpeed)

    bodyPartDropdown.MouseButton1Click:Connect(function()
        bodyPartMenu.Visible = not bodyPartMenu.Visible
    end)

    autoAimButton.MouseButton1Click:Connect(function()
        autoAimEnabled = not autoAimEnabled
        autoAimButton.Text = "Auto Aim: " .. (autoAimEnabled and "On" or "Off")
        autoAimButton.BackgroundColor3 = autoAimEnabled and Theme.ToggleOn or Theme.Panel
    end)

    highlightButton.MouseButton1Click:Connect(function()
        local enabled = not highlightEnabled
        highlightButton.Text = "Highlight ESP: " .. (enabled and "On" or "Off")
        highlightButton.BackgroundColor3 = enabled and Theme.ToggleOn or Theme.Panel
        setHighlightsEnabled(enabled)
    end)

    backpackButton.MouseButton1Click:Connect(function()
        backpackEnabled = not backpackEnabled
        backpackButton.Text = "Backpack ESP: " .. (backpackEnabled and "On" or "Off")
        backpackButton.BackgroundColor3 = backpackEnabled and Theme.ToggleOn or Theme.Panel
        if not backpackEnabled then
            updateBackpackBillboards()
        end
    end)

    fullbrightButton.MouseButton1Click:Connect(function()
        local enabled = not fullbrightEnabled
        fullbrightButton.Text = "Fullbright: " .. (enabled and "On" or "Off")
        fullbrightButton.BackgroundColor3 = enabled and Theme.ToggleOn or Theme.Panel
        setFullbright(enabled)
    end)

    dealerEspButton.MouseButton1Click:Connect(function()
        local enabled = not dealerEspEnabled
        dealerEspEnabled = enabled
        dealerEspButton.Text = "Dealer ESP: " .. (enabled and "On" or "Off")
        dealerEspButton.BackgroundColor3 = enabled and Theme.ToggleOn or Theme.Panel
        setDealerEspEnabled(enabled)
    end)

    gangCheckerButton.MouseButton1Click:Connect(function()
        gangEnabled = not gangEnabled
        gangCheckerButton.Text = "Gang Checker: " .. (gangEnabled and "On" or "Off")
        gangCheckerButton.BackgroundColor3 = gangEnabled and Theme.ToggleOn or Theme.Panel
        updateGangHighlights()
    end)

    safeAutofarmButton.MouseButton1Click:Connect(function()
        safeAutofarmEnabled = not safeAutofarmEnabled
        safeAutofarmButton.Text = "Safe Autofarm: " .. (safeAutofarmEnabled and "On" or "Off")
        safeAutofarmButton.BackgroundColor3 = safeAutofarmEnabled and Theme.ToggleOn or Theme.Panel
        if safeAutofarmEnabled then
            startSafeAutofarm()
        else
            stopSafeAutofarm()
        end
    end)

    local topNotice = create("Frame", {
        Parent = screenGui,
        Name = "CrowbarNotice",
        Size = UDim2.new(0, 260, 0, 44),
        Position = UDim2.new(0.5, -130, 0, -70),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20,
    })
    create("UICorner", {Parent = topNotice, CornerRadius = UDim.new(0, 12)})
    local topNoticeLabel = create("TextLabel", {
        Parent = topNotice,
        Name = "Label",
        Size = UDim2.new(1, -16, 1, -8),
        Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1,
        Text = "Buy a Crowbar first",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 21,
    })
    local topNoticeSound = create("Sound", {
        Parent = screenGui,
        Name = "CrowbarWarningSound",
        SoundId = "rbxassetid://9118379794",
        Volume = 0.45,
        Pitch = 1,
    })

    local toggleButton = create("ImageButton", {
        Parent = screenGui,
        Name = "ToggleButton",
        Size = UDim2.new(0, 52, 0, 52),
        Position = UDim2.new(1, -140, 0, 10),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Image = "rbxassetid://87758267633396",
        ScaleType = Enum.ScaleType.Fit,
        AutoButtonColor = false,
        ZIndex = 10,
        Visible = true,
    })
    create("UICorner", {Parent = toggleButton, CornerRadius = UDim.new(0, 14)})

    local isOpen = true
    local function setPanelVisible(visible)
        isOpen = visible
        mainFrame.Visible = visible
        toggleButton.Image = "rbxassetid://87758267633396"
    end

    toggleButton.MouseButton1Click:Connect(function()
        setPanelVisible(not isOpen)
    end)

    create("LocalScript", {
        Name = "TitlePulseScript",
        Parent = screenGui,
        Source = [[
            local TweenService = game:GetService("TweenService")
            local screenGui = script.Parent
            local mainFrame = screenGui:WaitForChild("MainFrame")
            local titleLabel = mainFrame:WaitForChild("TopBar"):WaitForChild("TitleLabel")
            local titleGradient = titleLabel:WaitForChild("TitleGradient")

            local tween = TweenService:Create(titleGradient, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Rotation = 360,
            })
            tween:Play()
        ]],
    })

    makeDraggable(mainFrame, topBar)
    setPanelVisible(true)
    return {
        Gui = screenGui,
        TargetLabel = targetLabel,
        ToggleButton = toggleButton,
        SetPanelVisible = setPanelVisible,
        CrowbarNotice = topNotice,
        CrowbarNoticeLabel = topNoticeLabel,
        CrowbarWarningSound = topNoticeSound,
    }
end

local ui = nil
local success, guiError = pcall(function()
    ui = createGui()
end)

if not success or not ui then
    warn("[PinkAim] UI failed to load:", guiError)
    local fallbackGui = create("ScreenGui", {
        Name = "PinkAimFallbackGui",
        ResetOnSpawn = false,
        Parent = PlayerGui,
    })
    create("TextLabel", {
        Parent = fallbackGui,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Bg,
        Text = "Pink Aimbot UI loaded",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
    })
    local fallbackNotice = create("Frame", {
        Parent = fallbackGui,
        Name = "CrowbarNotice",
        Size = UDim2.new(0, 260, 0, 44),
        Position = UDim2.new(0.5, -130, 0, -70),
        BackgroundColor3 = Theme.Panel,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20,
    })
    create("UICorner", {Parent = fallbackNotice, CornerRadius = UDim.new(0, 12)})
    local fallbackNoticeLabel = create("TextLabel", {
        Parent = fallbackNotice,
        Name = "Label",
        Size = UDim2.new(1, -16, 1, -8),
        Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1,
        Text = "Buy a Crowbar first",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 21,
    })
    local fallbackWarningSound = create("Sound", {
        Parent = fallbackGui,
        Name = "CrowbarWarningSound",
        SoundId = "rbxassetid://9118379794",
        Volume = 0.45,
        Pitch = 1,
    })

    ui = {
        Gui = fallbackGui,
        TargetLabel = nil,
        CrowbarNotice = fallbackNotice,
        CrowbarNoticeLabel = fallbackNoticeLabel,
        CrowbarWarningSound = fallbackWarningSound,
    }
end

local function showCrowbarWarning()
    if not ui or not ui.CrowbarNotice or not ui.CrowbarNoticeLabel or not ui.CrowbarWarningSound then
        return
    end

    local notice = ui.CrowbarNotice
    local label = ui.CrowbarNoticeLabel
    local sound = ui.CrowbarWarningSound

    notice.Visible = true
    label.TextTransparency = 0
    notice.Position = UDim2.new(0.5, -130, 0, -70)
    notice.BackgroundTransparency = 0.08

    sound:Play()

    local tweenIn = TweenService:Create(notice, TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -130, 0, 12),
        BackgroundTransparency = 0.08,
    })
    tweenIn:Play()

    task.delay(1.35, function()
        if not notice or not notice.Parent then
            return
        end
        local tweenOut = TweenService:Create(notice, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -130, 0, -70),
            BackgroundTransparency = 1,
        })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            if notice and notice.Parent then
                notice.Visible = false
            end
        end)
    end)
end

local backpackTimer = 0

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimHolding = true
        if autoAimEnabled then
            selectTarget(ui.TargetLabel)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimHolding = false
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if lastKiller and lastKiller.Character and lastKiller.Character.Parent then
        updateLastKillerHighlight()
    end

    if gangEnabled then
        updateGangHighlights()
    end

    if autoAimEnabled and aimHolding then
        local targetPart = getTargetPart()
        if targetPart and Camera then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
        end
    end

    if backpackEnabled then
        backpackTimer = backpackTimer + dt
        if backpackTimer >= 0.75 then
            updateBackpackBillboards()
            backpackTimer = 0
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    if highlightEnabled then
        task.defer(function()
            applyHighlightToPlayer(player)
        end)
    end

    player.CharacterAdded:Connect(function(character)
        if not highlightEnabled then
            return
        end

        task.wait(0.15)
        if player and player.Character and player.Character.Parent then
            applyHighlightToPlayer(player)
        end
    end)

    player.CharacterAdded:Connect(function(character)
        task.wait(0.1)
        if highlightEnabled then
            applyHighlightToPlayer(player)
        end
        if backpackEnabled then
            updateBackpackBillboards()
        end

        if character and character.Parent then
            task.defer(function()
                if highlightEnabled then
                    applyHighlightToPlayer(player)
                end
            end)
        end
    end)

    if player.Character and player.Character.Parent then
        task.wait(0.1)
        if highlightEnabled then
            applyHighlightToPlayer(player)
        end
        if backpackEnabled then
            updateBackpackBillboards()
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    local humanoid = character and character:WaitForChild("Humanoid", 5)
    if not humanoid then
        return
    end

    local previousHealth = humanoid.Health or 0

    humanoid.HealthChanged:Connect(function(newHealth)
        if typeof(newHealth) ~= "number" or typeof(previousHealth) ~= "number" then
            return
        end

        if newHealth < previousHealth then
            local success, attacker = pcall(getNearestPlayerToLocal)
            if success and attacker and attacker ~= LocalPlayer then
                lastKiller = attacker
                updateLastKillerHighlight()
            end
        end
        previousHealth = newHealth
    end)

    humanoid.Died:Connect(function()
        if lastKiller then
            updateLastKillerHighlight()
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if highlightCache[player] then
        highlightCache[player]:Destroy()
        highlightCache[player] = nil
    end
    if killerHighlightCache[player] then
        killerHighlightCache[player]:Destroy()
        killerHighlightCache[player] = nil
    end
    if backpackBillboards[player] then
        backpackBillboards[player].Gui:Destroy()
        backpackBillboards[player] = nil
    end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local function updateDealerHover(dealer)
    if not dealer then
        hoverFrame.Visible = false
        return
    end

    local stocks = getDealerStocks(dealer)

    local restock = dealer:FindFirstChild("RestockTime")
    local timeText = ""

    if restock and restock:IsA("IntValue") then
        timeText = "Restock: " .. formatTime(restock.Value)
    end

    local text = "Dealer Stocks:\n"

    for _, v in ipairs(stocks) do
        text ..= v .. "\n"
    end

    text ..= "\n" .. timeText

    hoverLabel.Text = text
    hoverFrame.Visible = true
end

RunService.RenderStepped:Connect(function()
    local target = Mouse.Target
    local model = target and target:FindFirstAncestorOfClass("Model")

    if model and model:FindFirstChild("Current Stocks") then
        updateDealerHover(model)
    else
        hoverFrame.Visible = false
    end
end)
