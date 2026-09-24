--[[
    Light Hop PRO
    - Ordena por menor ping / menos players / mais players
    - Mostra Ping + FPS
    - Visual atualizado (tema preto/amarelo, inspirado na referÃªncia)
    - BotÃ£o de abrir/fechar (LH) e botÃ£o de fechar (X) maiores
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

-- FOTO DO BOTAO LH (opcional). Use UMA das duas opcoes:
-- 1) ICON_ASSET_ID: id de imagem enviada ao Roblox, ex: "rbxassetid://123456789"
-- 2) ICON_URL: link raw de uma imagem png/jpg no seu GitHub
local ICON_ASSET_ID = ""
local ICON_URL = "https://raw.githubusercontent.com/sala192828817-dev/LightHop/main/foto.png"

local THEME = {
    Background = Color3.fromRGB(14, 14, 17),
    Secondary = Color3.fromRGB(24, 24, 29),
    Card = Color3.fromRGB(20, 20, 24),
    Accent = Color3.fromRGB(255, 190, 40),
    AccentHover = Color3.fromRGB(255, 210, 70),
    Text = Color3.fromRGB(245, 245, 245),
    TextDim = Color3.fromRGB(160, 160, 170),
    Border = Color3.fromRGB(48, 48, 56),
    GoodPing = Color3.fromRGB(80, 220, 120),
    MediumPing = Color3.fromRGB(255, 190, 40),
    BadPing = Color3.fromRGB(230, 80, 80),
    TitleYellow = Color3.fromRGB(255, 200, 50),
    CloseRed = Color3.fromRGB(235, 90, 90),
}

-- ===================== BASE GUI =====================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LightHop"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 9999
ScreenGui.IgnoreGuiInset = true

-- No Delta (principalmente mobile), gethui()/CoreGui Ã s vezes devolvem um
-- container que nÃ£o renderiza por cima do jogo. PlayerGui Ã© o mais confiÃ¡vel.
local function getGuiParent()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    if playerGui then
        return playerGui
    end

    local okHui, hui = pcall(function()
        return gethui and gethui()
    end)
    if okHui and hui then
        return hui
    end

    return game:GetService("CoreGui")
end

ScreenGui.Parent = getGuiParent()
ScreenGui.Enabled = true

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Light Hop",
        Text = "Script carregado!",
        Duration = 4
    })
end)

-- ===================== JANELA PRINCIPAL =====================

local Main = Instance.new("Frame")
Main.Name = "Main"
local cam = workspace.CurrentCamera
local viewport = cam and cam.ViewportSize or Vector2.new(800, 600)
local PANEL_W = math.min(460, viewport.X - 40)
local PANEL_H = math.min(600, viewport.Y - 40)
Main.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
Main.Position = UDim2.new(0.5, -PANEL_W / 2, 0.5, -PANEL_H / 2)
Main.BackgroundColor3 = THEME.Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = false
Main.Visible = true
Main.ZIndex = 2
Main.Parent = ScreenGui

print("[LightHop] ScreenGui parented to: " .. ScreenGui.Parent:GetFullName())

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 14)
UICorner.Parent = Main

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = THEME.Border
UIStroke.Thickness = 1
UIStroke.Parent = Main

-- Avatar circular no topo (usa o mesmo Ã­cone do botÃ£o LH)
local AvatarHolder = Instance.new("Frame")
AvatarHolder.Size = UDim2.new(0, 56, 0, 56)
AvatarHolder.Position = UDim2.new(0.5, -28, 0, -28)
AvatarHolder.BackgroundColor3 = THEME.Secondary
AvatarHolder.BorderSizePixel = 0
AvatarHolder.ZIndex = 3
AvatarHolder.Parent = Main

local AvatarCorner = Instance.new("UICorner")
AvatarCorner.CornerRadius = UDim.new(1, 0)
AvatarCorner.Parent = AvatarHolder

local AvatarStroke = Instance.new("UIStroke")
AvatarStroke.Color = THEME.Accent
AvatarStroke.Thickness = 2
AvatarStroke.Parent = AvatarHolder

local AvatarImage = Instance.new("ImageLabel")
AvatarImage.Size = UDim2.new(1, -6, 1, -6)
AvatarImage.Position = UDim2.new(0, 3, 0, 3)
AvatarImage.BackgroundTransparency = 1
AvatarImage.ScaleType = Enum.ScaleType.Crop
AvatarImage.ZIndex = 3
AvatarImage.Parent = AvatarHolder

local AvatarCropCorner = Instance.new("UICorner")
AvatarCropCorner.CornerRadius = UDim.new(1, 0)
AvatarCropCorner.Parent = AvatarImage

-- Barra de tÃ­tulo
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 78)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = THEME.Background
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 14)
TitleCorner.Parent = TitleBar

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 16)
TitleFix.Position = UDim2.new(0, 0, 1, -16)
TitleFix.BackgroundColor3 = THEME.Background
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -100, 0, 26)
Title.Position = UDim2.new(0, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "LIGHT HOP PRO"
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 20
Title.TextColor3 = THEME.TitleYellow
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = TitleBar

-- Engrenagem (configuraÃ§Ãµes) ao lado do tÃ­tulo
local GearBtn = Instance.new("TextButton")
GearBtn.Size = UDim2.new(0, 26, 0, 26)
GearBtn.Position = UDim2.new(0.5, 108, 0, 42)
GearBtn.BackgroundTransparency = 1
GearBtn.Text = "\226\154\153" -- âš™
GearBtn.Font = Enum.Font.GothamBold
GearBtn.TextSize = 18
GearBtn.TextColor3 = THEME.TextDim
GearBtn.Parent = TitleBar

-- BotÃ£o de fechar (X) â€” MAIOR e destacado, canto superior direito
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 46, 0, 46)
CloseBtn.Position = UDim2.new(1, -58, 0, 12)
CloseBtn.BackgroundColor3 = THEME.CloseRed
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBlack
CloseBtn.TextSize = 22
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.AutoButtonColor = true
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 12)
CloseCorner.Parent = CloseBtn

local CloseStroke = Instance.new("UIStroke")
CloseStroke.Color = Color3.fromRGB(255, 150, 150)
CloseStroke.Thickness = 1
CloseStroke.Parent = CloseBtn

-- BotÃ£o flutuante para abrir/fechar o painel (LH) â€” MAIOR
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "Toggle"
ToggleBtn.Size = UDim2.new(0, 64, 0, 64)
ToggleBtn.Position = UDim2.new(0, 12, 0.5, -32)
ToggleBtn.BackgroundColor3 = THEME.Accent
ToggleBtn.Text = "LH"
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.TextSize = 20
ToggleBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
ToggleBtn.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 16)
ToggleCorner.Parent = ToggleBtn

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = THEME.AccentHover
ToggleStroke.Thickness = 2
ToggleStroke.Parent = ToggleBtn

local IconImage = Instance.new("ImageLabel")
IconImage.Size = UDim2.new(1, 0, 1, 0)
IconImage.BackgroundTransparency = 1
IconImage.ScaleType = Enum.ScaleType.Crop
IconImage.Active = false
IconImage.Visible = false
IconImage.Parent = ToggleBtn

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(0, 16)
IconCorner.Parent = IconImage

local function applyIcon(image)
    IconImage.Image = image
    IconImage.Visible = true
    ToggleBtn.Text = ""
    AvatarImage.Image = image
end

task.spawn(function()
    if ICON_ASSET_ID ~= "" then
        pcall(applyIcon, ICON_ASSET_ID)
    elseif ICON_URL ~= "" then
        pcall(function()
            local data = game:HttpGet(ICON_URL)
            writefile("LightHop_icon.png", data)
            local getAsset = getcustomasset or getsynasset
            applyIcon(getAsset("LightHop_icon.png"))
        end)
    end
end)

-- Arrastar o botÃ£o flutuante (LH)
local toggleDragging = false
local toggleMoved = false
local toggleDragStart, toggleStartPos

ToggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleMoved = false
        toggleDragStart = input.Position
        toggleStartPos = ToggleBtn.Position
    end
end)

ToggleBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if toggleDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - toggleDragStart
        if delta.Magnitude > 6 then
            toggleMoved = true
        end
        if toggleMoved then
            ToggleBtn.Position = UDim2.new(toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X, toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y)
        end
    end
end)

ToggleBtn.MouseButton1Click:Connect(function()
    if not toggleMoved then
        Main.Visible = not Main.Visible
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)

-- ===================== BOTÃ•ES DE ORDENAÃ‡ÃƒO =====================

local SortFrame = Instance.new("Frame")
SortFrame.Size = UDim2.new(1, -24, 0, 36)
SortFrame.Position = UDim2.new(0, 12, 0, 86)
SortFrame.BackgroundTransparency = 1
SortFrame.Parent = Main

local SortLayout = Instance.new("UIListLayout")
SortLayout.FillDirection = Enum.FillDirection.Horizontal
SortLayout.SortOrder = Enum.SortOrder.LayoutOrder
SortLayout.Padding = UDim.new(0, 6)
SortLayout.Parent = SortFrame

local function createSortButton(text, layoutOrder)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 0, 1, 0)
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.LayoutOrder = layoutOrder
    btn.BackgroundColor3 = THEME.Secondary
    btn.Text = "  " .. text .. "  "
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = THEME.TextDim
    btn.Parent = SortFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = THEME.Border
    stroke.Thickness = 1
    stroke.Parent = btn

    return btn, stroke
end

local BtnPing, StrokePing = createSortButton("MENOR PING", 1)
local BtnLow, StrokeLow = createSortButton("MAIS VAZIOS", 2)
local BtnHigh, StrokeHigh = createSortButton("MAIS JOGADORES", 3)
local BtnFilter, StrokeFilter = createSortButton("FILTRO AVANÃ‡ADO", 4)

local currentSort = "ping"

local sortButtons = {
    {btn = BtnPing, stroke = StrokePing},
    {btn = BtnLow, stroke = StrokeLow},
    {btn = BtnHigh, stroke = StrokeHigh},
}

local function setActive(target)
    for _, entry in pairs(sortButtons) do
        entry.btn.BackgroundColor3 = THEME.Secondary
        entry.btn.TextColor3 = THEME.TextDim
        entry.stroke.Color = THEME.Border
    end
    for _, entry in pairs(sortButtons) do
        if entry.btn == target then
            entry.btn.BackgroundColor3 = THEME.Accent
            entry.btn.TextColor3 = Color3.fromRGB(20, 20, 20)
            entry.stroke.Color = THEME.AccentHover
        end
    end
end

setActive(BtnPing)
BtnFilter.BackgroundColor3 = THEME.Secondary
BtnFilter.TextColor3 = THEME.Accent
StrokeFilter.Color = THEME.Accent

-- ===================== STATUS / PROGRESSO =====================

local StatusRow = Instance.new("Frame")
StatusRow.Size = UDim2.new(1, -24, 0, 20)
StatusRow.Position = UDim2.new(0, 12, 0, 128)
StatusRow.BackgroundTransparency = 1
StatusRow.Parent = Main

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -100, 1, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "servidores carregados 0"
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextColor3 = THEME.TextDim
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.Parent = StatusRow

local ProgressBack = Instance.new("Frame")
ProgressBack.Size = UDim2.new(0, 90, 0, 6)
ProgressBack.Position = UDim2.new(1, -190, 0.5, -3)
ProgressBack.BackgroundColor3 = THEME.Secondary
ProgressBack.BorderSizePixel = 0
ProgressBack.Parent = StatusRow

local ProgressBackCorner = Instance.new("UICorner")
ProgressBackCorner.CornerRadius = UDim.new(1, 0)
ProgressBackCorner.Parent = ProgressBack

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = THEME.Accent
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressBack

local ProgressFillCorner = Instance.new("UICorner")
ProgressFillCorner.CornerRadius = UDim.new(1, 0)
ProgressFillCorner.Parent = ProgressFill

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 84, 0, 28)
RefreshBtn.Position = UDim2.new(1, -84, 0, -4)
RefreshBtn.BackgroundColor3 = THEME.Secondary
RefreshBtn.Text = "\226\134\187 Refresh" -- â†»
RefreshBtn.Font = Enum.Font.GothamMedium
RefreshBtn.TextSize = 12
RefreshBtn.TextColor3 = THEME.Text
RefreshBtn.Parent = StatusRow

local RefreshCorner = Instance.new("UICorner")
RefreshCorner.CornerRadius = UDim.new(0, 8)
RefreshCorner.Parent = RefreshBtn

-- ===================== LISTA DE SERVIDORES =====================

local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Size = UDim2.new(1, -24, 1, -270)
ListFrame.Position = UDim2.new(0, 12, 0, 156)
ListFrame.BackgroundColor3 = THEME.Secondary
ListFrame.BorderSizePixel = 0
ListFrame.ScrollBarThickness = 4
ListFrame.ScrollBarImageColor3 = THEME.Accent
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.Parent = Main

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 10)
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

-- ===================== RODAPÃ‰: AUTO HOP =====================

local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, -24, 0, 96)
Footer.Position = UDim2.new(0, 12, 1, -106)
Footer.BackgroundColor3 = THEME.Secondary
Footer.BorderSizePixel = 0
Footer.Parent = Main

local FooterCorner = Instance.new("UICorner")
FooterCorner.CornerRadius = UDim.new(0, 10)
FooterCorner.Parent = Footer

local function createToggleSwitch(parent, position, defaultOn)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0, 44, 0, 24)
    holder.Position = position
    holder.BackgroundColor3 = defaultOn and THEME.Accent or THEME.Border
    holder.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = holder

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = defaultOn and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = holder

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = holder

    local state = defaultOn
    btn.MouseButton1Click:Connect(function()
        state = not state
        holder.BackgroundColor3 = state and THEME.Accent or THEME.Border
        knob.Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    end)

    return holder
end

local AutoHopLabel = Instance.new("TextLabel")
AutoHopLabel.Size = UDim2.new(0, 100, 0, 20)
AutoHopLabel.Position = UDim2.new(0, 12, 0, 8)
AutoHopLabel.BackgroundTransparency = 1
AutoHopLabel.Text = "AUTO HOP"
AutoHopLabel.Font = Enum.Font.GothamBold
AutoHopLabel.TextSize = 13
AutoHopLabel.TextColor3 = THEME.Text
AutoHopLabel.TextXAlignment = Enum.TextXAlignment.Left
AutoHopLabel.Parent = Footer

createToggleSwitch(Footer, UDim2.new(0, 120, 0, 8), true)

local AutoModeBtnPing = Instance.new("TextButton")
AutoModeBtnPing.Size = UDim2.new(0, 110, 0, 24)
AutoModeBtnPing.Position = UDim2.new(1, -234, 0, 6)
AutoModeBtnPing.BackgroundColor3 = THEME.Accent
AutoModeBtnPing.Text = "MELHOR PING"
AutoModeBtnPing.Font = Enum.Font.GothamBold
AutoModeBtnPing.TextSize = 11
AutoModeBtnPing.TextColor3 = Color3.fromRGB(20, 20, 20)
AutoModeBtnPing.Parent = Footer

local AutoModePingCorner = Instance.new("UICorner")
AutoModePingCorner.CornerRadius = UDim.new(0, 8)
AutoModePingCorner.Parent = AutoModeBtnPing

local AutoModeBtnEmpty = Instance.new("TextButton")
AutoModeBtnEmpty.Size = UDim2.new(0, 110, 0, 24)
AutoModeBtnEmpty.Position = UDim2.new(1, -118, 0, 6)
AutoModeBtnEmpty.BackgroundColor3 = THEME.Card
AutoModeBtnEmpty.Text = "MAIS VAZIOS"
AutoModeBtnEmpty.Font = Enum.Font.GothamBold
AutoModeBtnEmpty.TextSize = 11
AutoModeBtnEmpty.TextColor3 = THEME.TextDim
AutoModeBtnEmpty.Parent = Footer

local AutoModeEmptyCorner = Instance.new("UICorner")
AutoModeEmptyCorner.CornerRadius = UDim.new(0, 8)
AutoModeEmptyCorner.Parent = AutoModeBtnEmpty

local ActiveModeLabel = Instance.new("TextLabel")
ActiveModeLabel.Size = UDim2.new(0, 100, 0, 20)
ActiveModeLabel.Position = UDim2.new(0, 12, 0, 40)
ActiveModeLabel.BackgroundTransparency = 1
ActiveModeLabel.Text = "MODO ATIVO"
ActiveModeLabel.Font = Enum.Font.GothamBold
ActiveModeLabel.TextSize = 13
ActiveModeLabel.TextColor3 = THEME.Text
ActiveModeLabel.TextXAlignment = Enum.TextXAlignment.Left
ActiveModeLabel.Parent = Footer

createToggleSwitch(Footer, UDim2.new(0, 120, 0, 40), false)

local AutoHopBtn = Instance.new("TextButton")
AutoHopBtn.Size = UDim2.new(1, -24, 0, 34)
AutoHopBtn.Position = UDim2.new(0, 12, 1, -42)
AutoHopBtn.BackgroundColor3 = THEME.Accent
AutoHopBtn.Text = "\226\156\148  Auto Hop (Melhor Ping)" -- âœ”
AutoHopBtn.Font = Enum.Font.GothamBold
AutoHopBtn.TextSize = 14
AutoHopBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
AutoHopBtn.Parent = Footer

local AutoCorner = Instance.new("UICorner")
AutoCorner.CornerRadius = UDim.new(0, 8)
AutoCorner.Parent = AutoHopBtn

-- ===================== LÃ“GICA DE SERVIDORES =====================

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
    entry.Size = UDim2.new(1, 0, 0, 74)
    entry.BackgroundColor3 = THEME.Card
    entry.BorderSizePixel = 0
    entry.LayoutOrder = index
    entry.Parent = ListFrame

    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 10)
    entryCorner.Parent = entry

    local entryStroke = Instance.new("UIStroke")
    entryStroke.Color = THEME.Border
    entryStroke.Thickness = 1
    entryStroke.Parent = entry

    -- nÃºmero da posiÃ§Ã£o
    local num = Instance.new("TextLabel")
    num.Size = UDim2.new(0, 32, 1, 0)
    num.Position = UDim2.new(0, 8, 0, 0)
    num.BackgroundTransparency = 1
    num.Text = "#"
