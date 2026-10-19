local RAW = "https://raw.githubusercontent.com/new-qwertyui/Bloxstrap/main/"
local API = "https://api.github.com/repos/new-qwertyui/Bloxstrap/contents/"
local hidegui = getgenv().hideui or false

local cloneref = cloneref or function(...)
    return ...
end

local HttpService = cloneref(game:GetService("HttpService"))

local function noCache(url)
    local separator = string.find(url, "?", 1, true) and "&" or "?"
    return url .. separator .. "_cb=" .. HttpService:GenerateGUID(false)
end

local function mkdir(path)
    if makefolder and not isfolder(path) then
        pcall(makefolder, path)
    end
end

mkdir("Bloxstrap")
mkdir("Bloxstrap/Main")
mkdir("Bloxstrap/Main/Functions")
mkdir("Bloxstrap/Main/Configs")
mkdir("Bloxstrap/Main/Fonts")
mkdir("Bloxstrap/Images")

local function installMissing()
    if not isfile("Bloxstrap/Main/Functions/GuiLibrary.lua") then
        local list = HttpService:JSONDecode(
            game:HttpGet(noCache(API .. "Main/Functions"), true)
        )

        for _, v in ipairs(list) do
            if v.name and v.name:find("%.lua$") then
                writefile(
                    "Bloxstrap/Main/Functions/" .. v.name,
                    "return loadstring(game:HttpGet('" .. RAW .. "Main/Functions/" .. v.name .. "?_cb=' .. game:GetService('HttpService'):GenerateGUID(false), true))()"
                )
            end
        end
    end

    if not isfile("Bloxstrap/Main/Configs/Default.json") then
        writefile("Bloxstrap/Main/Configs/Default.json", "{}")
    end
end

installMissing()

local source = game:HttpGet(
    noCache(RAW .. "Main/Bloxstrap.lua"),
    true
)

-- Patch 1: GUIScaler continua abaixo de 0.50, mas com passos menores depois disso.
local scaleStartMarker = "local funnycon\nlocal guisets = {}"
local scaleEndMarker = "local touchuuval = 1.2"

local scaleStartPos = string.find(source, scaleStartMarker, 1, true)
local scaleEndPos = scaleStartPos and string.find(source, scaleEndMarker, scaleStartPos, true)

if not scaleStartPos or not scaleEndPos then
    error("GUIScaler block not found. Bloxstrap was probably updated.")
end

local scalePatched = [=[
local funnycon
local scalerConnections = {}
-- Cada ativação do toggle desce só um degrau; revarreduras não diminuem mais.
local MIN_SCALE = 0.10
local activeScale = 1.00

local function nextScale(current)
    current = tonumber(current) or 1
    if current > 0.80 then return 0.80 end
    if current > 0.65 then return 0.65 end
    if current > 0.50 then return 0.50 end
    if current > 0.35 then return 0.35 end
    if current > 0.25 then return 0.25 end
    if current > 0.15 then return 0.15 end
    return MIN_SCALE
end

local function getDirectScale(gui)
    for _, child in ipairs(gui:GetChildren()) do
        if child:IsA("UIScale") and child.Name == "__BloxstrapUnlimitedScale" then
            return child
        end
    end
end

local function nameIsExcluded(name)
    name = string.lower(name)
    if name:find("chat", 1, true)
        or name:find("message", 1, true)
        or name:find("emote", 1, true)
        or name:find("backpack", 1, true)
        or name:find("inventory", 1, true)
        or name:find("toolbelt", 1, true)
        or name:find("textbox", 1, true)
        or name:find("chatbar", 1, true)
        or name:find("textchat", 1, true)
        or name:find("quickchat", 1, true)
        or name:find("emotewheel", 1, true)
        or name:find("emote-wheel", 1, true)
        then
        return true
    end
    return name == "touchgui"
        or name == "emotes"
        or name == "emotemenu"
        or name == "emote_menu"
        or name == "robloxmenu"
        or name == "chat"
        or name == "chatwindow"
        or name == "chatbar"
        or name == "chatinput"
        or name == "textchat"
        or name == "channelsbar"
        or name == "bubblechat"
        or name == "backpack"
        or name == "backpackgui"
        or name == "inventory"
        or name == "toolinventory"
        or name == "toolbelt"
        or name == "emoteanimation"
end

local function isBackpackToggle(gui)
    return gui and gui:IsA("GuiButton")
        and string.lower(gui.Name):find("backpack", 1, true) ~= nil
end

-- Protege os próprios itens da mochila, mesmo quando o nome do objeto é genérico.
local function isInventoryItem(gui)
    if not gui then return false end
    local function matches(value)
        value = string.lower(tostring(value or ""))
        return value == "velocidade" or value == "cola"
            or value:find("velocidade", 1, true) ~= nil
            or value:find("cola", 1, true) ~= nil
    end
    if matches(gui.Name) then return true end
    pcall(function()
        if gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox") then
            if matches(gui.Text) then return true end
        end
    end)
    local found = false
    for _, descendant in ipairs(gui:GetDescendants()) do
        if matches(descendant.Name) then return true end
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
            if matches(descendant.Text) then found = true; break end
        end
    end
    return found
end

local function isExcluded(gui)
    local current = gui
    while current and current ~= lplr.PlayerGui do
        -- O botão que abre a mochila pode diminuir; os itens e o painel ficam intactos.
        if (nameIsExcluded(current.Name) and not isBackpackToggle(current))
            or isInventoryItem(current) then
            return true
        end
        current = current.Parent
    end
    return false
end

local function isFullScreenContainer(gui)
    if not gui:IsA("GuiObject") then return false end
    local size = gui.Size
    if size.X.Scale >= 0.90 and size.Y.Scale >= 0.90 then
        return true
    end

    local camera = workspace.CurrentCamera
    if camera then
        local viewport = camera.ViewportSize
        local absolute = gui.AbsoluteSize
        if viewport.X > 0 and viewport.Y > 0
            and absolute.X >= viewport.X * 0.90
            and absolute.Y >= viewport.Y * 0.90 then
            return true
        end
    end
    return false
end

local function applyToGroup(gui)
    if not gui:IsA("GuiObject") or isExcluded(gui) then return end

    local scaler = getDirectScale(gui)
    if scaler then
        -- Nunca desce em revarreduras; só usa o degrau escolhido ao ativar.
        if scaler.Scale > activeScale then
            scaler.Scale = activeScale
        end
    else
        scaler = Instance.new("UIScale")
        scaler.Name = "__BloxstrapUnlimitedScale"
        scaler.Scale = activeScale
        scaler.Parent = gui
    end
end

local function directGuiChildren(node)
    local result = {}
    for _, child in ipairs(node:GetChildren()) do
        if child:IsA("GuiObject") and not isExcluded(child) then
            table.insert(result, child)
        end
    end
    return result
end

local function hasExcludedBranch(node)
    for _, descendant in ipairs(node:GetDescendants()) do
        if nameIsExcluded(descendant.Name) or isInventoryItem(descendant) then
            return true
        end
    end
    return false
end

local function hasLayout(node)
    for _, child in ipairs(node:GetChildren()) do
        if child:IsA("UIListLayout") or child:IsA("UIGridLayout")
            or child:IsA("UITableLayout") or child:IsA("UIPageLayout") then
            return true
        end
    end
    return false
end

-- Scale a shared container so sibling controls keep their relative layout.
-- Never destroy layouts; UIScale scales the group without baking positions.
local function scaleTree(node)
    if not node or isExcluded(node) then return end

    if node:IsA("ScreenGui") then
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("GuiObject") and not isExcluded(child) then
                scaleTree(child)
            end
        end
        return
    end
    if not node:IsA("GuiObject") then return end

    if isFullScreenContainer(node) then
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("GuiObject") and not isExcluded(child) then
                scaleTree(child)
            end
        end
        return
    end

    local children = directGuiChildren(node)
    local groupCandidate = #children >= 2 and not hasExcludedBranch(node)

    -- Prefer the smallest shared container that owns sibling controls.
    -- UIScale is applied to the container rather than each child, so the
    -- controls remain grouped (e.g. life + speed) instead of drifting apart.
    if groupCandidate then
        applyToGroup(node)
        return
    end

    -- If the branch is a single actionable control, still scale it rather
    -- than silently doing nothing. Its anchor point remains unchanged.
    if #children == 0 then
        applyToGroup(node)
        return
    end

    for _, child in ipairs(children) do
        scaleTree(child)
    end
end

local function disconnectScaler()
    if funnycon then
        pcall(function() funnycon:Disconnect() end)
        funnycon = nil
    end
    for _, connection in ipairs(scalerConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(scalerConnections)
end

local function watchScreenGui(screenGui)
    if not screenGui:IsA("ScreenGui") or isExcluded(screenGui)
        or screenGui:GetAttribute("__BloxstrapScaleWatcher") then
        return
    end
    screenGui:SetAttribute("__BloxstrapScaleWatcher", true)

    local connection = screenGui.DescendantAdded:Connect(function(child)
        task.defer(function()
            if child and child.Parent and child:IsA("GuiObject") and not isExcluded(child) then
                -- Re-scan the ScreenGui so newly added buttons join their
                -- correct shared group instead of being scaled independently.
                if screenGui.Parent then scaleTree(screenGui) end
            end
        end)
    end)
    table.insert(scalerConnections, connection)
end

local scalePassQueued = false

local function applyScalePass()
    for _, gui in ipairs(lplr.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and not isExcluded(gui) then
            scaleTree(gui)
            watchScreenGui(gui)
        end
    end
end

-- Batch rapid UI creation into one scan instead of rescanning the whole UI
-- tree for every individual GuiObject added by the game.
local function requestScalePass()
    if scalePassQueued then return end
    scalePassQueued = true
    task.defer(function()
        scalePassQueued = false
        if lplr and lplr.Parent and lplr:FindFirstChild("PlayerGui") then
            applyScalePass()
        end
    end)
end

local guiscale = Appearance:AddToggle({
    Name = "GUIScaler",
    Description = "Stronger grouped UI scaling; chat and emotes are excluded",
    Default = Bloxstrap.Config.GUIScale,
    Callback = function(call)
        Bloxstrap.UpdateConfig("GUIScale", call)
        if call then
            disconnectScaler()
            activeScale = nextScale(activeScale)
            -- Clear stale watcher markers so a re-enabled toggle can reconnect.
            for _, gui in ipairs(lplr.PlayerGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    gui:SetAttribute("__BloxstrapScaleWatcher", nil)
                end
            end
            applyScalePass()
            table.insert(scalerConnections, lplr.CharacterAdded:Connect(function()
                task.defer(function()
                    if lplr and lplr.Parent then
                        applyScalePass()
                    end
                end)
            end))
            table.insert(scalerConnections, lplr.PlayerGui.DescendantAdded:Connect(function(child)
                if child and child:IsA("GuiObject") and not isExcluded(child) then
                    requestScalePass()
                end
            end))
            funnycon = lplr.PlayerGui.ChildAdded:Connect(function(gui)
                task.defer(function()
                    if gui and gui.Parent == lplr.PlayerGui and gui:IsA("ScreenGui") and not isExcluded(gui) then
                        scaleTree(gui)
                        watchScreenGui(gui)
                    end
                end)
            end)
        else
            disconnectScaler()
            for _, gui in ipairs(lplr.PlayerGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    gui:SetAttribute("__BloxstrapScaleWatcher", nil)
                end
            end
        end
    end
})

]=]

source = string.sub(source, 1, scaleStartPos - 1)
    .. scalePatched
    .. string.sub(source, scaleEndPos)

-- Patch 2: Crosshair mobile-safe.
-- Usa imagem customizada se funcionar; sem imagem usa um ponto branco minúsculo.
local crossStartMarker = "local chosenimage = ''"
local crossEndMarker = "Appearance:AddSection('Customizations')"

local crossStartPos = string.find(source, crossStartMarker, 1, true)
local crossEndPos = crossStartPos and string.find(source, crossEndMarker, crossStartPos, true)

if not crossStartPos or not crossEndPos then
    error("Crosshair block not found. Bloxstrap was probably updated.")
end

local crossPatched = [=[
local chosenimage = ''
local crosshairRoot
local crosshairImage
local fallbackDot

local guiParent = game:GetService("CoreGui")
pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

pcall(function()
    local old = guiParent:FindFirstChild("BloxstrapCrosshair")
    if old then
        old:Destroy()
    end
end)

local screengui = Instance.new("ScreenGui")
screengui.Name = "BloxstrapCrosshair"
screengui.IgnoreGuiInset = true
screengui.ResetOnSpawn = false
screengui.DisplayOrder = 999999
screengui.Enabled = false
screengui.Parent = guiParent

local function makeCircle(frame)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = frame
end

local function ensureCrosshair()
    if crosshairRoot and crosshairRoot.Parent then
        return
    end

    crosshairRoot = Instance.new("Frame")
    crosshairRoot.Name = "CrosshairRoot"
    crosshairRoot.AnchorPoint = Vector2.new(0.5, 0.5)
    crosshairRoot.Position = UDim2.new(0.5, 0, 0.5, 0)
    crosshairRoot.Size = UDim2.new(0, 8, 0, 8)
    crosshairRoot.BackgroundTransparency = 1
    crosshairRoot.ZIndex = 100
    crosshairRoot.Parent = screengui

    crosshairImage = Instance.new("ImageLabel")
    crosshairImage.Name = "CustomImage"
    crosshairImage.AnchorPoint = Vector2.new(0.5, 0.5)
    crosshairImage.Position = UDim2.fromScale(0.5, 0.5)
    crosshairImage.Size = UDim2.new(0, 8, 0, 8)
    crosshairImage.BackgroundTransparency = 1
    crosshairImage.ZIndex = 102
    crosshairImage.Parent = crosshairRoot

    fallbackDot = Instance.new("Frame")
    fallbackDot.Name = "Dot"
    fallbackDot.AnchorPoint = Vector2.new(0.5, 0.5)
    fallbackDot.Position = UDim2.fromScale(0.5, 0.5)
    fallbackDot.Size = UDim2.new(0, 2, 0, 2)
    fallbackDot.BorderSizePixel = 0
    fallbackDot.BackgroundColor3 = Color3.new(1, 1, 1)
    fallbackDot.ZIndex = 101
    fallbackDot.Parent = crosshairRoot
    makeCircle(fallbackDot)
end

local function refreshCrosshairVisual()
    ensureCrosshair()

    local hasImage = type(chosenimage) == "string" and chosenimage ~= ""
    crosshairImage.Image = hasImage and chosenimage or ""
    crosshairImage.Visible = hasImage
    fallbackDot.Visible = not hasImage
end

local function tryLoadCrosshairAsset(path)
    if type(path) ~= "string" or path == "" then
        return ""
    end

    local assetFn = getcustomasset or getsynasset
    if not assetFn then
        return ""
    end

    local ok, asset = pcall(assetFn, path)
    if ok and type(asset) == "string" then
        return asset
    end

    return ""
end

pcall(function()
    if Bloxstrap.Config.CrosshairImage and Bloxstrap.Config.CrosshairImage ~= "" then
        chosenimage = tryLoadCrosshairAsset(Bloxstrap.Config.CrosshairImage)
    end
end)

refreshCrosshairVisual()

local crosshair = Appearance:AddToggle({
    Name = "Crosshair",
    Description = "Tiny centered dot, mobile-safe",
    Default = Bloxstrap.Config.Crosshair,
    Callback = function(call)
        Bloxstrap.UpdateConfig("Crosshair", call)
        refreshCrosshairVisual()
        screengui.Enabled = call and true or false
    end
})

local imageOptions = {}
pcall(function()
    if listfiles then
        imageOptions = listfiles("Bloxstrap/Images")
    end
end)

Appearance:AddDropdown({
    Name = "Image",
    Options = imageOptions,
    Default = Bloxstrap.Config.CrosshairImage,
    Callback = function(val)
        Bloxstrap.UpdateConfig("CrosshairImage", val)
        chosenimage = tryLoadCrosshairAsset(val)
        refreshCrosshairVisual()
    end
})

]=]

source = string.sub(source, 1, crossStartPos - 1)
    .. crossPatched
    .. string.sub(source, crossEndPos)

local chunk, err = loadstring(
    source,
    "Bloxstrap Smooth GUI Scale + Tiny Dot Crosshair"
)

if not chunk then
    error(err)
end

local Bloxstrap = chunk()

Bloxstrap.start()
Bloxstrap.Visible(not hidegui)
