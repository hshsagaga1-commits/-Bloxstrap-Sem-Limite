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

-- Patch 1: GUIScaler Evade Overhaul V4: direct button sizing, persistent/reversible.
local scaleStartMarker = "local funnycon\nlocal guisets = {}"
local scaleEndMarker = "local touchuuval = 1.2"

local scaleStartPos = string.find(source, scaleStartMarker, 1, true)
local scaleEndPos = scaleStartPos and string.find(source, scaleEndMarker, scaleStartPos, true)

if not scaleStartPos or not scaleEndPos then
    error("GUIScaler block not found. Bloxstrap was probably updated.")
end

local scalePatched = [=[
local funnycon
local funnyrootcon

-- V4: the Evade Overhaul HUD uses buttons INSIDE ScreenGui.
-- Resize the actual GuiObjects, not the ScreenGui container.
-- MoverBotoes V50 demonstrated that button.Size works on the new HUD.
local MIN_SCALE = math.clamp(tonumber(getgenv().BloxstrapMinScale) or 0.01, 0.01, 1)
local currentScale = math.clamp(tonumber(getgenv().BloxstrapCurrentScale) or 0.45, MIN_SCALE, 1)
local TAG = "__BloxstrapUnlimitedScale"
local active = false
local pendingScan = false
local records = setmetatable({}, {__mode = "k"})
local watching = setmetatable({}, {__mode = "k"})
local Stats = {resized = 0, repairs = 0}

local protectedNames = {
    pcjoystick=true, pcjump=true,
    dynamicthumbstickframe=true, thumbstickframe=true,
    touchthumbstick=true, jumpbutton=true, touchjump=true,
    jumpcontrol=true, joystick=true, thumbstick=true, jump=true,
    perfectuimanager_ui=true, perfectuimanager_shield=true,
    pckeyboardtouchbridgev52overlay=true,
}
local hudTokens = {"hud", "mobile", "control", "hotbar", "action",
    "emote", "crouch", "sprint", "slide", "dash", "interact", "carry",
    "equip", "backpack"}

local function excluded(node)
    local cursor = node
    while cursor and cursor ~= lplr.PlayerGui do
        local name = string.lower(cursor.Name)
        if protectedNames[name]
            or string.find(name, "bloxstrap", 1, true)
            or string.find(name, "delta", 1, true)
            or string.find(name, "perfectuimanager", 1, true)
            or string.find(name, "pcmovement", 1, true)
        then return true end
        cursor = cursor.Parent
    end
    return cursor ~= lplr.PlayerGui
end

local function isCandidate(node)
    if not node or not node:IsA("GuiObject") then return false end
    if node:IsA("GuiButton") then return true end
    local name = string.lower(node.Name)
    if (node:IsA("Frame") or node:IsA("ImageLabel"))
        and (string.find(name, "button", 1, true)
        or string.find(name, "action", 1, true)
        or string.find(name, "emote", 1, true))
        and not node:FindFirstChildWhichIsA("GuiButton", true) then
        return true
    end
    return false
end

local function isHudSized(node)
    if excluded(node) or not node.Visible then return false end
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 450)
    local size = node.AbsoluteSize
    if size.X < 5 or size.Y < 5 or viewport.X < 50 or viewport.Y < 50
        or size.X > viewport.X * 0.34 or size.Y > viewport.Y * 0.36 then
        return false
    end

    -- Keep menus, full-screen windows, inventory lists and emote panels intact.
    -- Pick individual floating HUD buttons (as MoverBotoes does), not their roots.
    local pos = node.AbsolutePosition
    -- Menus and popup windows are NOT HUD, even when they reuse button names.
    local ancestor = node.Parent
    while ancestor and ancestor ~= lplr.PlayerGui do
        if ancestor:IsA("GuiObject") then
            local aname = string.lower(ancestor.Name)
            local panel = string.find(aname, "panel", 1, true)
                or string.find(aname, "window", 1, true)
                or string.find(aname, "popup", 1, true)
                or string.find(aname, "settings", 1, true)
                or string.find(aname, "shop", 1, true)
                or string.find(aname, "inventory", 1, true)
                or string.find(aname, "mainmenu", 1, true)
                or string.find(aname, "emotewheel", 1, true)
            if panel and ancestor.AbsoluteSize.X > viewport.X * 0.48
                and ancestor.AbsoluteSize.Y > viewport.Y * 0.36 then
                return false
            end
        end
        ancestor = ancestor.Parent
    end
    local edge = pos.X < viewport.X * 0.23
        or pos.X + size.X > viewport.X * 0.77
        or pos.Y < viewport.Y * 0.24
        or pos.Y + size.Y > viewport.Y * 0.76
    local hint = false
    local parent = node
    while parent and parent ~= lplr.PlayerGui do
        local name = string.lower(parent.Name)
        for _, token in ipairs(hudTokens) do
            if string.find(name, token, 1, true) then
                hint = true
                break
            end
        end
        if hint then break end
        parent = parent.Parent
    end
    return edge or hint
end

local function scaledSize(original, factor)
    return UDim2.new(original.X.Scale * factor, original.X.Offset * factor,
        original.Y.Scale * factor, original.Y.Offset * factor)
end

local function restoreOne(node, rec)
    if not node.Parent then return end
    rec.busy = true
    if rec.method == "size" then
        -- Respect a custom size that MoverBotoes may have set afterward.
        if node.Size == rec.applied then node.Size = rec.original end
    elseif rec.method == "uiscale" and rec.scaler and rec.scaler.Parent then
        rec.scaler:Destroy()
    end
    rec.busy = false
end

local function restoreAll()
    for node, rec in pairs(records) do
        pcall(restoreOne, node, rec)
    end
    for node, list in pairs(watching) do
        for _, connection in ipairs(list) do
            pcall(function() connection:Disconnect() end)
        end
        watching[node] = nil
    end
    records = setmetatable({}, {__mode = "k"})
end

local function applyOne(node)
    if not active or not isCandidate(node) or not isHudSized(node) then
        return
    end
    local rec = records[node]
    if not rec then
        local native = node.Size
        -- The real button may be laid out visually before Size is assigned.
        if native == UDim2.new(0, 0, 0, 0) then
            native = UDim2.fromOffset(node.AbsoluteSize.X, node.AbsoluteSize.Y)
        end
        rec = {original=native, method="size", applied=nil, busy=false}
        local parent = node.Parent
        local layout = parent and parent:FindFirstChildWhichIsA("UIGridStyleLayout")
        if layout then
            -- GridLayout owns Size. Scale only THIS button, never the full grid.
            rec.method = "uiscale"
        end
        records[node] = rec
        Stats.resized += 1
    end
    if rec.busy then return end
    rec.busy = true
    if rec.method == "size" then
        local requested = scaledSize(rec.original, currentScale)
        -- Do not overwrite manual resizing by MoverBotoes.
        if rec.applied == nil or node.Size == rec.applied or node.Size == rec.original then
            node.Size = requested
            rec.applied = requested
        end
    else
        if not rec.scaler or not rec.scaler.Parent then
            rec.scaler = Instance.new("UIScale")
            rec.scaler.Name = TAG
            rec.scaler.Parent = node
        end
        rec.scaler.Scale = currentScale
    end
    rec.busy = false
end

local function observe(node)
    if not isCandidate(node) or watching[node] or excluded(node) then return end
    local listeners = {}
    watching[node] = listeners
    listeners[#listeners+1] = node:GetPropertyChangedSignal("Visible"):Connect(function()
        if active and node.Visible then task.defer(applyOne, node) end
    end)
    listeners[#listeners+1] = node:GetPropertyChangedSignal("Size"):Connect(function()
        if not active then return end
        local rec = records[node]
        if rec and not rec.busy and rec.method == "size" and node.Size == rec.original then
            -- The game reset an existing control after a round; reapply once.
            Stats.repairs += 1
            task.defer(function()
                if active and node.Parent and node.Size == rec.original then applyOne(node) end
            end)
        elseif not rec then
            task.defer(applyOne, node)
        end
    end)
    applyOne(node)
end

local function scanPlayerGui()
    if not active then return end
    for _, node in ipairs(lplr.PlayerGui:GetDescendants()) do
        if isCandidate(node) then observe(node) end
    end
end

local function scheduleScan()
    if not active or pendingScan then return end
    pendingScan = true
    task.delay(0.16, function()
        pendingScan = false
        if active then scanPlayerGui() end
    end)
end

local function stopScaler()
    active = false
    if funnycon then funnycon:Disconnect(); funnycon = nil end
    if funnyrootcon then funnyrootcon:Disconnect(); funnyrootcon = nil end
    restoreAll()
end

local previousScaler = getgenv().__BloxstrapHUDScalerCleanup
if type(previousScaler) == "function" then pcall(previousScaler) end
getgenv().__BloxstrapHUDScalerCleanup = stopScaler
getgenv().BloxstrapCurrentScale = currentScale

local function startScaler()
    stopScaler()
    active = true
    scanPlayerGui()
    funnycon = lplr.PlayerGui.DescendantAdded:Connect(function(node)
        if isCandidate(node) then
            -- Deferral lets Evade finish assigning Size and Position first.
            task.defer(observe, node)
            task.delay(0.25, function()
                if active and node.Parent then applyOne(node) end
            end)
        elseif node:IsA("ScreenGui") then
            scheduleScan()
        end
    end)
    funnyrootcon = lplr.PlayerGui.ChildAdded:Connect(scheduleScan)
    scheduleScan()
end

-- Optional explicit scale control. Affects ONLY buttons we own.
getgenv().BloxstrapHUDScaler = {
    GetScale = function() return currentScale end,
    GetState = function() return {enabled=active, scale=currentScale,
        resized=Stats.resized, repairs=Stats.repairs} end,
    SetScale = function(value)
        value = tonumber(value)
        if not value then return false end
        currentScale = math.clamp(value, MIN_SCALE, 1)
        getgenv().BloxstrapCurrentScale = currentScale
        if active then
            for node in pairs(records) do
                if node.Parent then applyOne(node) end
            end
            scanPlayerGui()
        end
        return true
    end
}

local guiscale = Appearance:AddToggle({
    Name = "GUIScaler",
    Description = "Reduz botoes HUD reais sem mover joystick/pulo; persiste por mapa/rodada.",
    Default = Bloxstrap.Config.GUIScale,
    Callback = function(call)
        Bloxstrap.UpdateConfig("GUIScale", call)
        if call then startScaler() else stopScaler() end
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

-- Preset de inicializacao: escala -4 niveis e crosshair ligado.
source = string.gsub(source, "Bloxstrap.canUpdate = true", [[Bloxstrap.canUpdate = true
task.defer(function()
    -- Ativa uma unica vez; nao alterna false/true na inicializacao.
    pcall(function()
        guiscale:Toggle(true)
    end)
    pcall(function()
        crosshair:Toggle(true)
    end)
end)
]], 1)

-- Patch 3 temporarily removed to restore the original upstream Display FPS block.

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
