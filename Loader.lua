local HttpService = game:GetService("HttpService")
local url = "https://raw.githubusercontent.com/hshsagaga1-commits/-Bloxstrap-Sem-Limite/main/Bloxtrap.lua"

local source = game:HttpGet(
    url .. "?_cb=" .. HttpService:GenerateGUID(false),
    true
)

-- Patch GUIScaler:
-- 1) protege joystick/pulo;
-- 2) nao escala containers de tela inteira (isso puxava tudo pro canto);
-- 3) escala cada bloco de UI no proprio lugar e corrige o centro depois da reducao.
local scaleStartMarker = "local function scalePlayerGui(v)\n"
local scaleEndMarker = "local function disconnectScaler()"

local scaleStartPos = string.find(source, scaleStartMarker, 1, true)
local scaleEndPos = scaleStartPos and string.find(source, scaleEndMarker, scaleStartPos, true)

if not scaleStartPos or not scaleEndPos then
    error("Bloxstrap in-place scaler patch failed: GUIScaler block not found")
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

local SCALE_NAME = "__BloxstrapUnlimitedScale"
local RunService = game:GetService("RunService")

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

local function getOwnBloxstrapScale(v)
    if not v then
        return nil
    end

    local scaler = v:FindFirstChild(SCALE_NAME)
    if scaler and scaler:IsA("UIScale") then
        return scaler
    end

    return nil
end

local function removeBloxstrapScale(v)
    local scaler = getOwnBloxstrapScale(v)
    if scaler then
        scaler:Destroy()
    end
end

local function hasLayoutController(parent)
    if not parent then
        return false
    end

    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("UIListLayout")
            or child:IsA("UIGridLayout")
            or child:IsA("UIPageLayout")
            or child:IsA("UITableLayout") then
            return true
        end
    end

    return false
end

-- Containers enormes sao so "mapas" de posicionamento.
-- Escalar eles faz qualquer elemento de 50%/100% da tela andar em direcao ao 0,0.
-- Entao atravessamos esses holders e escalamos os blocos menores por baixo deles.
local function isPlacementContainer(v)
    if not v or not v:IsA("GuiObject") then
        return true
    end

    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(0, 0)
    local size = v.AbsoluteSize

    if viewport.X > 0 and viewport.Y > 0 then
        if size.X >= viewport.X * 0.78 or size.Y >= viewport.Y * 0.78 then
            return true
        end
    end

    local sx = math.abs(v.Size.X.Scale)
    local sy = math.abs(v.Size.Y.Scale)

    if sx >= 0.85 or sy >= 0.85 then
        return true
    end

    return false
end

local function preserveVisualCenter(v, beforeCenter)
    if not v or not v.Parent or not v:IsA("GuiObject") then
        return
    end

    -- Layouts controlam Position; mexer nela faria brigar com o proprio layout.
    if hasLayoutController(v.Parent) then
        return
    end

    task.defer(function()
        pcall(function()
            RunService.RenderStepped:Wait()

            if not v or not v.Parent then
                return
            end

            local afterPos = v.AbsolutePosition
            local afterSize = v.AbsoluteSize
            local afterCenter = afterPos + (afterSize / 2)
            local delta = beforeCenter - afterCenter

            -- Corrige so o deslocamento criado pela escala.
            if math.abs(delta.X) > 0.25 or math.abs(delta.Y) > 0.25 then
                local p = v.Position
                v.Position = UDim2.new(
                    p.X.Scale,
                    p.X.Offset + delta.X,
                    p.Y.Scale,
                    p.Y.Offset + delta.Y
                )
            end
        end)
    end)
end

local function scaleTarget(v, inheritedScale)
    if not v or not v:IsA("GuiObject") or isProtectedScaleControl(v) then
        removeBloxstrapScale(v)
        return
    end

    local beforePos = v.AbsolutePosition
    local beforeSize = v.AbsoluteSize
    local beforeCenter = beforePos + (beforeSize / 2)

    local oldui = getOwnBloxstrapScale(v)

    if oldui then
        oldui.Scale = nextScale(oldui.Scale)
    else
        local uiscale = Instance.new("UIScale")
        uiscale.Name = SCALE_NAME

        if inheritedScale ~= nil then
            uiscale.Scale = nextScale(inheritedScale)
        else
            uiscale.Scale = 0.75
        end

        uiscale.Parent = v
    end

    preserveVisualCenter(v, beforeCenter)
end

local function scaleBranch(v, inheritedScale)
    if not v then
        return
    end

    if isProtectedScaleControl(v) then
        removeBloxstrapScale(v)
        return
    end

    local mustSplit = not v:IsA("GuiObject")
        or isPlacementContainer(v)
        or containsProtectedScaleControl(v)

    if mustSplit then
        local childInheritedScale = inheritedScale
        local ownScale = getOwnBloxstrapScale(v)

        -- Migra qualquer escala antiga aplicada no holder inteiro para os filhos.
        -- Assim a UI nao "teleporta" de volta ao tamanho 1 antes do proximo passo.
        if ownScale then
            childInheritedScale = ownScale.Scale
            ownScale:Destroy()
        end

        for _, child in ipairs(v:GetChildren()) do
            if not child:IsA("UIScale") then
                scaleBranch(child, childInheritedScale)
            end
        end

        return
    end

    scaleTarget(v, inheritedScale)
end

local function scalePlayerGui(v)
    if not v then
        return
    end

    -- Remove qualquer scaler velho colocado diretamente no joystick/pulo.
    for _, descendant in ipairs(v:GetDescendants()) do
        if PROTECTED_SCALE_CONTROLS[descendant.Name] then
            removeBloxstrapScale(descendant)
        end
    end

    scaleBranch(v, nil)
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
