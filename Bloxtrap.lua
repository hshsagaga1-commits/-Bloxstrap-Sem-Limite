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
-- A interface só é examinada quando o usuário ativa o toggle.
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
    -- Não excluir todo nome com "emote": o botão de abrir emotes também deve diminuir.
    -- Protege somente o menu/roda aberta de emotes e a interface de chat.
    if name:find("chat", 1, true)
        or name:find("message", 1, true)
        or name:find("textbox", 1, true)
        or name:find("chatbar", 1, true)
        or name:find("textchat", 1, true)
        or name:find("quickchat", 1, true)
        or name:find("emotewheel", 1, true)
        or name:find("emote-wheel", 1, true)
        or name:find("emotemenu", 1, true)
        or name:find("emote_menu", 1, true)
        then return true end
    return name == "touchgui" or name == "emotesmenu"
        or name == "robloxmenu" or name == "chat"
        or name == "chatwindow" or name == "chatbar" or name == "chatinput"
        or name == "textchat" or name == "channelsbar" or name == "bubblechat"
end

local function isBackpackToggle(gui)
    return gui and gui:IsA("GuiButton")
        and string.lower(gui.Name):find("backpack", 1, true) ~= nil
end

local function isInventoryItem(gui)
    if not gui then return false end
    local function matches(value)
        value = string.lower(tostring(value or ""))
        -- Preserve inventory items and the contextual action shown while holding them.
        -- Item na mão e botão contextual de soltar/colocar ficam intactos.
        value = value:gsub("[%[%]%(%)_%-]", " ")
        return value:find("velocidade", 1, true) ~= nil
            or value == "cola"
            or value:find("cola ", 1, true) ~= nil
            or value:find(" colocar no chao", 1, true) ~= nil
            or value:find(" colocar no chão", 1, true) ~= nil
            or value:find("colocar no chao", 1, true) ~= nil
            or value:find("colocar no chão", 1, true) ~= nil
            or value:find("soltar", 1, true) ~= nil
            or value:find("drop", 1, true) ~= nil
    end
    if matches(gui.Name) then return true end
    if gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox") then
        local ok, value = pcall(function() return gui.Text end)
        if ok and matches(value) then return true end
    end
    return false
end

local function isExcluded(gui)
    local current = gui
    while current and current ~= lplr.PlayerGui do
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
    if size.X.Scale >= 0.90 and size.Y.Scale >= 0.90 then return true end
    local camera = workspace.CurrentCamera
    if camera then
        local viewport = camera.ViewportSize
        local absolute = gui.AbsoluteSize
        if viewport.X > 0 and viewport.Y > 0
            and absolute.X >= viewport.X * 0.90
            and absolute.Y >= viewport.Y * 0.90 then return true end
    end
    return false
end

local function applyToGroup(gui)
    if not gui:IsA("GuiObject") or isExcluded(gui) then return end
    local scaler = getDirectScale(gui)
    if scaler then
        scaler.Scale = activeScale
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
    -- Se houver um botão contextual protegido dentro do grupo, não escalar o grupo
    -- inteiro; assim o botão não some e os botões irmãos (ex.: salvar/carregar) continuam escaláveis.
    for _, descendant in ipairs(node:GetDescendants()) do
        if (nameIsExcluded(descendant.Name) and not isBackpackToggle(descendant))
            or isInventoryItem(descendant) then
            return true
        end
    end
    return false
end

local function scaleTree(node)
    if not node or isExcluded(node) then return end
    if node:IsA("ScreenGui") then
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("GuiObject") and not isExcluded(child) then scaleTree(child) end
        end
        return
    end
    if not node:IsA("GuiObject") then return end
    if isFullScreenContainer(node) then
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("GuiObject") and not isExcluded(child) then scaleTree(child) end
        end
        return
    end
    local children = directGuiChildren(node)
    local groupCandidate = #children >= 2 and not hasExcludedBranch(node)
    if groupCandidate or #children == 0 then
        applyToGroup(node)
        return
    end
    for _, child in ipairs(children) do scaleTree(child) end
end

local function applyScalePass()
    -- One synchronous pass only. No DescendantAdded/ChildAdded/respawn watchers.
    for _, gui in ipairs(lplr.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and not isExcluded(gui) then
            scaleTree(gui)
        end
    end
end

local guiscale = Appearance:AddToggle({
    Name = "GUIScaler",
    Description = "Reduz a interface apenas quando você ativa o toggle",
    Default = Bloxstrap.Config.GUIScale,
    Callback = function(call)
        Bloxstrap.UpdateConfig("GUIScale", call)
        if call then
            activeScale = nextScale(activeScale)
            applyScalePass()
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
