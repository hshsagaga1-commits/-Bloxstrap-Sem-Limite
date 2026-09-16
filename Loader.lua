local HttpService = game:GetService("HttpService")
local url = "https://raw.githubusercontent.com/hshsagaga1-commits/-Bloxstrap-Sem-Limite/main/Bloxtrap.lua"

local source = game:HttpGet(
    url .. "?_cb=" .. HttpService:GenerateGUID(false),
    true
)

-- Keep the PC touch bridge controls out of GUIScaler. Everything else can keep
-- shrinking normally, but the joystick + jump overlay stays at Roblox-native size.
-- If an older Bloxstrap pass already added its scale to the overlay, remove it.
local scalerNeedle = [=[
local function scalePlayerGui(v)
    if not v or v.Name == "TouchGui" then
        return
    end
]=]

local scalerReplacement = [=[
local function scalePlayerGui(v)
    if not v then
        return
    end

    if v.Name == "TouchGui" or v.Name == "PCKeyboardTouchBridgeV52Overlay" then
        if v.Name == "PCKeyboardTouchBridgeV52Overlay" then
            local oldBridgeScale = v:FindFirstChild("__BloxstrapUnlimitedScale")
            if oldBridgeScale and oldBridgeScale:IsA("UIScale") then
                oldBridgeScale:Destroy()
            end
        end
        return
    end
]=]

local startPos, endPos = string.find(source, scalerNeedle, 1, true)
if not startPos then
    error("Bloxstrap joystick/jump exclusion patch failed: GUIScaler function marker not found")
end

if string.find(source, scalerNeedle, endPos + 1, true) then
    error("Bloxstrap joystick/jump exclusion patch failed: GUIScaler function marker was not unique")
end

source = string.sub(source, 1, startPos - 1)
    .. scalerReplacement
    .. string.sub(source, endPos + 1)

local chunk, err = loadstring(source)
if not chunk then
    error(err)
end

return chunk()
