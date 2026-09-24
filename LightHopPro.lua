--[[
    LIGHT HOP PRO
    Reconstrução profissional do "Light Hop"
    - Arquitetura modular por namespaces (script único)
    - Estado centralizado, cleanup via Maid, UI responsiva
    - Auto Hop real (loop, cooldown, retry controlado)
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

--====================================================
-- SERVICES
--====================================================
local Players           = game:GetService("Players")
local TeleportService    = game:GetService("TeleportService")
local HttpService        = game:GetService("HttpService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

local PlaceId = game.PlaceId
local JobId   = game.JobId

--====================================================
-- CONFIG
--====================================================
local Config = {
    MaxServers      = 50,
    RequestDelay    = 0.35,
    AutoHopCooldown = 6,      -- segundos mínimos entre tentativas de hop
    MaxVisitedMemo  = 40,     -- quantos JobIds evitar reentrar
    IconAssetId     = "",     -- rbxassetid://... (opcional)
    IconUrl         = "https://raw.githubusercontent.com/sala192828817-dev/LightHop/main/foto.png",
    BaseUrls        = { "https://games.roblox.com", "https://games.roproxy.com" },
}

--====================================================
-- THEME
--====================================================
local Theme = {
    Background   = Color3.fromRGB(16, 16, 20),
    Surface      = Color3.fromRGB(24, 24, 29),
    SurfaceAlt   = Color3.fromRGB(30, 30, 36),
    Border       = Color3.fromRGB(48, 48, 56),
    Accent       = Color3.fromRGB(255, 191, 43),
    AccentHover  = Color3.fromRGB(255, 209, 84),
    AccentDim    = Color3.fromRGB(90, 74, 30),
    Text         = Color3.fromRGB(245, 245, 248),
    TextDim      = Color3.fromRGB(160, 160, 170),
    Good         = Color3.fromRGB(88, 214, 130),
    Medium       = Color3.fromRGB(255, 191, 43),
    Bad          = Color3.fromRGB(235, 90, 90),
    Danger       = Color3.fromRGB(220, 90, 90),
    Font         = Enum.Font.GothamMedium,
    FontBold     = Enum.Font.GothamBold,
}

--====================================================
-- MAID (cleanup / lifecycle)
--====================================================
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Add(task_)
    table.insert(self._tasks, task_)
    return task_
end

function Maid:Cleanup()
    for i = #self._tasks, 1, -1 do
        local t = self._tasks[i]
        self._tasks[i] = nil
        if typeof(t) == "RBXScriptConnection" then
            t:Disconnect()
        elseif typeof(t) == "Instance" then
            t:Destroy()
        elseif type(t) == "function" then
            pcall(t)
        elseif type(t) == "thread" then
            pcall(task.cancel, t)
        end
    end
end

-- Se o script já rodou antes nesta sessão, limpa a instância anterior antes de recomeçar
local existingGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("LightHopPro")
if existingGui then
    existingGui:Destroy()
end
if _G.__LightHopCleanup then
    pcall(_G.__LightHopCleanup)
end

local GlobalMaid = Maid.new()
_G.__LightHopCleanup = function()
    GlobalMaid:Cleanup()
end

--====================================================
-- STATE (fonte única de verdade)
--====================================================
local State = {
    _data = {
        sort         = "ping",   -- ping | low | high
        servers      = {},
        loading      = false,
        panelOpen    = true,
        autoHopOn    = false,
        autoHopMode  = "ping",   -- ping | low
        statusText   = "Pronto",
        errorText    = nil,
    },
    _listeners = {},
}

function State:Get(key)
    return self._data[key]
end

function State:Set(key, value)
    if self._data[key] == value then return end
    self._data[key] = value
    local list = self._listeners[key]
    if list then
        for _, fn in ipairs(list) do
            task.spawn(fn, value)
        end
    end
end

function State:OnChange(key, fn)
    self._listeners[key] = self._listeners[key] or {}
    table.insert(self._listeners[key], fn)
end

--====================================================
-- GUI ROOT
--====================================================
local function getGuiParent()
    local ok, hui = pcall(function()
        return (gethui and gethui()) or nil
    end)
    if ok and hui then return hui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LightHopPro"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getGuiParent()
GlobalMaid:Add(ScreenGui)

--====================================================
-- UTIL
--====================================================
local Util = {}

function Util.Round(instance, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = instance
    return c
end

function Util.Stroke(instance, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    s.Parent = instance
    return s
end

function Util.Tween(instance, props, duration, style)
    local tw = TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

function Util.PingColor(ping)
    if ping <= 80 then return Theme.Good
    elseif ping <= 150 then return Theme.Medium
    else return Theme.Bad end
end

--====================================================
-- NOTIFY (toasts)
--====================================================
local Notify = {}
do
    local NotifyHolder = Instance.new("Frame")
    NotifyHolder.Name = "Notifications"
    NotifyHolder.AnchorPoint = Vector2.new(0.5, 0)
    NotifyHolder.Position = UDim2.new(0.5, 0, 0, 12)
    NotifyHolder.Size = UDim2.new(0, 320, 0, 0)
    NotifyHolder.BackgroundTransparency = 1
    NotifyHolder.Parent = ScreenGui

    local layout = Instance.new("UIListLayout")
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 6)
    layout.Parent = NotifyHolder

    function Notify.Show(text, kind, duration)
        duration = duration or 3
        local color = kind == "error" and Theme.Danger or (kind == "success" and Theme.Good or Theme.Accent)

        local toast = Instance.new("Frame")
        toast.Size = UDim2.new(1, 0, 0, 0)
        toast.AutomaticSize = Enum.AutomaticSize.Y
        toast.BackgroundColor3 = Theme.Surface
        toast.BackgroundTransparency = 0
        toast.Parent = NotifyHolder
        Util.Round(toast, 8)
        Util.Stroke(toast, color, 1)

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 12)
        pad.PaddingRight = UDim.new(0, 12)
        pad.Parent = toast

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 0)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.Font = Theme.Font
        label.TextSize = 13
        label.TextWrapped = true
        label.TextColor3 = Theme.Text
        label.Text = text
        label.Parent = toast

        toast.BackgroundTransparency = 1
        label.TextTransparency = 1
        Util.Tween(toast, { BackgroundTransparency = 0 }, 0.15)
        Util.Tween(label, { TextTransparency = 0 }, 0.15)

        task.delay(duration, function()
            if toast and toast.Parent then
                Util.Tween(toast, { BackgroundTransparency = 1 }, 0.2)
                Util.Tween(label, { TextTransparency = 1 }, 0.2)
                task.delay(0.22, function()
                    if toast then toast:Destroy() end
                end)
            end
        end)
    end
end

--====================================================
-- UI BUILD
--====================================================
local UI = {}

-- Toggle flutuante ---------------------------------------------------
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "Toggle"
ToggleBtn.Size = UDim2.new(0, 46, 0, 46)
ToggleBtn.Position = UDim2.new(0, 14, 0.5, -23)
ToggleBtn.BackgroundColor3 = Theme.Accent
ToggleBtn.Text = "LH"
ToggleBtn.Font = Theme.FontBold
ToggleBtn.TextSize = 15
ToggleBtn.TextColor3 = Color3.fromRGB(18, 18, 18)
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = ScreenGui
Util.Round(ToggleBtn, 12)
GlobalMaid:Add(ToggleBtn)

local IconImage = Instance.new("ImageLabel")
IconImage.Size = UDim2.new(1, 0, 1, 0)
IconImage.BackgroundTransparency = 1
IconImage.ScaleType = Enum.ScaleType.Crop
IconImage.Visible = false
IconImage.Parent = ToggleBtn
Util.Round(IconImage, 12)

task.spawn(function()
    local function apply(img)
        IconImage.Image = img
        IconImage.Visible = true
        ToggleBtn.Text = ""
    end
    if Config.IconAssetId ~= "" then
        pcall(apply, Config.IconAssetId)
    elseif Config.IconUrl ~= "" then
        pcall(function()
            local fileName = "LightHopPro_icon.png"
            if not (isfile and isfile(fileName)) then
                local data = game:HttpGet(Config.IconUrl)
                writefile(fileName, data)
            end
            local getAsset = getcustomasset or getsynasset
            if getAsset then
                apply(getAsset(fileName))
            end
        end)
    end
end)

-- Painel principal ----------------------------------------------------
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.Parent = ScreenGui
Util.Round(Main, 14)
Util.Stroke(Main, Theme.Border, 1)
GlobalMaid:Add(Main)

local function computePanelSize()
    local cam = workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
    local w = math.clamp(vp.X - 32, 300, 430)
    local h = math.clamp(vp.Y - 32, 380, 560)
    return w, h
end

local function applyPanelSize(animate)
    local w, h = computePanelSize()
    local goal = { Size = UDim2.new(0, w, 0, h) }
    if animate then
        Util.Tween(Main, goal, 0.2)
    else
        Main.Size = UDim2.new(0, w, 0, h)
    end
end
applyPanelSize(false)

GlobalMaid:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    applyPanelSize(true)
end))

-- Header ----------------------------------------------------------------
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 56)
Header.BackgroundColor3 = Theme.Surface
Header.BorderSizePixel = 0
Header.Parent = Main
Util.Round(Header, 14)

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 16)
HeaderFix.Position = UDim2.new(0, 0, 1, -16)
HeaderFix.BackgroundColor3 = Theme.Surface
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.Font = Theme.FontBold
TitleLabel.TextSize = 17
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.TextColor3 = Theme.Text
TitleLabel.RichText = true
TitleLabel.Text = "LIGHT HOP <font color=\"#FFBF2B\">PRO</font>"
TitleLabel.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -42, 0.5, -16)
CloseBtn.BackgroundColor3 = Color3.fromRGB(48, 30, 30)
CloseBtn.Text = "✕"
CloseBtn.Font = Theme.FontBold
CloseBtn.TextSize = 15
CloseBtn.TextColor3 = Theme.Danger
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header
Util.Round(CloseBtn, 9)

-- Sort bar ----------------------------------------------------------------
local SortBar = Instance.new("Frame")
SortBar.Size = UDim2.new(1, -24, 0, 32)
SortBar.Position = UDim2.new(0, 12, 0, 66)
SortBar.BackgroundTransparency = 1
SortBar.Parent = Main

local SortLayout = Instance.new("UIListLayout")
SortLayout.FillDirection = Enum.FillDirection.Horizontal
SortLayout.Padding = UDim.new(0, 6)
SortLayout.Parent = SortBar

local sortButtons = {}
local function createSortButton(key, text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 0, 1, 0)
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.BackgroundColor3 = Theme.Surface
    btn.Text = "  " .. text .. "  "
    btn.Font = Theme.Font
    btn.TextSize = 12
    btn.TextColor3 = Theme.TextDim
    btn.AutoButtonColor = false
    btn.LayoutOrder = #sortButtons
    btn.Parent = SortBar
    Util.Round(btn, 8)
    sortButtons[key] = btn
    return btn
end

createSortButton("ping", "Menor Ping")
createSortButton("low", "Mais Vazios")
createSortButton("high", "Mais Jogadores")

local function refreshSortButtonsVisual()
    for key, btn in pairs(sortButtons) do
        local active = State:Get("sort") == key
        Util.Tween(btn, {
            BackgroundColor3 = active and Theme.Accent or Theme.Surface,
        }, 0.15)
        btn.TextColor3 = active and Color3.fromRGB(20, 20, 20) or Theme.TextDim
    end
end

-- Status row ----------------------------------------------------------------
local StatusRow = Instance.new("Frame")
StatusRow.Size = UDim2.new(1, -24, 0, 20)
StatusRow.Position = UDim2.new(0, 12, 0, 104)
StatusRow.BackgroundTransparency = 1
StatusRow.Parent = Main

local StatusLabel = Instance.new("TextLabel")
StatusLabel.BackgroundTransparency = 1
StatusLabel.Size = UDim2.new(1, -76, 1, 0)
StatusLabel.Font = Theme.Font
StatusLabel.TextSize = 12
StatusLabel.TextColor3 = Theme.TextDim
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.Text = "Pronto"
StatusLabel.Parent = StatusRow

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0, 72, 1, 0)
RefreshBtn.Position = UDim2.new(1, -72, 0, 0)
RefreshBtn.BackgroundColor3 = Theme.Surface
RefreshBtn.Text = "↻ Refresh"
RefreshBtn.Font = Theme.Font
RefreshBtn.TextSize = 12
RefreshBtn.TextColor3 = Theme.Text
RefreshBtn.AutoButtonColor = false
RefreshBtn.Parent = StatusRow
Util.Round(RefreshBtn, 7)

-- Progress bar (loading) ------------------------------------------------
local ProgressTrack = Instance.new("Frame")
ProgressTrack.Size = UDim2.new(1, -24, 0, 3)
ProgressTrack.Position = UDim2.new(0, 12, 0, 128)
ProgressTrack.BackgroundColor3 = Theme.Border
ProgressTrack.BorderSizePixel = 0
ProgressTrack.Parent = Main
Util.Round(ProgressTrack, 2)

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Theme.Accent
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressTrack
Util.Round(ProgressFill, 2)

local progressLoopThread = nil
local function setLoadingVisual(loading)
    if progressLoopThread then
        task.cancel(progressLoopThread)
        progressLoopThread = nil
    end
    if loading then
        progressLoopThread = task.spawn(function()
            while true do
                Util.Tween(ProgressFill, { Size = UDim2.new(0.75, 0, 1, 0) }, 0.5)
                task.wait(0.5)
                Util.Tween(ProgressFill, { Size = UDim2.new(0.15, 0, 1, 0) }, 0.5)
                task.wait(0.5)
            end
        end)
    else
        Util.Tween(ProgressFill, { Size = UDim2.new(1, 0, 1, 0) }, 0.2)
        task.delay(0.25, function()
            if not State:Get("loading") then
                ProgressFill.Size = UDim2.new(0, 0, 1, 0)
            end
        end)
    end
end
GlobalMaid:Add(function()
    if progressLoopThread then task.cancel(progressLoopThread) end
end)

-- Lista de servidores ----------------------------------------------------
local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Size = UDim2.new(1, -24, 1, -228)
ListFrame.Position = UDim2.new(0, 12, 0, 138)
ListFrame.BackgroundColor3 = Theme.Surface
ListFrame.BorderSizePixel = 0
ListFrame.ScrollBarThickness = 4
ListFrame.ScrollBarImageColor3 = Theme.Accent
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.Parent = Main
Util.Round(ListFrame, 10)

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

GlobalMaid:Add(ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ListFrame.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 16)
end))

-- Empty / Error state label -------------------------------------------
local EmptyLabel = Instance.new("TextLabel")
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.Size = UDim2.new(1, -16, 0, 60)
EmptyLabel.Position = UDim2.new(0, 8, 0, 8)
EmptyLabel.Font = Theme.Font
EmptyLabel.TextSize = 13
EmptyLabel.TextColor3 = Theme.TextDim
EmptyLabel.TextWrapped = true
EmptyLabel.Visible = false
EmptyLabel.Text = "Nenhum servidor encontrado."
EmptyLabel.Parent = ListFrame

-- Footer: Auto Hop ---------------------------------------------------
local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, -24, 0, 78)
Footer.Position = UDim2.new(0, 12, 1, -86)
Footer.BackgroundColor3 = Theme.Surface
Footer.BorderSizePixel = 0
Footer.Parent = Main
Util.Round(Footer, 10)

local AutoHopLabel = Instance.new("TextLabel")
AutoHopLabel.BackgroundTransparency = 1
AutoHopLabel.Size = UDim2.new(0, 100, 0, 30)
AutoHopLabel.Position = UDim2.new(0, 12, 0, 6)
AutoHopLabel.Font = Theme.FontBold
AutoHopLabel.TextSize = 13
AutoHopLabel.TextColor3 = Theme.Text
AutoHopLabel.TextXAlignment = Enum.TextXAlignment.Left
AutoHopLabel.Text = "AUTO HOP"
AutoHopLabel.Parent = Footer

-- Toggle switch (pill)
local SwitchTrack = Instance.new("Frame")
SwitchTrack.Size = UDim2.new(0, 44, 0, 24)
SwitchTrack.Position = UDim2.new(1, -56, 0, 8)
SwitchTrack.BackgroundColor3 = Theme.Border
SwitchTrack.Parent = Footer
Util.Round(SwitchTrack, 12)

local SwitchKnob = Instance.new("Frame")
SwitchKnob.Size = UDim2.new(0, 18, 0, 18)
SwitchKnob.Position = UDim2.new(0, 3, 0.5, -9)
SwitchKnob.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
SwitchKnob.Parent = SwitchTrack
Util.Round(SwitchKnob, 9)

local SwitchBtn = Instance.new("TextButton")
SwitchBtn.Size = UDim2.new(1, 0, 1, 0)
SwitchBtn.BackgroundTransparency = 1
SwitchBtn.Text = ""
SwitchBtn.Parent = SwitchTrack

local function refreshSwitchVisual()
    local on = State:Get("autoHopOn")
    Util.Tween(SwitchTrack, { BackgroundColor3 = on and Theme.Accent or Theme.Border }, 0.15)
    Util.Tween(SwitchKnob, { Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) }, 0.15)
end

local AutoHopModeRow = Instance.new("Frame")
AutoHopModeRow.Size = UDim2.new(1, -24, 0, 24)
AutoHopModeRow.Position = UDim2.new(0, 12, 0, 40)
AutoHopModeRow.BackgroundTransparency = 1
AutoHopModeRow.Parent = Footer

local ModeLayout = Instance.new("UIListLayout")
ModeLayout.FillDirection = Enum.FillDirection.Horizontal
ModeLayout.Padding = UDim.new(0, 6)
ModeLayout.Parent = AutoHopModeRow

local modeButtons = {}
local function createModeButton(key, text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 0, 1, 0)
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.BackgroundColor3 = Theme.SurfaceAlt
    btn.Text = "  " .. text .. "  "
    btn.Font = Theme.Font
    btn.TextSize = 11
    btn.TextColor3 = Theme.TextDim
    btn.AutoButtonColor = false
    btn.Parent = AutoHopModeRow
    Util.Round(btn, 6)
    modeButtons[key] = btn
    return btn
end
createModeButton("ping", "Melhor Ping")
createModeButton("low", "Mais Vazios")

local function refreshModeVisual()
    for key, btn in pairs(modeButtons) do
        local active = State:Get("autoHopMode") == key
        btn.BackgroundColor3 = active and Theme.Accent or Theme.SurfaceAlt
        btn.TextColor3 = active and Color3.fromRGB(20, 20, 20) or Theme.TextDim
    end
end

--====================================================
-- API (rede)
--====================================================
local API = {}

local function httpAttempt(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" then return body end
    return nil, tostring(body)
end

local function requestAttempt(url)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return nil, "sem request disponível" end
    local ok, res = pcall(function()
        return req({ Url = url, Method = "GET" })
    end)
    if ok and type(res) == "table" and res.Body then
        if res.StatusCode == nil or res.StatusCode == 200 then
            return res.Body
        end
        return nil, "HTTP " .. tostring(res.StatusCode)
    end
    return nil, "request falhou"
end

local function getJson(url)
    local errors = {}
    for _, method in ipairs({ httpAttempt, requestAttempt }) do
        local body, err = method(url)
        if body then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
            if ok and type(data) == "table" and data.data then
                return data
            end
            table.insert(errors, "resposta inválida")
        else
            table.insert(errors, err)
        end
    end
    return nil, table.concat(errors, " | ")
end

function API.FetchPage(cursor, order)
    local errors = {}
    for _, base in ipairs(Config.BaseUrls) do
        local url = base .. "/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=" .. order .. "&limit=100"
        if cursor and cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end
        for attempt = 1, 2 do
            local data, err = getJson(url)
            if data then return data end
            if attempt == 1 and err and string.find(err, "429") then
                task.wait(1.5)
            else
                table.insert(errors, err)
                break
            end
        end
    end
    return nil, table.concat(errors, " || ")
end

--====================================================
-- SERVER MANAGER
--====================================================
local ServerManager = {}
local visitedOrder = {}
local visitedSet = {}

local function markVisited(id)
    if visitedSet[id] then return end
    visitedSet[id] = true
    table.insert(visitedOrder, id)
    if #visitedOrder > Config.MaxVisitedMemo then
        local oldest = table.remove(visitedOrder, 1)
        visitedSet[oldest] = nil
    end
end
markVisited(JobId)

function ServerManager.Sort(servers, key)
    if key == "ping" then
        table.sort(servers, function(a, b) return a.ping < b.ping end)
    elseif key == "low" then
        table.sort(servers, function(a, b) return a.playing < b.playing end)
    else
        table.sort(servers, function(a, b) return a.playing > b.playing end)
    end
    return servers
end

function ServerManager.Fetch()
    if State:Get("loading") then return end
    State:Set("loading", true)
    State:Set("statusText", "Carregando servidores...")

    local requestedSort = State:Get("sort")
    local order = (requestedSort == "high") and "Desc" or "Asc"
    local collected = {}
    local cursor = ""

    local ok, err = pcall(function()
        while #collected < Config.MaxServers do
            local result, fetchErr = API.FetchPage(cursor, order)
            if not result then
                error(fetchErr or "falha desconhecida")
            end
            for _, server in ipairs(result.data) do
                if server.playing < server.maxPlayers and server.id ~= JobId and not visitedSet[server.id] then
                    table.insert(collected, {
                        id = server.id,
                        playing = server.playing or 0,
                        maxPlayers = server.maxPlayers or 0,
                        ping = server.ping or 999,
                        fps = server.fps or 60,
                    })
                    if #collected >= Config.MaxServers then break end
                end
            end
            cursor = result.nextPageCursor
            if type(cursor) ~= "string" or cursor == "" then break end
            task.wait(Config.RequestDelay)
        end
    end)

    State:Set("loading", false)

    if not ok then
        warn("[LightHopPro] " .. tostring(err))
        State:Set("errorText", tostring(err))
        State:Set("statusText", "Erro ao carregar servidores")
        Notify.Show("Falha ao buscar servidores. Tentando novamente pode ajudar.", "error")
        State:Set("servers", {})
        return
    end

    ServerManager.Sort(collected, requestedSort)
    State:Set("errorText", nil)
    State:Set("servers", collected)
    State:Set("statusText", ("%d servidores carregados"):format(#collected))

    -- Se o usuário trocou o filtro durante o carregamento, refaz UMA vez (sem recursão infinita)
    if State:Get("sort") ~= requestedSort then
        task.defer(ServerManager.Fetch)
    end
end

function ServerManager.BestServer(mode)
    local servers = State:Get("servers")
    if #servers == 0 then return nil end
    local copy = table.clone(servers)
    ServerManager.Sort(copy, mode)
    return copy[1]
end

--====================================================
-- TELEPORT
--====================================================
local function joinServer(server)
    if not server then return end
    State:Set("statusText", "Teleportando para " .. string.sub(server.id, 1, 6) .. "...")
    markVisited(server.id)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
    end)
    if not ok then
        Notify.Show("Falha ao teleportar: " .. tostring(err), "error")
        State:Set("statusText", "Erro no teleporte")
    end
end

--====================================================
-- AUTO HOP (loop controlado)
--====================================================
local AutoHop = {}
local autoHopThread = nil

function AutoHop.Start()
    if autoHopThread then return end
    State:Set("autoHopOn", true)

    autoHopThread = task.spawn(function()
        while State:Get("autoHopOn") do
            if not State:Get("loading") and #State:Get("servers") == 0 then
                ServerManager.Fetch()
                -- espera o fetch terminar antes de agir
                while State:Get("loading") do task.wait(0.2) end
            end

            local mode = State:Get("autoHopMode")
            local best = ServerManager.BestServer(mode)

            if best then
                State:Set("statusText", "Auto Hop → ping " .. best.ping .. "ms")
                joinServer(best)
                -- TeleportToPlaceInstance normalmente já desconecta o cliente;
                -- o cooldown abaixo é a rede de segurança caso o teleporte falhe/seja cancelado
            else
                State:Set("statusText", "Auto Hop: nenhum servidor elegível, buscando...")
                State:Set("servers", {})
            end

            local waited = 0
            while State:Get("autoHopOn") and waited < Config.AutoHopCooldown do
                task.wait(0.25)
                waited += 0.25
            end
        end
        autoHopThread = nil
    end)
end

function AutoHop.Stop()
    State:Set("autoHopOn", false)
    if autoHopThread then
        task.cancel(autoHopThread)
        autoHopThread = nil
    end
    State:Set("statusText", "Auto Hop desativado")
end

GlobalMaid:Add(function() AutoHop.Stop() end)

--====================================================
-- RENDER: lista de cards
--====================================================
local function createServerEntry(index, server)
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1, 0, 0, 58)
    entry.BackgroundColor3 = Theme.Background
    entry.BorderSizePixel = 0
    entry.LayoutOrder = index
    entry.BackgroundTransparency = 1
    entry.Parent = ListFrame
    Util.Round(entry, 9)

    local num = Instance.new("TextLabel")
    num.Size = UDim2.new(0, 26, 1, 0)
    num.Position = UDim2.new(0, 8, 0, 0)
    num.BackgroundTransparency = 1
    num.Text = "#" .. index
    num.Font = Theme.FontBold
    num.TextSize = 13
    num.TextColor3 = Theme.TextDim
    num.Parent = entry

    local playersLabel = Instance.new("TextLabel")
    playersLabel.Size = UDim2.new(0, 70, 0, 18)
    playersLabel.Position = UDim2.new(0, 38, 0, 6)
    playersLabel.BackgroundTransparency = 1
    playersLabel.Text = server.playing .. "/" .. server.maxPlayers
    playersLabel.Font = Theme.FontBold
    playersLabel.TextSize = 13
    playersLabel.TextColor3 = Theme.Text
    playersLabel.TextXAlignment = Enum.TextXAlignment.Left
    playersLabel.Parent = entry

    local barTrack = Instance.new("Frame")
    barTrack.Size = UDim2.new(0, 70, 0, 4)
    barTrack.Position = UDim2.new(0, 38, 0, 26)
    barTrack.BackgroundColor3 = Theme.Border
    barTrack.BorderSizePixel = 0
    barTrack.Parent = entry
    Util.Round(barTrack, 2)

    local ratio = server.maxPlayers > 0 and (server.playing / server.maxPlayers) or 0
    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
    barFill.BackgroundColor3 = Theme.Accent
    barFill.BorderSizePixel = 0
    barFill.Parent = barTrack
    Util.Round(barFill, 2)

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(0, 200, 1, -6)
    infoLabel.Position = UDim2.new(0, 118, 0, 3)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Theme.Font
    infoLabel.TextSize = 12
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.RichText = true
    local pingHex = Util.PingColor(server.ping):ToHex()
    infoLabel.Text = ("Ping: <font color=\"#%s\">%dms</font>   FPS: %d\nID: %s"):format(
        pingHex, server.ping, math.floor(server.fps), string.sub(server.id, 1, 8)
    )
    infoLabel.TextColor3 = Theme.TextDim
    infoLabel.Parent = entry

    local joinBtn = Instance.new("TextButton")
    joinBtn.Size = UDim2.new(0, 74, 0, 34)
    joinBtn.Position = UDim2.new(1, -84, 0.5, -17)
    joinBtn.BackgroundColor3 = Theme.Accent
    joinBtn.Text = "Join"
    joinBtn.Font = Theme.FontBold
    joinBtn.TextSize = 13
    joinBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
    joinBtn.AutoButtonColor = false
    joinBtn.Parent = entry
    Util.Round(joinBtn, 7)

    joinBtn.MouseEnter:Connect(function()
        Util.Tween(joinBtn, { BackgroundColor3 = Theme.AccentHover }, 0.12)
    end)
    joinBtn.MouseLeave:Connect(function()
        Util.Tween(joinBtn, { BackgroundColor3 = Theme.Accent }, 0.12)
    end)
    joinBtn.MouseButton1Click:Connect(function()
        joinServer(server)
    end)

    Util.Tween(entry, { BackgroundTransparency = 0 }, 0.15)
end

local function renderServerList(servers)
    for _, child in ipairs(ListFrame:GetChildren()) do
        if child:IsA("Frame") and child ~= EmptyLabel then
            child:Destroy()
        end
    end

    if #servers == 0 and not State:Get("loading") then
        EmptyLabel.Text = State:Get("errorText") and "Não foi possível carregar servidores. Toque em Refresh para tentar de novo."
            or "Nenhum servidor disponível no momento."
        EmptyLabel.Visible = true
    else
        EmptyLabel.Visible = false
        for i, server in ipairs(servers) do
            createServerEntry(i, server)
        end
    end
end

--====================================================
-- BINDINGS: State -> UI
--====================================================
State:OnChange("sort", function() refreshSortButtonsVisual() end)
State:OnChange("servers", function(servers) renderServerList(servers) end)
State:OnChange("loading", function(loading)
    setLoadingVisual(loading)
    RefreshBtn.AutoButtonColor = not loading
    for _, btn in pairs(sortButtons) do
        btn.Active = not loading
    end
end)
State:OnChange("statusText", function(text) StatusLabel.Text = text end)
State:OnChange("autoHopOn", function() refreshSwitchVisual() end)
State:OnChange("autoHopMode", function() refreshModeVisual() end)

refreshSortButtonsVisual()
refreshSwitchVisual()
refreshModeVisual()

--====================================================
-- INTERAÇÕES
--====================================================
local sortDebounce = false
local function bindSort(key, btn)
    btn.MouseButton1Click:Connect(function()
        if sortDebounce or State:Get("sort") == key then return end
        sortDebounce = true
        State:Set("sort", key)
        ServerManager.Fetch()
        task.delay(0.3, function() sortDebounce = false end)
    end)
end
for key, btn in pairs(sortButtons) do
    bindSort(key, btn)
end

for key, btn in pairs(modeButtons) do
    btn.MouseButton1Click:Connect(function()
        State:Set("autoHopMode", key)
    end)
end

RefreshBtn.MouseButton1Click:Connect(function()
    ServerManager.Fetch()
end)

SwitchBtn.MouseButton1Click:Connect(function()
    if State:Get("autoHopOn") then
        AutoHop.Stop()
    else
        AutoHop.Start()
    end
end)

-- Abrir/fechar painel com animação ------------------------------------
local function setPanelOpen(open, animate)
    State:Set("panelOpen", open)
    if not animate then
        Main.Visible = open
        return
    end
    if open then
        Main.Visible = true
        Main.Size = UDim2.new(0, 0, 0, 0)
        local w, h = computePanelSize()
        Util.Tween(Main, { Size = UDim2.new(0, w, 0, h) }, 0.22, Enum.EasingStyle.Back)
    else
        local w, h = computePanelSize()
        local tw = Util.Tween(Main, { Size = UDim2.new(0, 0, 0, 0) }, 0.18)
        tw.Completed:Connect(function()
            if not State:Get("panelOpen") then
                Main.Visible = false
                Main.Size = UDim2.new(0, w, 0, h)
            end
        end)
    end
end

CloseBtn.MouseButton1Click:Connect(function()
    setPanelOpen(false, true)
end)

-- Toggle (com suporte a arrastar) --------------------------------------
do
    local dragging, moved, dragStart, startPos = false, false, nil, nil

    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = ToggleBtn.Position
        end
    end)

    ToggleBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    GlobalMaid:Add(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 6 then moved = true end
            if moved then
                ToggleBtn.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end))

    ToggleBtn.MouseButton1Click:Connect(function()
        if not moved then
            setPanelOpen(not State:Get("panelOpen"), true)
        end
    end)
end

-- Arrastar o painel pelo header -----------------------------------------
do
    local dragging, dragStart, startPos = false, nil, nil

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)

    Header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    GlobalMaid:Add(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

-- Sai do Auto Hop e limpa tudo quando o jogador é removido ---------------
GlobalMaid:Add(Players.PlayerRemoving:Connect(function(p)
    if p == LocalPlayer then
        GlobalMaid:Cleanup()
    end
end))

--====================================================
-- BOOT
--====================================================
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Light Hop Pro",
        Text = "Interface carregada.",
        Duration = 3,
    })
end)

ServerManager.Fetch()
