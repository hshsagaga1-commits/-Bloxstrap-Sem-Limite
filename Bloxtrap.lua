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

-- O nivel final continua configuravel, mas nunca deixa a interface praticamente invisivel.
local MIN_SCALE = tonumber(getgenv().BloxstrapMinScale) or 0.05
MIN_SCALE = math.clamp(MIN_SCALE, 0.05, 1)

local function nextScale(current)
    -- Comeca diretamente no ultimo nivel de reducao, sem exigir
    -- varias ativacoes consecutivas do GUIScaler.
    return MIN_SCALE
end

-- Protect only the actual movement/jump controls, not all of TouchGui.
local protectedTouchNames = {
    pcjoystick = true,
    pcjump = true,
    dynamicthumbstickframe = true,
    thumbstickframe = true,
    touchthumbstick = true,
    jumpbutton = true,
    touchjump = true,

    -- Controles usados pelo script separado do Evade Legacy:
    -- protege estes botoes do GUIScaler sem executar nem alterar aquele script.
    ["emote button"] = true,
    ["auto crouch"] = true,
}

local function isProtectedTouchControl(node)
    return node and protectedTouchNames[string.lower(node.Name)] == true
end

local function containsProtectedTouchControl(node)
    for _, descendant in ipairs(node:GetDescendants()) do
        if isProtectedTouchControl(descendant) then
            return true
        end
    end
    return false
end

local function applyScaleToObject(node)
    if not node or isProtectedTouchControl(node) then
        return
    end

    local oldui = node:FindFirstChildWhichIsA("UIScale", true)
    if oldui then
        oldui.Scale = nextScale(oldui.Scale)
    else
        local uiscale = Instance.new("UIScale")
        uiscale.Name = "__BloxstrapUnlimitedScale"
        uiscale.Scale = MIN_SCALE
        uiscale.Parent = node
    end
end

local function scaleTouchGuiNode(node)
    if isProtectedTouchControl(node) then
        return
    end

    -- Never scale a container that owns the joystick/jump button.
    -- Walk through it and scale only the other sibling controls.
    if containsProtectedTouchControl(node) then
        for _, child in ipairs(node:GetChildren()) do
            scaleTouchGuiNode(child)
        end
        return
    end

    if node:IsA("GuiObject") then
        applyScaleToObject(node)
    else
        for _, child in ipairs(node:GetChildren()) do
            scaleTouchGuiNode(child)
        end
    end
end

local function scalePlayerGui(v)
    if not v then
        return
    end

    if v.Name == "TouchGui" then
        for _, child in ipairs(v:GetChildren()) do
            scaleTouchGuiNode(child)
        end
        return
    end

    -- PC Movement replaces Roblox's immutable native touch controls with
    -- custom controls inside this ScreenGui. Never attach UIScale to this
    -- parent: that would shrink BOTH PCJoystick and PCJump together.
    -- Keep this overlay at its own authored size; GUIScaler can scale other GUIs.
    local hasCustomMovementControls = false
    pcall(function()
        hasCustomMovementControls =
            v:FindFirstChild("PCJoystick", true) ~= nil
            or v:FindFirstChild("PCJump", true) ~= nil
    end)
    if v.Name == "PCKeyboardTouchBridgeV52Overlay" or hasCustomMovementControls then
        return
    end

    applyScaleToObject(v)
end

local function disconnectScaler()
    pcall(function()
        if funnycon then
            funnycon:Disconnect()
            funnycon = nil
        end
    end)
end

local function applyScalePass()
    for _, v in ipairs(lplr.PlayerGui:GetChildren()) do
        scalePlayerGui(v)
    end
end

local guiscale = Appearance:AddToggle({
    Name = "GUIScaler",
    Description = "Aplica diretamente a reducao final da UI.",
    Default = Bloxstrap.Config.GUIScale,
    Callback = function(call)
        Bloxstrap.UpdateConfig("GUIScale", call)

        if call then
            disconnectScaler()
            applyScalePass()

            funnycon = lplr.PlayerGui.ChildAdded:Connect(function(v)
                task.defer(function()
                    scalePlayerGui(v)
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
