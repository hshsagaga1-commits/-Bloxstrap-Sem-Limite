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

-- Patch 1: GUIScaler Evade Overhaul V5: proportional whole-group scaling.
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

-- V5 / Evade Overhaul: whole-group scaling, NOT a separate Size edit per button.
-- A UIScale on a shared group shrinks buttons, text, icons, strokes and spacing.
-- For siblings without a shared compact frame, one geometric transform shrinks
-- their relative positions as a group. Never destroy UIListLayout or reparent.
local TAG="__BloxstrapUnlimitedGroupScale"
local MIN_SCALE=math.clamp(tonumber(getgenv().BloxstrapMinScale) or 0.01,0.01,1)
local currentScale=math.clamp(tonumber(getgenv().BloxstrapCurrentScale) or 0.30,MIN_SCALE,1)
local active=false
local pending=false
local updating=false
local groups={}
local signals={}
local statistics={rebuilds=0,native=0,virtual=0,buttons=0}

local PROTECT={
    pcjoystick=true,pcjump=true,dynamicthumbstickframe=true,
    thumbstickframe=true,touchthumbstick=true,jumpbutton=true,
    touchjump=true,jumpcontrol=true,joystick=true,thumbstick=true,
    ["perfectuimanager_ui"]=true,["perfectuimanager_shield"]=true,
    ["pckeyboardtouchbridgev52overlay"]=true
}
local HUD_HINTS={"hud","mobile","control","action","button","hotbar",
    "pov","whistle","apito","crouch","sprint","slide","dash",
    "interact","carry","equip","backpack"}
local PANEL_HINTS={"panel","window","popup","settings","shop","inventory",
    "mainmenu","emotemenu","emotewheel","dialog","modal"}

local function includesAny(name,tokens)
    for _,token in ipairs(tokens) do
        if string.find(name,token,1,true) then return true end
    end
    return false
end

local function excluded(node)
    local cursor=node
    while cursor and cursor~=lplr.PlayerGui do
        local name=string.lower(cursor.Name)
        if PROTECT[name] or includesAny(name,{"bloxstrap","delta",
            "perfectuimanager","pcmovement","executor","scriptui"}) then
            return true
        end
        cursor=cursor.Parent
    end
    return cursor~=lplr.PlayerGui
end

local function eligible(node)
    if not node or not node:IsA("GuiObject") or excluded(node) then
        return false
    end
    if not node.Visible then return false end
    if not node:IsA("GuiButton") then
        if not (node:IsA("Frame") or node:IsA("ImageLabel")) then return false end
        local lower=string.lower(node.Name)
        if not includesAny(lower,{"button","action","pov","whistle","apito"})
            or node:FindFirstChildWhichIsA("GuiButton",true) then
            return false
        end
    end
    local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        or Vector2.new(812,375)
    local size=node.AbsoluteSize
    if size.X<5 or size.Y<5 or size.X>viewport.X*.34
        or size.Y>viewport.Y*.36 then return false end
    local pos=node.AbsolutePosition
    local atEdge=pos.X<viewport.X*.24 or pos.X+size.X>viewport.X*.76
        or pos.Y<viewport.Y*.24 or pos.Y+size.Y>viewport.Y*.76
    local hint=false
    local ancestor=node
    while ancestor and ancestor~=lplr.PlayerGui do
        local name=string.lower(ancestor.Name)
        if includesAny(name,HUD_HINTS) then hint=true end
        if ancestor:IsA("GuiObject") then
            local s=ancestor.AbsoluteSize
            if includesAny(name,PANEL_HINTS) and s.X>viewport.X*.48
                and s.Y>viewport.Y*.36 then return false end
        end
        ancestor=ancestor.Parent
    end
    return atEdge or hint
end

local function boundsOf(objects)
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    for _,node in ipairs(objects) do
        local p,s=node.AbsolutePosition,node.AbsoluteSize
        minX=math.min(minX,p.X);minY=math.min(minY,p.Y)
        maxX=math.max(maxX,p.X+s.X);maxY=math.max(maxY,p.Y+s.Y)
    end
    return minX,minY,maxX,maxY
end

local function sharedScreen(node)
    local current=node
    while current and current~=lplr.PlayerGui do
        if current:IsA("ScreenGui") then return current end
        current=current.Parent
    end
    return nil
end

local function containsProtected(node)
    for _,child in ipairs(node:GetDescendants()) do
        if PROTECT[string.lower(child.Name)] then return true end
    end
    return false
end

local function compactRoot(root,members,viewport)
    if not root:IsA("GuiObject") or root:IsA("GuiButton")
        or root:IsA("ScrollingFrame") or containsProtected(root) then return false end
    if #members<2 or #members>8 then return false end
    local s=root.AbsoluteSize
    if s.X<8 or s.Y<8 or s.X>viewport.X*.50 or s.Y>viewport.Y*.52
        then return false end
    local x1,y1,x2,y2=boundsOf(members)
    if x2-x1>viewport.X*.47 or y2-y1>viewport.Y*.47 then return false end
    -- Reject screen-wide transparent wrappers and unrelated controls.
    if s.X>(x2-x1)+100 or s.Y>(y2-y1)+85 then return false end
    return true
end

local function collectButtons()
    local out={}
    for _,node in ipairs(lplr.PlayerGui:GetDescendants()) do
        if eligible(node) then out[#out+1]=node end
    end
    -- A wrapper and the button inside it must be one logical control.
    local filtered={}
    for _,node in ipairs(out) do
        local ancestor=node.Parent
        local insideAnother=false
        while ancestor and ancestor~=lplr.PlayerGui do
            if table.find(out,ancestor) then insideAnother=true break end
            ancestor=ancestor.Parent
        end
        if not insideAnother then filtered[#filtered+1]=node end
    end
    return filtered
end

local function makeScale(node)
    if not node or not node.Parent then return nil end
    local scaler=node:FindFirstChild(TAG)
    if not scaler or not scaler:IsA("UIScale") then
        scaler=Instance.new("UIScale")
        scaler.Name=TAG
        scaler.Scale=1
        scaler.Parent=node
    end
    return scaler
end

local function listen(connection)
    signals[#signals+1]=connection
end

local function clearGroups()
    updating=true
    for _,group in ipairs(groups) do
        for _,item in ipairs(group.items) do
            local node=item.node
            if node and node.Parent then
                -- Respect manual MoverBotoes positioning after this scaler.
                if item.shifted and node.Position==item.shifted then
                    node.Position=item.originalPosition
                end
                local scaler=node:FindFirstChild(TAG)
                if scaler and scaler:IsA("UIScale") then scaler:Destroy() end
            end
        end
    end
    table.clear(groups)
    updating=false
end

local function applyGroup(group)
    if not active then return end
    updating=true
    for _,item in ipairs(group.items) do
        local node=item.node
        if node and node.Parent then
            if item.kind=="shared" then
                local scale=makeScale(node)
                if scale then scale.Scale=currentScale end
            else
                local scale=makeScale(node)
                if scale then scale.Scale=currentScale end
                -- Transform the root anchors about ONE shared pivot, preserving
                -- the original group shape, order and relative gaps.
                local dx=(item.anchorX-group.pivotX)*(currentScale-1)
                local dy=(item.anchorY-group.pivotY)*(currentScale-1)
                local orig=item.originalPosition
                local target=UDim2.new(orig.X.Scale,orig.X.Offset+dx,
                    orig.Y.Scale,orig.Y.Offset+dy)
                local layout=node.Parent and (node.Parent:FindFirstChildWhichIsA("UIListLayout")
                    or node.Parent:FindFirstChildWhichIsA("UIGridStyleLayout")
                    or node.Parent:FindFirstChildWhichIsA("UITableLayout"))
                if not layout then
                    -- SetScale does not accumulate, always compute from original.
                    if not item.shifted or node.Position==item.shifted
                        or node.Position==item.originalPosition then
                        node.Position=target
                        item.shifted=target
                    end
                end
            end
        end
    end
    updating=false
end

local function newShared(root,members)
    return {name=root.Name,kind="shared",
        items={{node=root,kind="shared"}},buttons=#members,
        pivotX=0,pivotY=0}
end

local function newVirtual(members)
    local x1,y1,x2,y2=boundsOf(members)
    local group={name="cluster",kind="virtual",items={},buttons=#members,
        pivotX=(x1+x2)*.5,pivotY=(y1+y2)*.5}
    for _,node in ipairs(members) do
        local p,s=node.AbsolutePosition,node.AbsoluteSize
        group.items[#group.items+1]={
            node=node,kind="virtual",originalPosition=node.Position,
            anchorX=p.X+s.X*node.AnchorPoint.X,
            anchorY=p.Y+s.Y*node.AnchorPoint.Y
        }
    end
    return group
end

local function near(a,b,viewport)
    if sharedScreen(a)~=sharedScreen(b) then return false end
    local p1,s1=a.AbsolutePosition,a.AbsoluteSize
    local p2,s2=b.AbsolutePosition,b.AbsoluteSize
    local gapX=math.max(0,p1.X-(p2.X+s2.X),p2.X-(p1.X+s1.X))
    local gapY=math.max(0,p1.Y-(p2.Y+s2.Y),p2.Y-(p1.Y+s1.Y))
    return gapX<=math.min(35,viewport.X*.055)
        and gapY<=math.min(28,viewport.Y*.075)
end

local function build()
    if not active then return end
    clearGroups()
    local buttons=collectButtons()
    local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
        or Vector2.new(812,375)
    local counts={}
    -- Find the smallest real group containers first; prefer the highest
    -- compact ancestor containing the full cluster (POV/menu/whistle).
    for _,button in ipairs(buttons) do
        local parent=button.Parent
        while parent and parent~=lplr.PlayerGui do
            if parent:IsA("GuiObject") then
                local list=counts[parent]
                if not list then list={};counts[parent]=list end
                list[#list+1]=button
            end
            parent=parent.Parent
        end
    end
    local ordered={}
    for parent,members in pairs(counts) do
        if compactRoot(parent,members,viewport) then
            ordered[#ordered+1]={root=parent,members=members}
        end
    end
    table.sort(ordered,function(a,b)
        if #a.members~=#b.members then return #a.members>#b.members end
        local as,bs=a.root.AbsoluteSize,b.root.AbsoluteSize
        return (as.X*as.Y)>(bs.X*bs.Y)
    end)
    local covered={}
    local nativeCount=0
    local virtualCount=0
    for _,entry in ipairs(ordered) do
        local hasCovered=false
        for _,button in ipairs(entry.members) do
            if covered[button] then hasCovered=true break end
        end
        if not hasCovered then
            local group=newShared(entry.root,entry.members)
            groups[#groups+1]=group
            nativeCount+=1
            for _,button in ipairs(entry.members) do covered[button]=true end
        end
    end
    -- Fallback for same-screen siblings not inside one compact frame:
    -- scale each whole control AND its position relative to the same pivot.
    local remaining={}
    for _,button in ipairs(buttons) do
        if not covered[button] then remaining[#remaining+1]=button end
    end
    while #remaining>0 do
        local seed=table.remove(remaining,1)
        local component={seed}
        local changed=true
        while changed do
            changed=false
            for index=#remaining,1,-1 do
                local possible=remaining[index]
                local adjacent=false
                for _,member in ipairs(component) do
                    if near(member,possible,viewport) then adjacent=true break end
                end
                if adjacent then
                    component[#component+1]=table.remove(remaining,index)
                    changed=true
                end
            end
        end
        local x1,y1,x2,y2=boundsOf(component)
        if #component<=8 and x2-x1<=viewport.X*.52
            and y2-y1<=viewport.Y*.50 then
            groups[#groups+1]=newVirtual(component)
            virtualCount+=1
        else
            -- Do not merge unrelated full-screen clusters.
            for _,node in ipairs(component) do
                groups[#groups+1]=newVirtual({node})
                virtualCount+=1
            end
        end
    end
    for _,group in ipairs(groups) do applyGroup(group) end
    statistics.native=nativeCount
    statistics.virtual=virtualCount
    statistics.buttons=#buttons
    statistics.rebuilds+=1
end

local function scheduleBuild()
    if not active or pending then return end
    pending=true
    task.delay(.22,function()
        pending=false
        if active then build() end
    end)
end

local function stopScaler()
    active=false
    pending=false
    for _,connection in ipairs(signals) do pcall(function() connection:Disconnect() end) end
    table.clear(signals)
    clearGroups()
end

local previous=getgenv().__BloxstrapHUDScalerCleanup
if type(previous)=="function" then pcall(previous) end
getgenv().__BloxstrapHUDScalerCleanup=stopScaler
getgenv().BloxstrapCurrentScale=currentScale

local function startScaler()
    stopScaler()
    active=true
    build()
    -- Recreated interfaces / respawns trigger ONE deferred rebuild, not 60 scans/s.
    funnycon=lplr.PlayerGui.DescendantAdded:Connect(function(node)
        if node.Name~=TAG and not node:IsA("UIScale") then
            scheduleBuild()
        end
    end)
    listen(funnycon)
    funnyrootcon=lplr.PlayerGui.ChildAdded:Connect(scheduleBuild)
    listen(funnyrootcon)
end

getgenv().BloxstrapHUDScaler={
    GetScale=function() return currentScale end,
    GetState=function()
        return {enabled=active,scale=currentScale,groups=#groups,
            nativeGroups=statistics.native,virtualGroups=statistics.virtual,
            buttons=statistics.buttons,rebuilds=statistics.rebuilds}
    end,
    SetScale=function(value)
        value=tonumber(value)
        if not value then return false end
        currentScale=math.clamp(value,MIN_SCALE,1)
        getgenv().BloxstrapCurrentScale=currentScale
        if active then
            for _,group in ipairs(groups) do applyGroup(group) end
        end
        return true
    end,
    Rebuild=function() if active then build() end end
}

local guiscale=Appearance:AddToggle({
    Name="GUIScaler",
    Description="Reduz HUD em grupos completos: botoes, textos, icones e espacos juntos.",
    Default=Bloxstrap.Config.GUIScale,
    Callback=function(call)
        Bloxstrap.UpdateConfig("GUIScale",call)
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
