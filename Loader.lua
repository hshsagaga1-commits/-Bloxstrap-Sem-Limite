local HttpService = game:GetService("HttpService")
local url = "https://raw.githubusercontent.com/hshsagaga1-commits/-Bloxstrap-Sem-Limite/main/Bloxtrap.lua"

local source = game:HttpGet(
    url .. "?_cb=" .. HttpService:GenerateGUID(false),
    true
)

-- Patch GUIScaler so it protects ONLY the actual movement controls instead of
-- excluding an entire ScreenGui/TouchGui area. This lets Legacy buttons keep
-- shrinking even when they share a GUI tree with mobile controls.
local scaleStartMarker = "local function scalePlayerGui(v)\n"
local scaleEndMarker = "local function disconnectScaler()"

local scaleStartPos = string.find(source, scaleStartMarker, 1, true)
local scaleEndPos = scaleStartPos and string.find(source, scaleEndMarker, scaleStartPos, true)

if not scaleStartPos or not scaleEndPos then
    error("Bloxstrap object-specific scaler patch failed: GUIScaler block not found")
end

local scaleReplacement = [=[
local PROTECTED_SCALE_CONTROLS = {
    PCJoystick = true,
    PCJump = true,
    DynamicThumbstickFrame = true,
    ThumbstickFrame = true,
    TouchThumbstick = true,
    JumpButton = true,
}

local function isProtectedScaleControl(v)
    local current = v

    while current and current ~= lplr.PlayerGui do
        if PROTECTED_SCALE_CONTROLS[current.Name] then
            return true
        end
        current = current.Parent
    end

    return false
end

local function containsProtectedScaleControl(v)
    if not v then
        return false
    end

    if PROTECTED_SCALE_CONTROLS[v.Name] then
        return true
    end

    for _, descendant in ipairs(v:GetDescendants()) do
        if PROTECTED_SCALE_CONTROLS[descendant.Name] then
            return true
        end
    end

    return false
end

local function removeBloxstrapScale(v)
    if not v then
        return
    end

    local old = v:FindFirstChild("__BloxstrapUnlimitedScale")
    if old and old:IsA("UIScale") then
        old:Destroy()
    end
end

local function scaleTarget(v, inheritedScale)
    if not v or isProtectedScaleControl(v) then
        removeBloxstrapScale(v)
        return
    end

    -- Only touch the scale created by this script. Do not recursively grab a
    -- UIScale owned by Evade/Roblox, because that can make unrelated buttons
    -- stop changing while GUIScaler appears to be working.
    local oldui = v:FindFirstChild("__BloxstrapUnlimitedScale")

    if oldui and oldui:IsA("UIScale") then
        oldui.Scale = nextScale(oldui.Scale)
    else
        local uiscale = Instance.new("UIScale")
        uiscale.Name = "__BloxstrapUnlimitedScale"

        if inheritedScale ~= nil then
            uiscale.Scale = nextScale(inheritedScale)
        else
            uiscale.Scale = 0.75
        end

        uiscale.Parent = v
    end
end

local function scaleBranch(v, inheritedScale)
    if not v then
        return
    end

    if isProtectedScaleControl(v) then
        removeBloxstrapScale(v)
        return
    end

    -- A safe GuiObject can be scaled as one subtree. If it contains joystick
    -- or jump, split the branch and scale only its non-protected children.
    if v:IsA("GuiObject") and not containsProtectedScaleControl(v) then
        scaleTarget(v, inheritedScale)
        return
    end

    for _, child in ipairs(v:GetChildren()) do
        if not child:IsA("UIScale") then
            scaleBranch(child, inheritedScale)
        end
    end
end

local function scalePlayerGui(v)
    if not v then
        return
    end

    -- Migrate an old whole-GUI Bloxstrap scale into the safe child branches.
    -- This is especially important for the old PCKeyboardTouchBridge overlay:
    -- its parent scale used to shrink joystick + jump together with everything.
    local inheritedScale
    local oldRootScale = v:FindFirstChild("__BloxstrapUnlimitedScale")

    if oldRootScale and oldRootScale:IsA("UIScale") then
        inheritedScale = oldRootScale.Scale
        oldRootScale:Destroy()
    end

    -- Remove any stale Bloxstrap scale that an older attempt may have put
    -- directly on joystick/jump. Nothing here uses screen coordinates/areas.
    if isProtectedScaleControl(v) then
        removeBloxstrapScale(v)
        return
    end

    for _, descendant in ipairs(v:GetDescendants()) do
        if PROTECTED_SCALE_CONTROLS[descendant.Name] then
            removeBloxstrapScale(descendant)
        end
    end

    scaleBranch(v, inheritedScale)
end

]=]

source = string.sub(source, 1, scaleStartPos - 1)
    .. scaleReplacement
    .. string.sub(source, scaleEndPos)

local chunk, err = loadstring(source)
if not chunk then
    error(err)
end

return chunk()
