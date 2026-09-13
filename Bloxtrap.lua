local RAW = "https://raw.githubusercontent.com/new-qwertyui/Bloxstrap/main/"
local API = "https://api.github.com/repos/new-qwertyui/Bloxstrap/contents/"
local hidegui = getgenv().hideui or false

local cloneref = cloneref or function(...)
    return ...
end

local HttpService = cloneref(game:GetService("HttpService"))

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
        local list = HttpService:JSONDecode(game:HttpGet(API .. "Main/Functions", true))

        for _, v in ipairs(list) do
            if v.name and v.name:find("%.lua$") then
                writefile(
                    "Bloxstrap/Main/Functions/" .. v.name,
                    "return loadstring(game:HttpGet('" .. RAW .. "Main/Functions/" .. v.name .. "', true))()"
                )
            end
        end
    end

    if not isfile("Bloxstrap/Main/Configs/Default.json") then
        writefile(
            "Bloxstrap/Main/Configs/Default.json",
            "{}"
        )
    end
end

installMissing()

local source =
    game:HttpGet(
        RAW .. "Main/Bloxstrap.lua",
        true
    )

local startMarker =
    "local funnycon\nlocal guisets = {}"

local endMarker =
    "local touchuuval = 1.2"

local startPos =
    string.find(
        source,
        startMarker,
        1,
        true
    )

local endPos =
    startPos
    and string.find(
        source,
        endMarker,
        startPos,
        true
    )

if not startPos or not endPos then
    error(
        "GUIScaler block not found. Bloxstrap was probably updated."
    )
end

local patched = [=[
local funnycon
local guisets = {}
local guisetmap = {}

local SCALE_STEP =
    tonumber(
        getgenv().BloxstrapScaleStep
    )
    or 0.70

if SCALE_STEP <= 0 then
    SCALE_STEP = 0.70
end

local function rememberScale(
    scaler,
    oldscale,
    created
)
    if not scaler
        or guisetmap[scaler]
    then
        return
    end

    guisetmap[scaler] = true

    table.insert(
        guisets,
        {
            oldscale = oldscale,
            scaler = scaler,
            created = created
        }
    )
end

local function scalePlayerGui(v)
    if not v
        or v.Name == "TouchGui"
    then
        return
    end

    local oldui =
        v:FindFirstChildWhichIsA(
            "UIScale",
            true
        )

    if oldui then
        rememberScale(
            oldui,
            oldui.Scale,
            false
        )

        oldui.Scale =
            oldui.Scale
            * SCALE_STEP
    else
        local uiscale =
            Instance.new("UIScale")

        uiscale.Scale =
            SCALE_STEP

        uiscale.Parent =
            v

        rememberScale(
            uiscale,
            9e9,
            true
        )
    end
end

local function restoreEverything()
    pcall(function()
        if funnycon then
            funnycon:Disconnect()
            funnycon = nil
        end
    end)

    for _, v in ipairs(guisets) do
        pcall(function()
            if v.scaler
                and v.scaler.Parent
            then
                if v.created
                    or v.oldscale == 9e9
                then
                    v.scaler:Destroy()
                else
                    v.scaler.Scale =
                        v.oldscale
                end
            end
        end)
    end

    table.clear(guisets)
    table.clear(guisetmap)
end

local guiscale =
    Appearance:AddToggle({
        Name = "GUIScaler",

        Description =
            "Decrease the roblox gui scales without a fixed lower limit",

        Default =
            Bloxstrap.Config.GUIScale,

        Callback = function(call)
            Bloxstrap.UpdateConfig(
                "GUIScale",
                call
            )

            if call then
                funnycon =
                    lplr.PlayerGui.ChildAdded:
                    Connect(function(v)
                        scalePlayerGui(v)
                    end)

                for _, v in ipairs(
                    lplr.PlayerGui:GetChildren()
                ) do
                    scalePlayerGui(v)
                end
            else
                restoreEverything()
            end
        end
    })

]=]

source =
    string.sub(
        source,
        1,
        startPos - 1
    )
    .. patched
    .. string.sub(
        source,
        endPos
    )

local chunk, err =
    loadstring(
        source,
        "Bloxstrap Unlimited GUI Scale"
    )

if not chunk then
    error(err)
end

local Bloxstrap =
    chunk()

Bloxstrap.start()
Bloxstrap.Visible(not hidegui)