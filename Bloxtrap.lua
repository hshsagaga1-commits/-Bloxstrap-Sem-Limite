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

-- Mantem o nivel escolhido durante recriacoes de UI/mapa.
-- Escala final configuravel: padrao 0.01, mas a UI nova recebe o nivel atual,
-- nao volta para 0.75 nem reinicia a sequencia.
local MIN_SCALE = tonumber(getgenv().BloxstrapMinScale) or 0.01
MIN_SCALE = math.clamp(MIN_SCALE, 0.01, 1)

local scaleLevels = {1, 0.75, 0.50, 0.40, 0.30, 0.20, 0.10, 0.05, MIN_SCALE}
-- Preset fixo: quatro passos a partir de 1.0 = 0.30; nao acumula entre execucoes.
local currentScale = 0.30
getgenv().BloxstrapCurrentScale = currentScale

local function nextScale(current)
    local nearestIndex = 1
    local nearestDistance = math.huge
    for i, level in ipairs(scaleLevels) do
        local distance = math.abs(level - current)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestIndex = i
        end
    end
    local nextIndex = math.min(nearestIndex + 1, #scaleLevels)
    return scaleLevels[nextIndex]
end

local protectedTouchNames = {
    pcjoystick = true, pcjump = true,
    dynamicthumbstickframe = true, thumbstickframe = true,
    touchthumbstick = true, jumpbutton = true, touchjump = true,
}

local function isProtectedTouchControl(node)
    return node and protectedTouchNames[string.lower(node.Name)] == true
end

local function containsProtectedTouchControl(node)
    for _, descendant in ipairs(node:GetDescendants()) do
        if isProtectedTouchControl(descendant) then return true end
    end
    return false
end

local function applyScaleToObject(node, scale)
    if not node or isProtectedTouchControl(node) then return end
    -- Nunca altere UIScale de descendentes: isso causa escalas multiplicadas
    -- em cada inicializacao e faz os botoes desaparecerem.
    local uiscale = node:FindFirstChild("__BloxstrapUnlimitedScale")
    if not uiscale or not uiscale:IsA("UIScale") then
        uiscale = Instance.new("UIScale")
        uiscale.Name = "__BloxstrapUnlimitedScale"
        uiscale.Parent = node
    end
    uiscale.Scale = scale
end

local function scaleTouchGuiNode(node, scale)
    if isProtectedTouchControl(node) then return end
    if containsProtectedTouchControl(node) then
        for _, child in ipairs(node:GetChildren()) do
            scaleTouchGuiNode(child, scale)
        end
        return
    end
    if node:IsA("GuiObject") then
        applyScaleToObject(node, scale)
    else
        for _, child in ipairs(node:GetChildren()) do
            scaleTouchGuiNode(child, scale)
        end
    end
end

local function scalePlayerGui(v, scale)
    if not v then return end
    if v.Name == "TouchGui" then
        for _, child in ipairs(v:GetChildren()) do
            scaleTouchGuiNode(child, scale)
        end
        return
    end
    local hasCustomMovementControls = false
    pcall(function()
        hasCustomMovementControls =
            v:FindFirstChild("PCJoystick", true) ~= nil
            or v:FindFirstChild("PCJump", true) ~= nil
    end)
    if v.Name == "PCKeyboardTouchBridgeV52Overlay" or hasCustomMovementControls then
        return
    end
    applyScaleToObject(v, scale)
end

local function disconnectScaler()
    pcall(function()
        if funnycon then funnycon:Disconnect(); funnycon = nil end
    end)
end

local function applyScalePass(scale)
    for _, v in ipairs(lplr.PlayerGui:GetChildren()) do
        scalePlayerGui(v, scale)
    end
end

local guiscale = Appearance:AddToggle({
    Name = "GUIScaler",
    Description = "Cada ativacao avanca um nivel; UIs recriadas mantem o ultimo nivel escolhido.",
    Default = Bloxstrap.Config.GUIScale,
    Callback = function(call)
        Bloxstrap.UpdateConfig("GUIScale", call)
        if call then
            disconnectScaler()
            -- Aplica o preset fixo de quatro passos e para; nao avanca novamente.
            getgenv().BloxstrapCurrentScale = currentScale
            applyScalePass(currentScale)
            funnycon = lplr.PlayerGui.ChildAdded:Connect(function(v)
                task.defer(function()
                    -- Reutiliza o ultimo nivel selecionado; nao avanca de novo.
                    scalePlayerGui(v, currentScale)
                end)
            end)
        else
            disconnectScaler()
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

-- Patch 3: Display FPS compacto, com fundo preto totalmente opaco.
-- O overlay nativo do FFlag nao permite configurar escala nem fundo; substituimos
-- somente o toggle Display FPS por um painel compacto com FPS e ping.
local displayFPSStart = [=[
EngineSettings:AddToggle({
    Name = 'Display FPS',
    Default = Bloxstrap.Config.DisplayFPS,
    Callback = function(call)
        Bloxstrap.UpdateConfig('DisplayFPS', call)
        Bloxstrap.ToggleFFlag('FFlagDebugDisplayFPS', call);
    end
})
]=]
local displayFPSReplacement = [=[
local compactStatsGui
local compactStatsConnection

local function stopCompactStats()
    if compactStatsConnection then
        compactStatsConnection:Disconnect()
        compactStatsConnection = nil
    end
    if compactStatsGui then
        pcall(function() compactStatsGui:Destroy() end)
        compactStatsGui = nil
    end
end

local function startCompactStats()
    stopCompactStats()
    Bloxstrap.ToggleFFlag('FFlagDebugDisplayFPS', false)

    local parent = game:GetService("CoreGui")
    pcall(function()
        if gethui then parent = gethui() end
    end)

    compactStatsGui = Instance.new("ScreenGui")
    compactStatsGui.Name = "BloxstrapCompactDisplayFPS"
    compactStatsGui.ResetOnSpawn = false
    compactStatsGui.IgnoreGuiInset = true
    compactStatsGui.DisplayOrder = 999998
    compactStatsGui.Parent = parent

    local panel = Instance.new("Frame")
    panel.Name = "StatsPanel"
    panel.Position = UDim2.new(0, 8, 0, 8)
    panel.Size = UDim2.new(0, 112, 0, 34)
    panel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    panel.BackgroundTransparency = 0
    panel.BorderSizePixel = 0
    panel.Parent = compactStatsGui

    local label = Instance.new("TextLabel")
    label.Name = "StatsText"
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 5, 0, 0)
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = "FPS: -- | Ping: --"
    label.Parent = panel

    local RunService = game:GetService("RunService")
    local Stats = game:GetService("Stats")
    local elapsed, frames = 0, 0

    compactStatsConnection = RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        frames += 1
        if elapsed >= 0.5 then
            local fps = math.floor(frames / elapsed + 0.5)
            elapsed, frames = 0, 0
            local ping = "--"
            pcall(function()
                local item = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
                if item then ping = item:GetValueString():gsub(" ms", "") end
            end)
            if label and label.Parent then
                label.Text = "FPS: " .. fps .. " | Ping: " .. ping .. " ms"
            end
        end
    end)
end

EngineSettings:AddToggle({
    Name = 'Display FPS',
    Default = Bloxstrap.Config.DisplayFPS,
    Callback = function(call)
        Bloxstrap.UpdateConfig('DisplayFPS', call)
        if call then
            startCompactStats()
        else
            stopCompactStats()
            Bloxstrap.ToggleFFlag('FFlagDebugDisplayFPS', false)
        end
    end
})
]=]

local displayFPSCount
source, displayFPSCount = string.gsub(source, displayFPSStart, displayFPSReplacement, 1)
if displayFPSCount ~= 1 then
    error("Display FPS block not found; no replacement applied.")
end

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
