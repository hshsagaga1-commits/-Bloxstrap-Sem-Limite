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

local startMarker = "local funnycon\nlocal guisets = {}"
local endMarker = "local touchuuval = 1.2"

local startPos = string.find(source, startMarker, 1, true)
local endPos = startPos and string.find(source, endMarker, startPos, true)

if not startPos or not endPos then
    error("GUIScaler block not found. Bloxstrap was probably updated.")
end

local patched = [=[
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

source = string.sub(source, 1, startPos - 1)
    .. patched
    .. string.sub(source, endPos)

local chunk, err = loadstring(
    source,
    "Bloxstrap Unlimited GUI Scale"
)

if not chunk then
    error(err)
end

local Bloxstrap = chunk()

Bloxstrap.start()
Bloxstrap.Visible(not hidegui)
