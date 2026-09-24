--[[
    Light Hop
    - Ordena por menor ping / menos players / mais players
    - Mostra Ping + FPS
    - Tema amarelo limpo e moderno
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end
local PlaceId = game.PlaceId
local JobId = game.JobId

local MAX_SERVERS = 50
local REQUEST_DELAY = 0.4

local THEME = {
    Background = Color3.fromRGB(18, 18, 22),
    Secondary = Color3.fromRGB(28, 28, 34),
    Accent = Color3.fromRGB(255, 190, 40),
    AccentHover = Color3.fromRGB(255, 210, 70),
    Text = Color3.fromRGB(245, 245, 245),
    TextDim = Color3.fromRGB(170, 170, 180),
    Border = Color3.fromRGB(50, 50, 58),
    GoodPing = Color3.fromRGB(80, 220, 120),
    MediumPing = Color3.fromRGB(255, 190, 40),
    BadPing = Color3.fromRGB(230, 80, 80),
    TitleYellow = Color3.fromRGB(255, 200, 50),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LightHop"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local function getGuiParent()
    local okHui, hui = pcall(function()
        return gethui and gethui()
    end)
    if okHui and hui then
        return hui
    end

    local okCore = pcall(function()
        return game:GetService("CoreGui"):GetChildren()
    end)
    if okCore then
        return game:GetService("CoreGui")
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

ScreenGui.Parent = getGuiParent()

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Light Hop",
        Text = "Script carregado!",
        Duration = 4
    })
end)

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 420, 0, 520)
Main.Position = UDim2.new(0.5, -210, 0.5, -260)
Main.BackgroundColor3 = THEME.Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = Main

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = THEME.Border
UIStroke.Thickness = 1
UIStroke.Parent = Main

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = THEME.Secondary
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = TitleBar

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 16)
TitleFix.Position = UDim2.new(0, 0, 1, -16)
TitleFix.BackgroundColor3 = THEME.Secondary
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Light Hop"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 17
Title.TextColor3 = THEME.TitleYellow
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -16)
CloseBtn.BackgroundColor3 = Color3.fromRGB(55, 35, 35)
CloseBtn.Text = "Ã—"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 20
CloseBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local SortFrame = Instance.new("Frame")
SortFrame.Size = UDim2.new(1, -24, 0, 34)
SortFrame.Position = UDim2.new(0, 12, 0, 54)
SortFrame.BackgroundTransparency = 1
SortFrame.Parent = Main

local function createSortButton(text, position)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.32, 0, 1, 0)
    btn.Position = position
    btn.BackgroundColor3 = THEME.Secondary
    btn.Text = text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextColor3 = THEME.TextDim
    btn.Parent = SortFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    return btn
end

local BtnPing = createSortButton("Menor Ping", UDim2.new(0, 0, 0, 0))
local BtnLow = createSortButton("Menos Players", UDim2.new(0.34, 0, 0, 0))
local BtnHigh = createSortButton("Mais Players", UDim2.new(0.68, 0, 0, 0))

local currentSort = "ping"

local function setActive(btn)
    for _, b in pairs({BtnPing, BtnLow, BtnHigh}) do
        b.BackgroundColor3 = THEME.Secondary
        b.TextColor3 = THEME.TextDim
    end
    btn.BackgroundColor3 = THEME.Accent
    btn.TextColor3 = Color3.fromRGB(20, 20, 20)
end

setActive(BtnPing)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -100, 0, 22)
StatusLabel.Position = UDim2.new(0, 12, 0, 96)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Pronto"
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextColor3 = THEME.TextDim
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 80, 0, 26)
RefreshBtn.Position = UDim2.new(1, -92, 0, 94)
RefreshBtn.BackgroundColor3 = THEME.Secondary
RefreshBtn.Text = "Refresh"
RefreshBtn.Font = Enum.Font.GothamMedium
RefreshBtn.TextSize = 12
RefreshBtn.TextColor3 = THEME.Text
RefreshBtn.Parent = Main

local RefreshCorner = Instance.new("UICorner")
RefreshCorner.CornerRadius = UDim.new(0, 6)
RefreshCorner.Parent = RefreshBtn

local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Size = UDim2.new(1, -24, 1, -180)
ListFrame.Position = UDim2.new(0, 12, 0, 128)
ListFrame.BackgroundColor3 = THEME.Secondary
ListFrame.BorderSizePixel = 0
ListFrame.ScrollBarThickness = 4
ListFrame.ScrollBarImageColor3 = THEME.Accent
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.Parent = Main

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 8)
ListCorner.Parent = ListFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 6)
ListLayout.Parent = ListFrame

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 8)
ListPadding.PaddingBottom = UDim.new(0, 8)
ListPadding.PaddingLeft = UDim.new(0, 8)
ListPadding.PaddingRight = UDim.new(0, 8)
ListPadding.Parent = ListFrame

local AutoHopBtn = Instance.new("TextButton")
AutoHopBtn.Size = UDim2.new(1, -24, 0, 36)
AutoHopBtn.Position = UDim2.new(0, 12, 1, -48)
AutoHopBtn.BackgroundColor3 = THEME.Accent
AutoHopBtn.Text = "Auto Hop (Melhor Ping)"
AutoHopBtn.Font = Enum.Font.GothamBold
AutoHopBtn.TextSize = 14
AutoHopBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
AutoHopBtn.Parent = Main

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 8)
AutoCorner.Parent = AutoHopBtn

local serversCache = {}
local isLoading = false

local function getPingColor(ping)
    if ping <= 80 then return THEME.GoodPing
    elseif ping <= 140 then return THEME.MediumPing
    else return THEME.BadPing
    end
end

local function clearList()
    for _, child in pairs(ListFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function createServerEntry(index, server)
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1, 0, 0, 52)
    entry.BackgroundColor3 = THEME.Background
    entry.BorderSizePixel = 0
    entry.LayoutOrder = index
    entry.Parent = ListFrame

    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 8)
    entryCorner.Parent = entry

    local num = Instance.new("TextLabel")
    num.Size = UDim2.new(0, 28, 1, 0)
    num.Position = UDim2.new(0, 8, 0, 0)
    num.BackgroundTransparency = 1
    num.Text = tostring(index)
    num.Font = Enum.Font.GothamBold
    num.TextSize = 14
    num.TextColor3 = THEME.TextDim
    num.Parent = entry

    local players = Instance.new("TextLabel")
    players.Size = UDim2.new(0, 70, 0, 20)
    players.Position = UDim2.new(0, 40, 0, 6)
    players.BackgroundTransparency = 1
    players.Text = server.playing .. "/" .. server.maxPlayers
    players.Font = Enum.Font.GothamMedium
    players.TextSize = 13
    players.TextColor3 = THEME.Text
    players.TextXAlignment = Enum.TextXAlignment.Left
    players.Parent = entry

    local ping = Instance.new("TextLabel")
    ping.Size = UDim2.new(0, 80, 0, 20)
    ping.Position = UDim2.new(0, 40, 0, 26)
    ping.BackgroundTransparency = 1
    ping.Text = "Ping: " .. (server.ping or "?")
    ping.Font = Enum.Font.Gotham
    ping.TextSize = 12
    ping.TextColor3 = getPingColor(server.ping or 999)
    ping.TextXAlignment = Enum.TextXAlignment.Left
    ping.Parent = entry

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(0, 120, 0, 40)
    info.Position = UDim2.new(0, 140, 0, 6)
    info.BackgroundTransparency = 1
    info.Text = "FPS: " .. math.floor(server.fps or 0) .. "\nRegiÃ£o: Unknown"
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextColor3 = THEME.TextDim
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.Parent = entry

    local join = Instance.new("TextButton")
    join.Size = UDim2.new(0, 70, 0, 32)
    join.Position = UDim2.new(1, -82, 0.5, -16)
    join.BackgroundColor3 = THEME.Accent
    join.Text = "Join"
    join.Font = Enum.Font.GothamBold
    join.TextSize = 13
    join.TextColor3 = Color3.fromRGB(20, 20, 20)
    join.Parent = entry

    local joinCorner = Instance.new("UICorner")
    joinCorner.CornerRadius = UDim.new(0, 6)
    joinCorner.Parent = join

    join.MouseEnter:Connect(function()
        join.BackgroundColor3 = THEME.AccentHover
    end)
    join.MouseLeave:Connect(function()
        join.BackgroundColor3 = THEME.Accent
    end)

    join.MouseButton1Click:Connect(function()
        StatusLabel.Text = "Teleportando..."
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
        end)
    end)
end

local function httpGet(url)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local ok, res = pcall(function()
            return req({Url = url, Method = "GET"})
        end)
        if ok and res and res.Body then
            return res.Body
        end
    end
    return game:HttpGet(url)
end

local function fetchServers()
    if isLoading then return end
    isLoading = true
    StatusLabel.Text = "Carregando servidores..."
    clearList()
    serversCache = {}

    local cursor = ""
    local loaded = 0

    while loaded < MAX_SERVERS do
        local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end

        local success, result = pcall(function()
            return HttpService:JSONDecode(httpGet(url))
        end)

        if not success or not result or not result.data then
            StatusLabel.Text = "Erro ao carregar. Tente novamente."
            isLoading = false
            return
        end

        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.id ~= JobId then
                table.insert(serversCache, {
                    id = server.id,
                    playing = server.playing or 0,
                    maxPlayers = server.maxPlayers or 0,
                    ping = server.ping or 999,
                    fps = server.fps or 0
                })
                loaded = loaded + 1
                if loaded >= MAX_SERVERS then break end
            end
        end

        cursor = result.nextPageCursor
        if not cursor or cursor == "" then break end
        task.wait(REQUEST_DELAY)
    end

    if currentSort == "ping" then
        table.sort(serversCache, function(a, b) return a.ping < b.ping end)
    elseif currentSort == "low" then
        table.sort(serversCache, function(a, b) return a.playing < b.playing end)
    else
        table.sort(serversCache, function(a, b) return a.playing > b.playing end)
    end

    for i, server in ipairs(serversCache) do
        createServerEntry(i, server)
    end

    ListFrame.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 16)
    StatusLabel.Text = "Carregados " .. #serversCache .. " servidores"
    isLoading = false
end

BtnPing.MouseButton1Click:Connect(function()
    currentSort = "ping"
    setActive(BtnPing)
    fetchServers()
end)

BtnLow.MouseButton1Click:Connect(function()
    currentSort = "low"
    setActive(BtnLow)
    fetchServers()
end)

BtnHigh.MouseButton1Click:Connect(function()
    currentSort = "high"
    setActive(BtnHigh)
    fetchServers()
end)

RefreshBtn.MouseButton1Click:Connect(fetchServers)

AutoHopBtn.MouseButton1Click:Connect(function()
    if #serversCache == 0 then
        StatusLabel.Text = "Carregue os servidores primeiro"
        return
    end

    local best = serversCache[1]
    if currentSort ~= "ping" then
        table.sort(serversCache, function(a, b) return a.ping < b.ping end)
        best = serversCache[1]
    end

    StatusLabel.Text = "Auto Hop â†’ Ping " .. best.ping
    pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, best.id, LocalPlayer)
    end)
end)

local dragging, dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

fetchServers()    btn.TextSize = 13
    btn.TextColor3 = THEME.TextDim
    btn.Parent = SortFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    return btn
end

local BtnPing = createSortButton("Menor Ping", UDim2.new(0, 0, 0, 0))
local BtnLow = createSortButton("Menos Players", UDim2.new(0.34, 0, 0, 0))
local BtnHigh = createSortButton("Mais Players", UDim2.new(0.68, 0, 0, 0))

local currentSort = "ping"

local function setActive(btn)
    for _, b in pairs({BtnPing, BtnLow, BtnHigh}) do
        b.BackgroundColor3 = THEME.Secondary
        b.TextColor3 = THEME.TextDim
    end
    btn.BackgroundColor3 = THEME.Accent
    btn.TextColor3 = Color3.fromRGB(20, 20, 20)
end

setActive(BtnPing)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -100, 0, 22)
StatusLabel.Position = UDim2.new(0, 12, 0, 96)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Pronto"
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextColor3 = THEME.TextDim
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 80, 0, 26)
RefreshBtn.Position = UDim2.new(1, -92, 0, 94)
RefreshBtn.BackgroundColor3 = THEME.Secondary
RefreshBtn.Text = "Refresh"
RefreshBtn.Font = Enum.Font.GothamMedium
RefreshBtn.TextSize = 12
RefreshBtn.TextColor3 = THEME.Text
RefreshBtn.Parent = Main

local RefreshCorner = Instance.new("UICorner")
RefreshCorner.CornerRadius = UDim.new(0, 6)
RefreshCorner.Parent = RefreshBtn

local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Size = UDim2.new(1, -24, 1, -180)
ListFrame.Position = UDim2.new(0, 12, 0, 128)
ListFrame.BackgroundColor3 = THEME.Secondary
ListFrame.BorderSizePixel = 0
ListFrame.ScrollBarThickness = 4
ListFrame.ScrollBarImageColor3 = THEME.Accent
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.Parent = Main

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 8)
ListCorner.Parent = ListFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 6)
ListLayout.Parent = ListFrame

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 8)
ListPadding.PaddingBottom = UDim.new(0, 8)
ListPadding.PaddingLeft = UDim.new(0, 8)
ListPadding.PaddingRight = UDim.new(0, 8)
ListPadding.Parent = ListFrame

local AutoHopBtn = Instance.new("TextButton")
AutoHopBtn.Size = UDim2.new(1, -24, 0, 36)
AutoHopBtn.Position = UDim2.new(0, 12, 1, -48)
AutoHopBtn.BackgroundColor3 = THEME.Accent
AutoHopBtn.Text = "Auto Hop (Melhor Ping)"
AutoHopBtn.Font = Enum.Font.GothamBold
AutoHopBtn.TextSize = 14
AutoHopBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
AutoHopBtn.Parent = Main

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 8)
AutoCorner.Parent = AutoHopBtn

local serversCache = {}
local isLoading = false

local function getPingColor(ping)
    if ping <= 80 then return THEME.GoodPing
    elseif ping <= 140 then return THEME.MediumPing
    else return THEME.BadPing
    end
end

local function clearList()
    for _, child in pairs(ListFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function createServerEntry(index, server)
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1, 0, 0, 52)
    entry.BackgroundColor3 = THEME.Background
    entry.BorderSizePixel = 0
    entry.LayoutOrder = index
    entry.Parent = ListFrame

    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 8)
    entryCorner.Parent = entry

    local num = Instance.new("TextLabel")
    num.Size = UDim2.new(0, 28, 1, 0)
    num.Position = UDim2.new(0, 8, 0, 0)
    num.BackgroundTransparency = 1
    num.Text = tostring(index)
    num.Font = Enum.Font.GothamBold
    num.TextSize = 14
    num.TextColor3 = THEME.TextDim
    num.Parent = entry

    local players = Instance.new("TextLabel")
    players.Size = UDim2.new(0, 70, 0, 20)
    players.Position = UDim2.new(0, 40, 0, 6)
    players.BackgroundTransparency = 1
    players.Text = server.playing .. "/" .. server.maxPlayers
    players.Font = Enum.Font.GothamMedium
    players.TextSize = 13
    players.TextColor3 = THEME.Text
    players.TextXAlignment = Enum.TextXAlignment.Left
    players.Parent = entry

    local ping = Instance.new("TextLabel")
    ping.Size = UDim2.new(0, 80, 0, 20)
    ping.Position = UDim2.new(0, 40, 0, 26)
    ping.BackgroundTransparency = 1
    ping.Text = "Ping: " .. (server.ping or "?")
    ping.Font = Enum.Font.Gotham
    ping.TextSize = 12
    ping.TextColor3 = getPingColor(server.ping or 999)
    ping.TextXAlignment = Enum.TextXAlignment.Left
    ping.Parent = entry

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(0, 120, 0, 40)
    info.Position = UDim2.new(0, 140, 0, 6)
    info.BackgroundTransparency = 1
    info.Text = "FPS: " .. math.floor(server.fps or 0) .. "\nRegiÃ£o: Unknown"
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextColor3 = THEME.TextDim
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.Parent = entry

    local join = Instance.new("TextButton")
    join.Size = UDim2.new(0, 70, 0, 32)
    join.Position = UDim2.new(1, -82, 0.5, -16)
    join.BackgroundColor3 = THEME.Accent
    join.Text = "Join"
    join.Font = Enum.Font.GothamBold
    join.TextSize = 13
    join.TextColor3 = Color3.fromRGB(20, 20, 20)
    join.Parent = entry

    local joinCorner = Instance.new("UICorner")
    joinCorner.CornerRadius = UDim.new(0, 6)
    joinCorner.Parent = join

    join.MouseEnter:Connect(function()
        join.BackgroundColor3 = THEME.AccentHover
    end)
    join.MouseLeave:Connect(function()
        join.BackgroundColor3 = THEME.Accent
    end)

    join.MouseButton1Click:Connect(function()
        StatusLabel.Text = "Teleportando..."
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
        end)
    end)
end

local function fetchServers()
    if isLoading then return end
    isLoading = true
    StatusLabel.Text = "Carregando servidores..."
    clearList()
    serversCache = {}

    local cursor = ""
    local loaded = 0

    while loaded < MAX_SERVERS do
        local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end

        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if not success or not result or not result.data then
            StatusLabel.Text = "Erro ao carregar. Tente novamente."
            isLoading = false
            return
        end

        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.id ~= JobId then
                table.insert(serversCache, {
                    id = server.id,
                    playing = server.playing or 0,
                    maxPlayers = server.maxPlayers or 0,
                    ping = server.ping or 999,
                    fps = server.fps or 0
                })
                loaded = loaded + 1
                if loaded >= MAX_SERVERS then break end
            end
        end

        cursor = result.nextPageCursor
        if not cursor or cursor == "" then break end
        task.wait(REQUEST_DELAY)
    end

    if currentSort == "ping" then
        table.sort(serversCache, function(a, b) return a.ping < b.ping end)
    elseif currentSort == "low" then
        table.sort(serversCache, function(a, b) return a.playing < b.playing end)
    else
        table.sort(serversCache, function(a, b) return a.playing > b.playing end)
    end

    for i, server in ipairs(serversCache) do
        createServerEntry(i, server)
    end

    ListFrame.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 16)
    StatusLabel.Text = "Carregados " .. #serversCache .. " servidores"
    isLoading = false
end

BtnPing.MouseButton1Click:Connect(function()
    currentSort = "ping"
    setActive(BtnPing)
    fetchServers()
end)

BtnLow.MouseButton1Click:Connect(function()
    currentSort = "low"
    setActive(BtnLow)
    fetchServers()
end)

BtnHigh.MouseButton1Click:Connect(function()
    currentSort = "high"
    setActive(BtnHigh)
    fetchServers()
end)

RefreshBtn.MouseButton1Click:Connect(fetchServers)

AutoHopBtn.MouseButton1Click:Connect(function()
    if #serversCache == 0 then
        StatusLabel.Text = "Carregue os servidores primeiro"
        return
    end

    local best = serversCache[1]
    if currentSort ~= "ping" then
        table.sort(serversCache, function(a, b) return a.ping < b.ping end)
        best = serversCache[1]
    end

    StatusLabel.Text = "Auto Hop â†’ Ping " .. best.ping
    pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, best.id, LocalPlayer)
    end)
end)

local dragging, dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

fetchServers()SortFrame.Parent = Main

local function createSortButton(text, position)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.32, 0, 1, 0)
    btn.Position = position
    btn.BackgroundColor3 = THEME.Secondary
    btn.Text = text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextColor3 = THEME.TextDim
    btn.Parent = SortFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    return btn
end

local BtnPing = createSortButton("Menor Ping", UDim2.new(0, 0, 0, 0))
local BtnLow = createSortButton("Menos Players", UDim2.new(0.34, 0, 0, 0))
local BtnHigh = createSortButton("Mais Players", UDim2.new(0.68, 0, 0, 0))

local currentSort = "ping"

local function setActive(btn)
    for _, b in pairs({BtnPing, BtnLow, BtnHigh}) do
        b.BackgroundColor3 = THEME.Secondary
        b.TextColor3 = THEME.TextDim
    end
    btn.BackgroundColor3 = THEME.Accent
    btn.TextColor3 = Color3.fromRGB(20, 20, 20)
end

setActive(BtnPing)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -100, 0, 22)
StatusLabel.Position = UDim2.new(0, 12, 0, 96)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Pronto"
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextColor3 = THEME.TextDim
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 80, 0, 26)
RefreshBtn.Position = UDim2.new(1, -92, 0, 94)
RefreshBtn.BackgroundColor3 = THEME.Secondary
RefreshBtn.Text = "Refresh"
RefreshBtn.Font = Enum.Font.GothamMedium
RefreshBtn.TextSize = 12
RefreshBtn.TextColor3 = THEME.Text
RefreshBtn.Parent = Main

local RefreshCorner = Instance.new("UICorner")
RefreshCorner.CornerRadius = UDim.new(0, 6)
RefreshCorner.Parent = RefreshBtn

local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Size = UDim2.new(1, -24, 1, -180)
ListFrame.Position = UDim2.new(0, 12, 0, 128)
ListFrame.BackgroundColor3 = THEME.Secondary
ListFrame.BorderSizePixel = 0
ListFrame.ScrollBarThickness = 4
ListFrame.ScrollBarImageColor3 = THEME.Accent
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.Parent = Main

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 8)
ListCorner.Parent = ListFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 6)
ListLayout.Parent = ListFrame

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 8)
ListPadding.PaddingBottom = UDim.new(0, 8)
ListPadding.PaddingLeft = UDim.new(0, 8)
ListPadding.PaddingRight = UDim.new(0, 8)
ListPadding.Parent = ListFrame

local AutoHopBtn = Instance.new("TextButton")
AutoHopBtn.Size = UDim2.new(1, -24, 0, 36)
AutoHopBtn.Position = UDim2.new(0, 12, 1, -48)
AutoHopBtn.BackgroundColor3 = THEME.Accent
AutoHopBtn.Text = "Auto Hop (Melhor Ping)"
AutoHopBtn.Font = Enum.Font.GothamBold
AutoHopBtn.TextSize = 14
AutoHopBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
AutoHopBtn.Parent = Main

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 8)
AutoCorner.Parent = AutoHopBtn

local serversCache = {}
local isLoading = false

local function getPingColor(ping)
    if ping <= 80 then return THEME.GoodPing
    elseif ping <= 140 then return THEME.MediumPing
    else return THEME.BadPing
    end
end

local function clearList()
    for _, child in pairs(ListFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function createServerEntry(index, server)
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1, 0, 0, 52)
    entry.BackgroundColor3 = THEME.Background
    entry.BorderSizePixel = 0
    entry.LayoutOrder = index
    entry.Parent = ListFrame

    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 8)
    entryCorner.Parent = entry

    local num = Instance.new("TextLabel")
    num.Size = UDim2.new(0, 28, 1, 0)
    num.Position = UDim2.new(0, 8, 0, 0)
    num.BackgroundTransparency = 1
    num.Text = tostring(index)
    num.Font = Enum.Font.GothamBold
    num.TextSize = 14
    num.TextColor3 = THEME.TextDim
    num.Parent = entry

    local players = Instance.new("TextLabel")
    players.Size = UDim2.new(0, 70, 0, 20)
    players.Position = UDim2.new(0, 40, 0, 6)
    players.BackgroundTransparency = 1
    players.Text = server.playing .. "/" .. server.maxPlayers
    players.Font = Enum.Font.GothamMedium
    players.TextSize = 13
    players.TextColor3 = THEME.Text
    players.TextXAlignment = Enum.TextXAlignment.Left
    players.Parent = entry

    local ping = Instance.new("TextLabel")
    ping.Size = UDim2.new(0, 80, 0, 20)
    ping.Position = UDim2.new(0, 40, 0, 26)
    ping.BackgroundTransparency = 1
    ping.Text = "Ping: " .. (server.ping or "?")
    ping.Font = Enum.Font.Gotham
    ping.TextSize = 12
    ping.TextColor3 = getPingColor(server.ping or 999)
    ping.TextXAlignment = Enum.TextXAlignment.Left
    ping.Parent = entry

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(0, 120, 0, 40)
    info.Position = UDim2.new(0, 140, 0, 6)
    info.BackgroundTransparency = 1
    info.Text = "FPS: " .. math.floor(server.fps or 0) .. "\nRegião: Unknown"
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextColor3 = THEME.TextDim
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.Parent = entry

    local join = Instance.new("TextButton")
    join.Size = UDim2.new(0, 70, 0, 32)
    join.Position = UDim2.new(1, -82, 0.5, -16)
    join.BackgroundColor3 = THEME.Accent
    join.Text = "Join"
    join.Font = Enum.Font.GothamBold
    join.TextSize = 13
    join.TextColor3 = Color3.fromRGB(20, 20, 20)
    join.Parent = entry

    local joinCorner = Instance.new("UICorner")
    joinCorner.CornerRadius = UDim.new(0, 6)
    joinCorner.Parent = join

    join.MouseEnter:Connect(function()
        join.BackgroundColor3 = THEME.AccentHover
    end)
    join.MouseLeave:Connect(function()
        join.BackgroundColor3 = THEME.Accent
    end)

    join.MouseButton1Click:Connect(function()
        StatusLabel.Text = "Teleportando..."
        pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
        end)
    end)
end

local function fetchServers()
    if isLoading then return end
    isLoading = true
    StatusLabel.Text = "Carregando servidores..."
    clearList()
    serversCache = {}

    local cursor = ""
    local loaded = 0

    while loaded < MAX_SERVERS do
        local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor \~= "" then
            url = url .. "&cursor=" .. cursor
        end

        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if not success or not result or not result.data then
            StatusLabel.Text = "Erro ao carregar. Tente novamente."
            isLoading = false
            return
        end

        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.id \~= JobId then
                table.insert(serversCache, {
                    id = server.id,
                    playing = server.playing or 0,
                    maxPlayers = server.maxPlayers or 0,
                    ping = server.ping or 999,
                    fps = server.fps or 0
                })
                loaded = loaded + 1
                if loaded >= MAX_SERVERS then break end
            end
        end

        cursor = result.nextPageCursor
        if not cursor or cursor == "" then break end
        task.wait(REQUEST_DELAY)
    end

    if currentSort == "ping" then
        table.sort(serversCache, function(a, b) return a.ping < b.ping end)
    elseif currentSort == "low" then
        table.sort(serversCache, function(a, b) return a.playing < b.playing end)
    else
        table.sort(serversCache, function(a, b) return a.playing > b.playing end)
    end

    for i, server in ipairs(serversCache) do
        createServerEntry(i, server)
    end

    ListFrame.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 16)
    StatusLabel.Text = "Carregados " .. #serversCache .. " servidores"
    isLoading = false
end

BtnPing.MouseButton1Click:Connect(function()
    currentSort = "ping"
    setActive(BtnPing)
    fetchServers()
end)

BtnLow.MouseButton1Click:Connect(function()
    currentSort = "low"
    setActive(BtnLow)
    fetchServers()
end)

BtnHigh.MouseButton1Click:Connect(function()
    currentSort = "high"
    setActive(BtnHigh)
    fetchServers()
end)

RefreshBtn.MouseButton1Click:Connect(fetchServers)

AutoHopBtn.MouseButton1Click:Connect(function()
    if #serversCache == 0 then
        StatusLabel.Text = "Carregue os servidores primeiro"
        return
    end

    local best = serversCache[1]
    if currentSort \~= "ping" then
        table.sort(serversCache, function(a, b) return a.ping < b.ping end)
        best = serversCache[1]
    end

    StatusLabel.Text = "Auto Hop → Ping " .. best.ping
    pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, best.id, LocalPlayer)
    end)
end)

local dragging, dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

fetchServers()
