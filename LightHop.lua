--[[
    ╔══════════════════════════════════════╗
              LIGHT HOP PRO
       Server Browser / Server Hop
    ╚══════════════════════════════════════╝

    DESIGN:
    - Interface inspirada na referência enviada
    - Botão LH maior
    - Painel moderno
    - Filtros
    - Server cards
    - Auto Hop
    - Ping / FPS
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

--// SERVICES
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

local PlaceId = game.PlaceId
local JobId = game.JobId

--// CONFIG
local MAX_SERVERS = 50
local REQUEST_DELAY = 0.4

-- ÍCONE DO BOTÃO LH
local ICON_ASSET_ID = ""

local ICON_URL =
    "https://raw.githubusercontent.com/sala192828817-dev/LightHop/main/foto.png"

--// THEME
local THEME = {
    Background = Color3.fromRGB(14, 14, 18),
    Panel = Color3.fromRGB(18, 18, 23),
    Card = Color3.fromRGB(29, 29, 35),
    CardHover = Color3.fromRGB(36, 36, 43),

    Accent = Color3.fromRGB(255, 190, 40),
    AccentHover = Color3.fromRGB(255, 207, 65),

    AccentDark = Color3.fromRGB(125, 91, 22),

    Text = Color3.fromRGB(245, 245, 245),
    TextDim = Color3.fromRGB(165, 165, 175),

    Border = Color3.fromRGB(58, 58, 66),

    GoodPing = Color3.fromRGB(70, 220, 120),
    MediumPing = Color3.fromRGB(255, 190, 40),
    BadPing = Color3.fromRGB(235, 80, 80),

    Green = Color3.fromRGB(65, 220, 120),
    Red = Color3.fromRGB(230, 85, 85),

    Black = Color3.fromRGB(10, 10, 12)
}

--// GUI PARENT
local function getGuiParent()
    local okHui, hui = pcall(function()
        if gethui then
            return gethui()
        end
    end)

    if okHui and hui then
        return hui
    end

    local okCore = pcall(function()
        game:GetService("CoreGui"):GetChildren()
    end)

    if okCore then
        return game:GetService("CoreGui")
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

--// SCREEN GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LightHopPro"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getGuiParent()

--========================================================
--// TOGGLE BUTTON
--========================================================

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "LightHopToggle"

-- MAIOR QUE O ORIGINAL
ToggleBtn.Size = UDim2.fromOffset(64, 64)
ToggleBtn.Position = UDim2.new(0, 18, 0.5, -32)

ToggleBtn.BackgroundColor3 = THEME.Background
ToggleBtn.Text = "LH"
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 18
ToggleBtn.TextColor3 = THEME.Accent
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 16)
ToggleCorner.Parent = ToggleBtn

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = THEME.Accent
ToggleStroke.Thickness = 2
ToggleStroke.Transparency = 0.15
ToggleStroke.Parent = ToggleBtn

-- brilho interno
local ToggleGradient = Instance.new("UIGradient")
ToggleGradient.Rotation = 45
ToggleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 42)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 18))
})
ToggleGradient.Parent = ToggleBtn

--// ICON
local IconImage = Instance.new("ImageLabel")
IconImage.Name = "Icon"
IconImage.Size = UDim2.new(1, -8, 1, -8)
IconImage.Position = UDim2.fromOffset(4, 4)
IconImage.BackgroundTransparency = 1
IconImage.ScaleType = Enum.ScaleType.Crop
IconImage.Visible = false
IconImage.Parent = ToggleBtn

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(0, 14)
IconCorner.Parent = IconImage

local function applyIcon(image)
    IconImage.Image = image
    IconImage.Visible = true
    ToggleBtn.Text = ""
end

task.spawn(function()
    if ICON_ASSET_ID ~= "" then
        pcall(function()
            applyIcon(ICON_ASSET_ID)
        end)

    elseif ICON_URL ~= "" then
        pcall(function()
            local data = game:HttpGet(ICON_URL)

            writefile("LightHop_icon.png", data)

            local getAsset = getcustomasset or getsynasset

            if getAsset then
                applyIcon(getAsset("LightHop_icon.png"))
            end
        end)
    end
end)

--========================================================
--// MAIN PANEL
--========================================================

local Main = Instance.new("Frame")
Main.Name = "Main"

local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(900, 700)

local PANEL_W = math.min(760, viewport.X - 35)
local PANEL_H = math.min(610, viewport.Y - 35)

Main.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
Main.Position = UDim2.new(
    0.5,
    -PANEL_W / 2,
    0.5,
    -PANEL_H / 2
)

Main.BackgroundColor3 = THEME.Panel
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 18)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = THEME.Border
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.15
MainStroke.Parent = Main

--========================================================
--// HEADER
--========================================================

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 92)
Header.BackgroundColor3 = THEME.Background
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 18)
HeaderCorner.Parent = Header

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 20)
HeaderFix.Position = UDim2.new(0, 0, 1, -20)
HeaderFix.BackgroundColor3 = THEME.Background
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

--// LOGO
local Logo = Instance.new("Frame")
Logo.Size = UDim2.fromOffset(62, 62)
Logo.Position = UDim2.new(0, 18, 0.5, -31)
Logo.BackgroundColor3 = THEME.Card
Logo.BorderSizePixel = 0
Logo.Parent = Header

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(1, 0)
LogoCorner.Parent = Logo

local LogoStroke = Instance.new("UIStroke")
LogoStroke.Color = THEME.Accent
LogoStroke.Thickness = 2
LogoStroke.Parent = Logo

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.fromScale(1, 1)
LogoText.BackgroundTransparency = 1
LogoText.Text = "LH"
LogoText.Font = Enum.Font.GothamBlack
LogoText.TextSize = 19
LogoText.TextColor3 = THEME.Accent
LogoText.Parent = Logo

--// TITLE
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 350, 0, 34)
Title.Position = UDim2.new(0, 94, 0, 25)
Title.BackgroundTransparency = 1
Title.Text = "LIGHT HOP "
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 24
Title.TextColor3 = THEME.Text
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local ProText = Instance.new("TextLabel")
ProText.Size = UDim2.fromOffset(70, 34)
ProText.Position = UDim2.new(0, 238, 0, 25)
ProText.BackgroundTransparency = 1
ProText.Text = "PRO"
ProText.Font = Enum.Font.GothamBlack
ProText.TextSize = 24
ProText.TextColor3 = THEME.Accent
ProText.TextXAlignment = Enum.TextXAlignment.Left
ProText.Parent = Header

--// SUBTITLE
local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(0, 350, 0, 20)
Subtitle.Position = UDim2.new(0, 96, 0, 54)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "SERVER BROWSER  •  FAST SERVER HOP"
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextSize = 10
Subtitle.TextColor3 = THEME.TextDim
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

--// GEAR
local GearBtn = Instance.new("TextButton")
GearBtn.Size = UDim2.fromOffset(38, 38)
GearBtn.Position = UDim2.new(1, -92, 0.5, -19)
GearBtn.BackgroundColor3 = THEME.Card
GearBtn.Text = "⚙"
GearBtn.Font = Enum.Font.GothamBold
GearBtn.TextSize = 21
GearBtn.TextColor3 = THEME.TextDim
GearBtn.AutoButtonColor = false
GearBtn.Parent = Header

local GearCorner = Instance.new("UICorner")
GearCorner.CornerRadius = UDim.new(0, 10)
GearCorner.Parent = GearBtn

--========================================================
--// CLOSE BUTTON
--========================================================

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "Close"
CloseBtn.Size = UDim2.fromOffset(44, 44)
CloseBtn.Position = UDim2.new(1, -48, 0, 16)

-- MAIOR QUE O ORIGINAL
CloseBtn.BackgroundColor3 = Color3.fromRGB(58, 35, 37)
CloseBtn.Text = "×"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 29
CloseBtn.TextColor3 = Color3.fromRGB(255, 115, 115)
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Main

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 12)
CloseCorner.Parent = CloseBtn

--========================================================
--// FILTER BAR
--========================================================

local FilterBar = Instance.new("Frame")
FilterBar.Size = UDim2.new(1, -32, 0, 48)
FilterBar.Position = UDim2.new(0, 16, 0, 105)
FilterBar.BackgroundTransparency = 1
FilterBar.Parent = Main

local function createFilterButton(text, icon, position, width)
    local button = Instance.new("TextButton")

    button.Size = UDim2.fromOffset(width, 42)
    button.Position = position

    button.BackgroundColor3 = THEME.Card
    button.BorderSizePixel = 0

    button.Text = icon .. "  " .. text

    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.TextColor3 = THEME.TextDim

    button.AutoButtonColor = false
    button.Parent = FilterBar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 11)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Thickness = 1
    stroke.Parent = button

    return button
end

local BtnPing = createFilterButton(
    "MENOR PING",
    "⌁",
    UDim2.fromOffset(0, 0),
    145
)

local BtnLow = createFilterButton(
    "MAIS VAZIOS",
    "♧",
    UDim2.fromOffset(153, 0),
    145
)

local BtnHigh = createFilterButton(
    "MAIS JOGADORES",
    "♟",
    UDim2.fromOffset(306, 0),
    155
)

local BtnAdvanced = createFilterButton(
    "FILTRO AVANÇADO",
    "⚑",
    UDim2.fromOffset(469, 0),
    165
)

local currentSort = "ping"

local function setActive(button)
    for _, b in ipairs({
        BtnPing,
        BtnLow,
        BtnHigh
    }) do
        b.BackgroundColor3 = THEME.Card
        b.TextColor3 = THEME.TextDim
    end

    button.BackgroundColor3 = THEME.Accent
    button.TextColor3 = THEME.Black
end

setActive(BtnPing)

--========================================================
--// STATUS AREA
--========================================================

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -180, 0, 25)
StatusLabel.Position = UDim2.new(0, 18, 0, 161)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "servidores carregados 0"
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextSize = 13
StatusLabel.TextColor3 = THEME.TextDim
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = Main

--// LOADING BAR
local LoadingBack = Instance.new("Frame")
LoadingBack.Size = UDim2.fromOffset(180, 7)
LoadingBack.Position = UDim2.new(1, -290, 0, 170)
LoadingBack.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
LoadingBack.BorderSizePixel = 0
LoadingBack.Parent = Main

local LoadingCorner = Instance.new("UICorner")
LoadingCorner.CornerRadius = UDim.new(1, 0)
LoadingCorner.Parent = LoadingBack

local LoadingBar = Instance.new("Frame")
LoadingBar.Size = UDim2.new(0, 0, 1, 0)
LoadingBar.BackgroundColor3 = THEME.Accent
LoadingBar.BorderSizePixel = 0
LoadingBar.Parent = LoadingBack

local LoadingBarCorner = Instance.new("UICorner")
LoadingBarCorner.CornerRadius = UDim.new(1, 0)
LoadingBarCorner.Parent = LoadingBar

--// REFRESH
local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.fromOffset(96, 34)
RefreshBtn.Position = UDim2.new(1, -110, 0, 156)
RefreshBtn.BackgroundColor3 = THEME.Card
RefreshBtn.Text = "↻  Refresh"
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.TextSize = 12
RefreshBtn.TextColor3 = THEME.Text
RefreshBtn.AutoButtonColor = false
RefreshBtn.Parent = Main

local RefreshCorner = Instance.new("UICorner")
RefreshCorner.CornerRadius = UDim.new(0, 10)
RefreshCorner.Parent = RefreshBtn

--========================================================
--// SERVER LIST
--========================================================

local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Name = "ServerList"

ListFrame.Size = UDim2.new(1, -32, 0, 315)
ListFrame.Position = UDim2.new(0, 16, 0, 194)

ListFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 17)
ListFrame.BorderSizePixel = 0

ListFrame.ScrollBarThickness = 5
ListFrame.ScrollBarImageColor3 = THEME.Accent

ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.Parent = Main

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 14)
ListCorner.Parent = ListFrame

local ListStroke = Instance.new("UIStroke")
ListStroke.Color = THEME.Border
ListStroke.Transparency = 0.35
ListStroke.Parent = ListFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 7)
ListLayout.Parent = ListFrame

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 8)
ListPadding.PaddingBottom = UDim.new(0, 8)
ListPadding.PaddingLeft = UDim.new(0, 8)
ListPadding.PaddingRight = UDim.new(0, 8)
ListPadding.Parent = ListFrame

--========================================================
--// BOTTOM CONTROLS
--========================================================

local Bottom = Instance.new("Frame")
Bottom.Size = UDim2.new(1, -32, 0, 74)
Bottom.Position = UDim2.new(0, 16, 1, -88)
Bottom.BackgroundColor3 = THEME.Background
Bottom.BorderSizePixel = 0
Bottom.Parent = Main

local BottomCorner = Instance.new("UICorner")
BottomCorner.CornerRadius = UDim.new(0, 14)
BottomCorner.Parent = Bottom

local AutoTitle = Instance.new("TextLabel")
AutoTitle.Size = UDim2.fromOffset(110, 24)
AutoTitle.Position = UDim2.fromOffset(16, 11)
AutoTitle.BackgroundTransparency = 1
AutoTitle.Text = "AUTO HOP"
AutoTitle.Font = Enum.Font.GothamBold
AutoTitle.TextSize = 13
AutoTitle.TextColor3 = THEME.Text
AutoTitle.TextXAlignment = Enum.TextXAlignment.Left
AutoTitle.Parent = Bottom

local AutoStatus = Instance.new("TextLabel")
AutoStatus.Size = UDim2.fromOffset(120, 20)
AutoStatus.Position = UDim2.fromOffset(16, 34)
AutoStatus.BackgroundTransparency = 1
AutoStatus.Text = "Melhor servidor"
AutoStatus.Font = Enum.Font.Gotham
AutoStatus.TextSize = 10
AutoStatus.TextColor3 = THEME.TextDim
AutoStatus.TextXAlignment = Enum.TextXAlignment.Left
AutoStatus.Parent = Bottom

--// AUTO TOGGLE
local AutoToggle = Instance.new("TextButton")
AutoToggle.Size = UDim2.fromOffset(48, 26)
AutoToggle.Position = UDim2.fromOffset(130, 22)
AutoToggle.BackgroundColor3 = THEME.Accent
AutoToggle.Text = ""
AutoToggle.AutoButtonColor = false
AutoToggle.Parent = Bottom

local AutoToggleCorner = Instance.new("UICorner")
AutoToggleCorner.CornerRadius = UDim.new(1, 0)
AutoToggleCorner.Parent = AutoToggle

local ToggleCircle = Instance.new("Frame")
ToggleCircle.Size = UDim2.fromOffset(20, 20)
ToggleCircle.Position = UDim2.new(1, -23, 0.5, -10)
ToggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleCircle.BorderSizePixel = 0
ToggleCircle.Parent = AutoToggle

local ToggleCircleCorner = Instance.new("UICorner")
ToggleCircleCorner.CornerRadius = UDim.new(1, 0)
ToggleCircleCorner.Parent = ToggleCircle

local autoEnabled = true

--// AUTO MODE BUTTON
local AutoMode = Instance.new("TextButton")
AutoMode.Size = UDim2.fromOffset(190, 42)
AutoMode.Position = UDim2.new(0, 195, 0.5, -21)
AutoMode.BackgroundColor3 = THEME.Card
AutoMode.Text = "✓  MELHOR PING  ⌁"
AutoMode.Font = Enum.Font.GothamBold
AutoMode.TextSize = 12
AutoMode.TextColor3 = THEME.Accent
AutoMode.AutoButtonColor = false
AutoMode.Parent = Bottom

local AutoModeCorner = Instance.new("UICorner")
AutoModeCorner.CornerRadius = UDim.new(0, 10)
AutoModeCorner.Parent = AutoMode

local AutoModeStroke = Instance.new("UIStroke")
AutoModeStroke.Color = THEME.Accent
AutoModeStroke.Thickness = 1
AutoModeStroke.Parent = AutoMode

--// AUTO HOP BUTTON
local AutoHopBtn = Instance.new("TextButton")
AutoHopBtn.Size = UDim2.new(0, 210, 0, 42)
AutoHopBtn.Position = UDim2.new(1, -226, 0.5, -21)
AutoHopBtn.BackgroundColor3 = THEME.Accent
AutoHopBtn.Text = "⚒  AUTO HOP"
AutoHopBtn.Font = Enum.Font.GothamBlack
AutoHopBtn.TextSize = 13
AutoHopBtn.TextColor3 = THEME.Black
AutoHopBtn.AutoButtonColor = false
AutoHopBtn.Parent = Bottom

local AutoHopCorner = Instance.new("UICorner")
AutoHopCorner.CornerRadius = UDim.new(0, 10)
AutoHopCorner.Parent = AutoHopBtn

--========================================================
--// SERVER DATA
--========================================================

local serversCache = {}
local isLoading = false

--========================================================
--// PING COLOR
--========================================================

local function getPingColor(ping)
    ping = tonumber(ping) or 999

    if ping <= 80 then
        return THEME.GoodPing
    elseif ping <= 140 then
        return THEME.MediumPing
    else
        return THEME.BadPing
    end
end

--========================================================
--// CLEAR LIST
--========================================================

local function clearList()
    for _, child in ipairs(ListFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

--========================================================
--// SERVER ENTRY
--========================================================

local function createServerEntry(index, server)

    local entry = Instance.new("Frame")

    entry.Size = UDim2.new(1, 0, 0, 78)

    entry.BackgroundColor3 = THEME.Card
    entry.BorderSizePixel = 0

    entry.LayoutOrder = index
    entry.Parent = ListFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 11)
    corner.Parent = entry

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Transparency = 0.45
    stroke.Parent = entry

    --====================================================
    -- NUMBER
    --====================================================

    local number = Instance.new("TextLabel")
    number.Size = UDim2.fromOffset(40, 70)
    number.Position = UDim2.fromOffset(8, 4)

    number.BackgroundTransparency = 1

    number.Text = "#" .. tostring(index)

    number.Font = Enum.Font.GothamBlack
    number.TextSize = 15
    number.TextColor3 = THEME.TextDim

    number.TextXAlignment = Enum.TextXAlignment.Center
    number.Parent = entry

    --====================================================
    -- PLAYER ICON / COUNT
    --====================================================

    local playerCount = Instance.new("TextLabel")

    playerCount.Size = UDim2.fromOffset(90, 24)
    playerCount.Position = UDim2.fromOffset(55, 12)

    playerCount.BackgroundTransparency = 1

    playerCount.Text =
        "♟  " ..
        tostring(server.playing or 0) ..
        " / " ..
        tostring(server.maxPlayers or 0)

    playerCount.Font = Enum.Font.GothamBold
    playerCount.TextSize = 14
    playerCount.TextColor3 = THEME.Text

    playerCount.TextXAlignment = Enum.TextXAlignment.Left
    playerCount.Parent = entry

    --====================================================
    -- PLAYER BAR
 
