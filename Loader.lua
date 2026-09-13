local HttpService = game:GetService("HttpService")

local scripts = {
    "https://raw.githubusercontent.com/hshsagaga1-commits/-Bloxstrap-Sem-Limite/main/Bloxtrap.lua",
    "https://raw.githubusercontent.com/hshsagaga1-commits/-Nova-CoreUIi/main/CoreUI.lua",
}

local function runNoCache(url)
    local separator = string.find(url, "?", 1, true) and "&" or "?"
    local cacheBust = HttpService:GenerateGUID(false)
    local source = game:HttpGet(url .. separator .. "_cb=" .. cacheBust, true)

    local chunk, err = loadstring(source)
    if not chunk then
        error(err)
    end

    return chunk()
end

for _, url in ipairs(scripts) do
    runNoCache(url)
end
