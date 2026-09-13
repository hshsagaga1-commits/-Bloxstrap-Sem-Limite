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

-- Patch 1: GUIScaler sem limite em 0.50.
local scaleStartMarker = "local funnycon\nlocal guisets = {}"
local scaleEndMarker = "local touchuuval = 1.2"

local scaleStartPos = string.find(source, scaleStartMarker, 1, true)
local scaleEndPos = scaleStartPos and string.find(source, scaleEndMarker, scaleStartPos, true)

if not scaleStartPos or not scaleEndPos then
    error("GUIScaler block not found. Bloxstrap was probably updated.")
end

local scalePatched = [=[
local funnycon

local SCALE_STEP = tonumber(getgenv().BloxstrapScaleStep) or 0.25
local MIN_SCALE = tonumber(getgenv().BloxstrapMinScale) or 0.01

if SCALE_STEP <= 0 then
    SCALE_STEP = 0.25
end

if MIN_SCALE < 0 then
    MIN_SCALE = 0.01
end

local function nextScale(current)
    current = tonumber(current) or 1
    return math.max(MIN_SCALE, current - SCALE_STEP)
end

local function scalePlayerGui(v)
    if not v or v.Name == "TouchGui" then
        return
    end

    local oldui = v:FindFirstChildWhichIsA("UIScale", true)

    if oldui then
        oldui.Scale = nextScale(oldui.Scale)
    else
        local uiscale = Instance.new("UIScale")
        uiscale.Name = "__BloxstrapUnlimitedScale"
        uiscale.Scale = nextScale(1)
        uiscale.Parent = v
    end
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
    Description = "1.00 -> 0.75 -> 0.50 -> 0.25 -> almost zero; no 0.50 floor",
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
            -- Keep the reduced scale. Turning it ON again applies the next -0.25 step.
            disconnectScaler()
        end
    end
})

]=]

source = string.sub(source, 1, scaleStartPos - 1)
    .. scalePatched
    .. string.sub(source, scaleEndPos)

-- Patch 2: Crosshair mobile-safe. Mantem imagem customizada quando funcionar,
-- mas sempre mostra uma mira fallback e nao limita a primeira pessoa.
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
local fallbackH
local fallbackV

local guiParent = game:GetService("CoreGui")
pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)

local screengui = Instance.new("ScreenGui")
screengui.Name = "BloxstrapCrosshair"
screengui.IgnoreGuiInset = true
screengui.ResetOnSpawn = false
screengui.DisplayOrder = 999999
screengui.Enabled = false
screengui.Parent = guiParent

local function ensureCrosshair()
    if crosshairRoot and crosshairRoot.Parent then
        return
    end

    crosshairRoot = Instance.new("Frame")
    crosshairRoot.Name = "CrosshairRoot"
    crosshairRoot.AnchorPoint = Vector2.new(0.5, 0.5)
    crosshairRoot.Position = UDim2.new(0.5, 0, 0.5, 0)
    crosshairRoot.Size = UDim2.new(0, 19, 0, 19)
    crosshairRoot.BackgroundTransparency = 1
    crosshairRoot.ZIndex = 100
    crosshairRoot.Parent = screengui

    crosshairImage = Instance.new("ImageLabel")
    crosshairImage.Name = "CustomImage"
    crosshairImage.Size = UDim2.fromScale(1, 1)
    crosshairImage.BackgroundTransparency = 1
    crosshairImage.ZIndex = 102
    crosshairImage.Parent = crosshairRoot

    fallbackH = Instance.new("Frame")
    fallbackH.Name = "FallbackH"
    fallbackH.AnchorPoint = Vector2.new(0.5, 0.5)
    fallbackH.Position = UDim2.fromScale(0.5, 0.5)
    fallbackH.Size = UDim2.new(0, 13, 0, 2)
    fallbackH.BorderSizePixel = 0
    fallbackH.BackgroundColor3 = Color3.new(1, 1, 1)
    fallbackH.ZIndex = 101
    fallbackH.Parent = crosshairRoot

    fallbackV = Instance.new("Frame")
    fallbackV.Name = "FallbackV"
    fallbackV.AnchorPoint = Vector2.new(0.5, 0.5)
    fallbackV.Position = UDim2.fromScale(0.5, 0.5)
    fallbackV.Size = UDim2.new(0, 2, 0, 13)
    fallbackV.BorderSizePixel = 0
    fallbackV.BackgroundColor3 = Color3.new(1, 1, 1)
    fallbackV.ZIndex = 101
    fallbackV.Parent = crosshairRoot
end

local function refreshCrosshairVisual()
    ensureCrosshair()

    local hasImage = type(chosenimage) == "string" and chosenimage ~= ""
    crosshairImage.Image = hasImage and chosenimage or ""
    crosshairImage.Visible = hasImage
    fallbackH.Visible = not hasImage
    fallbackV.Visible = not hasImage
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
    Description = "Always-visible mobile-safe crosshair",
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
    "Bloxstrap Unlimited GUI Scale + Mobile Crosshair Fix"
)

if not chunk then
    error(err)
end

local Bloxstrap = chunk()

Bloxstrap.start()
Bloxstrap.Visible(not hidegui)
