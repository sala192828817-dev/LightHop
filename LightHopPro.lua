--[[
    LIGHT HOP PRO — ETAPA 2
    Integração da UI (Etapa 1, layout preservado) com a lógica real do script original.

    NESTA ETAPA:
    - Servidores reais via API pública do Roblox (games.roblox.com / roproxy).
    - Ping e FPS vêm diretamente do campo retornado pela própria API do Roblox.
    - Jogadores/capacidade reais, Server ID real, ordenação real (Sort).
    - Refresh real, Join Server real (TeleportService), Auto Hop real (loop + cooldown).
    - REGIÃO/BANDEIRA: a API pública de servidores do Roblox NÃO expõe o
      datacenter/região do servidor. Para não inventar dado falso, a região é
      exibida como "Desconhecida 🏳️" por padrão. O campo é mantido no card
      (nunca removido) e o código já verifica se o payload traz `region`/
      `location` caso a Roblox passe a fornecer isso no futuro, ou caso você
      plugue uma fonte própria depois.
    - Filtro Avançado e Configurações (⚙) continuam como placeholders visuais
      (ainda não têm conteúdo funcional) — não fazem parte do escopo desta etapa.
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

--====================================================
-- SERVICES
--====================================================
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

local PlaceId = game.PlaceId
local JobId   = game.JobId

--====================================================
-- THEME
--====================================================
local Theme = {
    Background   = Color3.fromRGB(14, 14, 18),
    Panel        = Color3.fromRGB(19, 19, 24),
    Surface      = Color3.fromRGB(26, 26, 32),
    SurfaceAlt   = Color3.fromRGB(32, 32, 39),
    Border       = Color3.fromRGB(50, 50, 59),
    BorderSoft   = Color3.fromRGB(38, 38, 45),
    Accent       = Color3.fromRGB(255, 190, 40),
    AccentHover  = Color3.fromRGB(255, 208, 84),
    AccentDim    = Color3.fromRGB(96, 78, 28),
    AccentText   = Color3.fromRGB(20, 17, 8),
    Text         = Color3.fromRGB(246, 246, 249),
    TextDim      = Color3.fromRGB(158, 158, 170),
    TextFaint    = Color3.fromRGB(110, 110, 122),
    Good         = Color3.fromRGB(88, 214, 130),
    Medium       = Color3.fromRGB(255, 190, 40),
    Bad          = Color3.fromRGB(235, 90, 90),
    Danger       = Color3.fromRGB(224, 92, 92),
    Blue         = Color3.fromRGB(70, 140, 235),
    Font         = Enum.Font.GothamMedium,
    FontBold     = Enum.Font.GothamBold,
    FontBlack    = Enum.Font.GothamBlack,
}

--====================================================
-- CONFIG
--====================================================
local Config = {
    MaxServers      = 50,
    RequestDelay    = 0.35,
    AutoHopCooldown = 6,    -- segundos mínimos entre tentativas de hop
    MaxVisitedMemo  = 40,   -- quantos JobIds evitar reentrar
    BaseUrls        = { "https://games.roblox.com", "https://games.roproxy.com" },
}

--====================================================
-- MAID
--====================================================
local Maid = {}
Maid.__index = Maid
function Maid.new() return setmetatable({ _tasks = {} }, Maid) end
function Maid:Add(t) table.insert(self._tasks, t); return t end
function Maid:Cleanup()
    for i = #self._tasks, 1, -1 do
        local t = self._tasks[i]
        self._tasks[i] = nil
        if typeof(t) == "RBXScriptConnection" then t:Disconnect()
        elseif typeof(t) == "Instance" then t:Destroy()
        elseif type(t) == "function" then pcall(t)
        elseif type(t) == "thread" then pcall(task.cancel, t) end
    end
end

local existingGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("LightHopPro")
if existingGui then existingGui:Destroy() end
if _G.__LightHopCleanup then pcall(_G.__LightHopCleanup) end

local GlobalMaid = Maid.new()
_G.__LightHopCleanup = function() GlobalMaid:Cleanup() end

--====================================================
-- STATE (fonte única de verdade — igual ao script original)
--====================================================
local State = {
    _data = {
        sort              = "ping",   -- ping | empty | players
        servers           = {},
        loading           = false,
        autoHopOn         = false,
        autoHopMode       = "ping",   -- ping | empty
        autoHopStatusText = nil,      -- mensagem transitória exibida na barra "Modo Ativo"
        errorText         = nil,
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
-- UTIL
--====================================================
local Util = {}

function Util.Round(inst, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = inst
    return c
end

function Util.Stroke(inst, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end

function Util.Pad(inst, l, r, t, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 0)
    p.PaddingRight = UDim.new(0, r or l or 0)
    p.PaddingTop = UDim.new(0, t or l or 0)
    p.PaddingBottom = UDim.new(0, b or t or l or 0)
    p.Parent = inst
    return p
end

function Util.Tween(inst, props, duration, style, dir)
    local tw = TweenService:Create(
        inst,
        TweenInfo.new(duration or 0.16, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

function Util.PingColor(ping)
    if ping <= 60 then return Theme.Good
    elseif ping <= 140 then return Theme.Medium
    else return Theme.Bad end
end

function Util.OccupancyColor(ratio)
    if ratio >= 0.9 then return Theme.Bad
    elseif ratio >= 0.6 then return Theme.Medium
    else return Theme.Accent end
end

local function getGuiParent()
    local ok, hui = pcall(function() return (gethui and gethui()) or nil end)
    if ok and hui then return hui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

--====================================================
-- GUI ROOT
--====================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LightHopPro"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getGuiParent()
GlobalMaid:Add(ScreenGui)

--====================================================
-- NOTIFY (toasts de feedback — erros, sucesso, avisos)
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
        toast.Parent = NotifyHolder
        Util.Round(toast, 8)
        Util.Stroke(toast, color, 1)
        Util.Pad(toast, 12, 12, 8, 8)

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
-- API (rede) — igual ao script original
--====================================================
local API = {}

local function httpAttempt(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    return nil, tostring(body)
end

local function requestAttempt(url)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return nil, "sem request disponível" end
    local ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
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

-- Deriva um "status" visual a partir dos dados reais (sem inventar métricas)
local function deriveStatus(server)
    if server.playing >= server.maxPlayers and server.maxPlayers > 0 then return "Cheio"
    elseif server.playing == 0 then return "Vazio"
    elseif server.ping > 150 then return "Instável"
    else return "Online" end
end

-- A API pública de servidores do Roblox não retorna região/datacenter.
-- Para não inventar dado falso, usamos "Desconhecida" por padrão, mas já
-- verificamos se o payload eventualmente trouxer algum campo de região.
local function deriveRegion(raw)
    local region = raw.region or (raw.location and raw.location.region)
    if type(region) == "string" and region ~= "" then
        return region, "🌐"
    end
    return "Desconhecida", "🏳️"
end

function ServerManager.Sort(servers, key)
    if key == "ping" then
        table.sort(servers, function(a, b) return a.ping < b.ping end)
    elseif key == "empty" then
        table.sort(servers, function(a, b) return a.playing < b.playing end)
    elseif key == "players" then
        table.sort(servers, function(a, b) return a.playing > b.playing end)
    end
    return servers
end

function ServerManager.Fetch()
    if State:Get("loading") then return end
    State:Set("loading", true)

    local requestedSort = State:Get("sort")
    local order = (requestedSort == "players") and "Desc" or "Asc"
    local collected = {}
    local cursor = ""

    local ok, err = pcall(function()
        while #collected < Config.MaxServers do
            local result, fetchErr = API.FetchPage(cursor, order)
            if not result then
                error(fetchErr or "falha desconhecida")
            end
            for _, raw in ipairs(result.data) do
                if raw.playing < raw.maxPlayers and raw.id ~= JobId and not visitedSet[raw.id] then
                    local region, flag = deriveRegion(raw)
                    local entry = {
                        id         = raw.id,
                        playing    = raw.playing or 0,
                        maxPlayers = raw.maxPlayers or 0,
                        ping       = raw.ping or 999,
                        fps        = raw.fps or 60,
                        region     = region,
                        flag       = flag,
                    }
                    entry.status = deriveStatus(entry)
                    table.insert(collected, entry)
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
        Notify.Show("Falha ao buscar servidores. Tente novamente.", "error")
        State:Set("servers", {})
        return
    end

    ServerManager.Sort(collected, requestedSort)
    State:Set("errorText", nil)
    State:Set("servers", collected)

    -- Se o filtro mudou durante o carregamento, refaz uma vez (sem recursão infinita)
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
    markVisited(server.id)
    Notify.Show("Teleportando para " .. string.sub(server.id, 1, 8) .. "...", "info", 2)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LocalPlayer)
    end)
    if not ok then
        Notify.Show("Falha ao teleportar: " .. tostring(err), "error")
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
                while State:Get("loading") do task.wait(0.2) end
            end

            local mode = State:Get("autoHopMode")
            local best = ServerManager.BestServer(mode)

            if best then
                joinServer(best)
                -- TeleportToPlaceInstance normalmente já desconecta o cliente;
                -- o cooldown abaixo é a rede de segurança caso o teleporte falhe.
            else
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
end

GlobalMaid:Add(function() AutoHop.Stop() end)

--====================================================
-- MAIN PANEL
--====================================================
local BASE_W, BASE_H = 760, 660
local MOBILE_BREAKPOINT = 560

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.Size = UDim2.new(0, BASE_W, 0, BASE_H)
Main.BackgroundColor3 = Theme.Panel
Main.BorderSizePixel = 0
Main.ClipsDescendants = false
Main.Parent = ScreenGui
Util.Round(Main, 18)
Util.Stroke(Main, Theme.Border, 1)

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.BackgroundTransparency = 1
Content.Size = UDim2.new(1, 0, 1, 0)
Content.ClipsDescendants = true
Content.Parent = Main
Util.Round(Content, 18)

local MainLayout = Instance.new("UIListLayout")
MainLayout.FillDirection = Enum.FillDirection.Vertical
MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
MainLayout.Parent = Content

--====================================================
-- HEADER (logo + título + settings + close)
--====================================================
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.BackgroundTransparency = 1
Header.Size = UDim2.new(1, 0, 0, 92)
Header.LayoutOrder = 1
Header.Parent = Content

-- Logo circular, "flutuando" acima do topo do painel
local LogoRing = Instance.new("Frame")
LogoRing.Name = "LogoRing"
LogoRing.AnchorPoint = Vector2.new(0.5, 0)
LogoRing.Position = UDim2.new(0.5, 0, 0, -30)
LogoRing.Size = UDim2.new(0, 60, 0, 60)
LogoRing.BackgroundColor3 = Theme.SurfaceAlt
LogoRing.ZIndex = 5
LogoRing.Parent = Header
Util.Round(LogoRing, 30)
Util.Stroke(LogoRing, Theme.Accent, 2)

local LogoText = Instance.new("TextLabel")
LogoText.BackgroundTransparency = 1
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.Text = "⚡"
LogoText.Font = Theme.FontBlack
LogoText.TextSize = 24
LogoText.TextColor3 = Theme.Accent
LogoText.ZIndex = 6
LogoText.Parent = LogoRing

local TitleRow = Instance.new("Frame")
TitleRow.Name = "TitleRow"
TitleRow.BackgroundTransparency = 1
TitleRow.AnchorPoint = Vector2.new(0.5, 0)
TitleRow.Position = UDim2.new(0.5, 0, 0, 40)
TitleRow.Size = UDim2.new(0, 320, 0, 30)
TitleRow.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size = UDim2.new(1, 0, 1, 0)
TitleLabel.Font = Theme.FontBlack
TitleLabel.TextSize = 22
TitleLabel.TextXAlignment = Enum.TextXAlignment.Center
TitleLabel.RichText = true
TitleLabel.Text = ("<font color=\"#%s\">LIGHT HOP</font> <font color=\"#%s\">PRO</font>  <font size=\"16\">⚙</font>")
    :format(Theme.Text:ToHex(), Theme.Accent:ToHex())
TitleLabel.Parent = TitleRow

local SettingsBtn = Instance.new("TextButton")
SettingsBtn.Name = "SettingsBtn"
SettingsBtn.AnchorPoint = Vector2.new(1, 0)
SettingsBtn.Position = UDim2.new(1, -56, 0, 16)
SettingsBtn.Size = UDim2.new(0, 34, 0, 34)
SettingsBtn.BackgroundColor3 = Theme.Surface
SettingsBtn.Text = "⚙"
SettingsBtn.TextSize = 16
SettingsBtn.TextColor3 = Theme.TextDim
SettingsBtn.Font = Theme.Font
SettingsBtn.AutoButtonColor = false
SettingsBtn.Parent = Header
Util.Round(SettingsBtn, 9)
Util.Stroke(SettingsBtn, Theme.BorderSoft, 1)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.AnchorPoint = Vector2.new(1, 0)
CloseBtn.Position = UDim2.new(1, -16, 0, 16)
CloseBtn.Size = UDim2.new(0, 34, 0, 34)
CloseBtn.BackgroundColor3 = Color3.fromRGB(70, 30, 30)
CloseBtn.Text = "✕"
CloseBtn.TextSize = 15
CloseBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
CloseBtn.Font = Theme.FontBold
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header
Util.Round(CloseBtn, 9)
Util.Stroke(CloseBtn, Theme.Danger, 1)

for _, btn in ipairs({ SettingsBtn, CloseBtn }) do
    local base = btn.BackgroundColor3
    btn.MouseEnter:Connect(function() Util.Tween(btn, { BackgroundColor3 = base:Lerp(Color3.new(1,1,1), 0.12) }, 0.1) end)
    btn.MouseLeave:Connect(function() Util.Tween(btn, { BackgroundColor3 = base }, 0.1) end)
end

--====================================================
-- FILTER BAR
--====================================================
local FilterBar = Instance.new("Frame")
FilterBar.Name = "FilterBar"
FilterBar.BackgroundTransparency = 1
FilterBar.Size = UDim2.new(1, -32, 0, 42)
FilterBar.LayoutOrder = 2
FilterBar.Parent = Content
Util.Pad(FilterBar, 16, 16, 0, 0)

local FilterLayout = Instance.new("UIListLayout")
FilterLayout.FillDirection = Enum.FillDirection.Horizontal
FilterLayout.Padding = UDim.new(0, 8)
FilterLayout.SortOrder = Enum.SortOrder.LayoutOrder
FilterLayout.Parent = FilterBar

local filterButtons = {}
local activeFilter = "ping"

local function styleFilterButton(btn, active)
    if active then
        btn.BackgroundColor3 = Theme.AccentDim
        btn.TextColor3 = Theme.Accent
        local stroke = btn:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = Theme.Accent end
    else
        btn.BackgroundColor3 = Theme.Surface
        btn.TextColor3 = Theme.TextDim
        local stroke = btn:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = Theme.BorderSoft end
    end
end

local function createFilterButton(key, text, widthGrow)
    local btn = Instance.new("TextButton")
    btn.Name = key
    btn.Size = UDim2.new(0, 0, 1, 0)
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.BackgroundColor3 = Theme.Surface
    btn.Font = Theme.FontBold
    btn.TextSize = 12
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = widthGrow
    btn.Parent = FilterBar
    Util.Round(btn, 9)
    Util.Stroke(btn, Theme.BorderSoft, 1)
    Util.Pad(btn, 14, 14, 0, 0)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0, 0, 1, 0)
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Font = Theme.FontBold
    label.TextSize = 12
    label.Text = text
    label.TextColor3 = Theme.TextDim
    label.Parent = btn

    btn.MouseButton1Click:Connect(function()
        if key == "advanced" then
            -- Ainda sem conteúdo funcional nesta etapa (fora do escopo pedido)
            Notify.Show("Filtro Avançado: em breve.", "info", 2)
            return
        end
        if State:Get("loading") or State:Get("sort") == key then return end
        activeFilter = key
        for k, b in pairs(filterButtons) do
            styleFilterButton(b.frame, k == activeFilter)
        end
        State:Set("sort", key)
        ServerManager.Fetch()
    end)

    filterButtons[key] = { frame = btn, label = label }
    return btn
end

createFilterButton("ping", "MENOR PING  📶", 1)
createFilterButton("empty", "MAIS VAZIOS  🚫", 2)
createFilterButton("players", "MAIS JOGADORES  👥", 3)
createFilterButton("advanced", "FILTRO AVANÇADO  ▾", 4)
styleFilterButton(filterButtons.ping.frame, true)
styleFilterButton(filterButtons.advanced.frame, true) -- refletindo o destaque duplo da referência
activeFilter = "ping"

--====================================================
-- STATUS ROW (contagem + loading + refresh)
--====================================================
local StatusRow = Instance.new("Frame")
StatusRow.Name = "StatusRow"
StatusRow.BackgroundTransparency = 1
StatusRow.Size = UDim2.new(1, -32, 0, 40)
StatusRow.LayoutOrder = 3
StatusRow.Parent = Content
Util.Pad(StatusRow, 16, 16, 8, 8)

local CountLabel = Instance.new("TextLabel")
CountLabel.BackgroundTransparency = 1
CountLabel.Size = UDim2.new(0.32, 0, 1, 0)
CountLabel.Font = Theme.Font
CountLabel.TextSize = 13
CountLabel.TextXAlignment = Enum.TextXAlignment.Left
CountLabel.TextColor3 = Theme.TextDim
CountLabel.Text = "servidores carregados 0"
CountLabel.Parent = StatusRow

local ProgressTrack = Instance.new("Frame")
ProgressTrack.AnchorPoint = Vector2.new(0.5, 0.5)
ProgressTrack.Position = UDim2.new(0.5, 0, 0.5, 0)
ProgressTrack.Size = UDim2.new(0.34, 0, 0, 6)
ProgressTrack.BackgroundColor3 = Theme.SurfaceAlt
ProgressTrack.BorderSizePixel = 0
ProgressTrack.Parent = StatusRow
Util.Round(ProgressTrack, 3)

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(0.6, 0, 1, 0)
ProgressFill.BackgroundColor3 = Theme.Blue
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressTrack
Util.Round(ProgressFill, 3)

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.AnchorPoint = Vector2.new(1, 0.5)
RefreshBtn.Position = UDim2.new(1, 0, 0.5, 0)
RefreshBtn.Size = UDim2.new(0, 96, 0, 30)
RefreshBtn.BackgroundColor3 = Theme.Surface
RefreshBtn.Font = Theme.FontBold
RefreshBtn.TextSize = 12
RefreshBtn.TextColor3 = Theme.Text
RefreshBtn.Text = "🔄  Refresh"
RefreshBtn.AutoButtonColor = false
RefreshBtn.Parent = StatusRow
Util.Round(RefreshBtn, 8)
Util.Stroke(RefreshBtn, Theme.BorderSoft, 1)

RefreshBtn.MouseEnter:Connect(function() Util.Tween(RefreshBtn, { BackgroundColor3 = Theme.SurfaceAlt }, 0.1) end)
RefreshBtn.MouseLeave:Connect(function() Util.Tween(RefreshBtn, { BackgroundColor3 = Theme.Surface }, 0.1) end)
RefreshBtn.MouseButton1Click:Connect(function()
    if State:Get("loading") then return end
    ServerManager.Fetch()
end)

--====================================================
-- SERVER LIST (ScrollingFrame)
--====================================================
local ListOuter = Instance.new("Frame")
ListOuter.Name = "ListOuter"
ListOuter.BackgroundTransparency = 1
ListOuter.Size = UDim2.new(1, -32, 1, -92-42-40-190)
ListOuter.LayoutOrder = 4
ListOuter.Parent = Content
Util.Pad(ListOuter, 16, 16, 0, 0)

local ListFrame = Instance.new("ScrollingFrame")
ListFrame.Name = "ListFrame"
ListFrame.BackgroundTransparency = 1
ListFrame.Size = UDim2.new(1, 0, 1, 0)
ListFrame.BorderSizePixel = 0
ListFrame.ScrollBarThickness = 4
ListFrame.ScrollBarImageColor3 = Theme.Accent
ListFrame.ScrollBarImageTransparency = 0.3
ListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ListFrame.Parent = ListOuter

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Padding = UDim.new(0, 8)
ListLayout.Parent = ListFrame

local EmptyLabel = Instance.new("TextLabel")
EmptyLabel.Name = "EmptyLabel"
EmptyLabel.BackgroundTransparency = 1
EmptyLabel.Size = UDim2.new(1, 0, 0, 60)
EmptyLabel.Font = Theme.Font
EmptyLabel.TextSize = 13
EmptyLabel.TextWrapped = true
EmptyLabel.TextColor3 = Theme.TextDim
EmptyLabel.Visible = false
EmptyLabel.Text = "Nenhum servidor disponível no momento."
EmptyLabel.Parent = ListFrame

--====================================================
-- SERVER CARD FACTORY
--====================================================
local function statusColor(status)
    if status == "Online" then return Theme.Good
    elseif status == "Cheio" then return Theme.Bad
    elseif status == "Instável" then return Theme.Medium
    elseif status == "Vazio" then return Theme.TextFaint
    end
    return Theme.TextDim
end

local function createServerCard(server)
    local card = Instance.new("Frame")
    card.Name = "Card_" .. server.id
    card.Size = UDim2.new(1, 0, 0, 92)
    card.BackgroundColor3 = Theme.Surface
    card.BorderSizePixel = 0
    card.LayoutOrder = server.rank
    card.ClipsDescendants = true
    card.Parent = ListFrame
    Util.Round(card, 12)
    Util.Stroke(card, Theme.BorderSoft, 1)
    Util.Pad(card, 16, 16, 0, 0)

    -- ===== Coluna 1: rank =====
    local RankLabel = Instance.new("TextLabel")
    RankLabel.BackgroundTransparency = 1
    RankLabel.AnchorPoint = Vector2.new(0, 0.5)
    RankLabel.Position = UDim2.new(0, 0, 0.5, 0)
    RankLabel.Size = UDim2.new(0, 46, 0, 40)
    RankLabel.Font = Theme.FontBlack
    RankLabel.TextSize = 18
    RankLabel.TextColor3 = Theme.TextFaint
    RankLabel.TextXAlignment = Enum.TextXAlignment.Left
    RankLabel.Text = "#" .. server.rank
    RankLabel.Parent = card

    -- ===== Coluna 2: jogadores + barra de ocupação =====
    local PlayersCol = Instance.new("Frame")
    PlayersCol.BackgroundTransparency = 1
    PlayersCol.AnchorPoint = Vector2.new(0, 0.5)
    PlayersCol.Position = UDim2.new(0, 54, 0.5, 0)
    PlayersCol.Size = UDim2.new(0, 110, 0, 46)
    PlayersCol.Parent = card

    local PlayersLabel = Instance.new("TextLabel")
    PlayersLabel.BackgroundTransparency = 1
    PlayersLabel.Size = UDim2.new(1, 0, 0, 22)
    PlayersLabel.Font = Theme.FontBold
    PlayersLabel.TextSize = 17
    PlayersLabel.TextXAlignment = Enum.TextXAlignment.Left
    PlayersLabel.TextColor3 = Theme.Text
    PlayersLabel.RichText = true
    PlayersLabel.Text = ("👥 %d <font color=\"#%s\">/ %d</font>"):format(server.playing, Theme.TextFaint:ToHex(), server.maxPlayers)
    PlayersLabel.Parent = PlayersCol

    local ratio = server.maxPlayers > 0 and (server.playing / server.maxPlayers) or 0
    local barTrack = Instance.new("Frame")
    barTrack.Position = UDim2.new(0, 0, 0, 28)
    barTrack.Size = UDim2.new(0, 84, 0, 5)
    barTrack.BackgroundColor3 = Theme.SurfaceAlt
    barTrack.BorderSizePixel = 0
    barTrack.Parent = PlayersCol
    Util.Round(barTrack, 3)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Util.OccupancyColor(ratio)
    barFill.BorderSizePixel = 0
    barFill.Parent = barTrack
    Util.Round(barFill, 3)
    Util.Tween(barFill, { Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0) }, 0.4)

    -- ===== Coluna 3: status / ping / fps / região =====
    local InfoCol = Instance.new("Frame")
    InfoCol.BackgroundTransparency = 1
    InfoCol.AnchorPoint = Vector2.new(0, 0.5)
    InfoCol.Position = UDim2.new(0, 182, 0.5, 0)
    InfoCol.Size = UDim2.new(1, -182-280, 1, -12)
    InfoCol.Parent = card

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Size = UDim2.new(1, 0, 0, 14)
    StatusLabel.Font = Theme.FontBold
    StatusLabel.TextSize = 10
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.TextColor3 = Theme.TextFaint
    StatusLabel.Text = "STATUS"
    StatusLabel.Parent = InfoCol

    local pingColor = Util.PingColor(server.ping)
    local StatusValue = Instance.new("TextLabel")
    StatusValue.BackgroundTransparency = 1
    StatusValue.Position = UDim2.new(0, 0, 0, 14)
    StatusValue.Size = UDim2.new(1, 0, 0, 18)
    StatusValue.Font = Theme.Font
    StatusValue.TextSize = 12
    StatusValue.TextXAlignment = Enum.TextXAlignment.Left
    StatusValue.RichText = true
    StatusValue.TextColor3 = Theme.TextDim
    StatusValue.Text = ("<font color=\"#%s\">📶 %s • Ping: %dms</font>   FPS: %d   Região: %s %s")
        :format(statusColor(server.status):ToHex(), server.status, server.ping, server.fps, server.region, server.flag)
    StatusValue.Parent = InfoCol

    local IdLabel = Instance.new("TextLabel")
    IdLabel.BackgroundTransparency = 1
    IdLabel.Position = UDim2.new(0, 0, 0, 34)
    IdLabel.Size = UDim2.new(1, 0, 0, 16)
    IdLabel.Font = Theme.Font
    IdLabel.TextSize = 11
    IdLabel.TextXAlignment = Enum.TextXAlignment.Left
    IdLabel.TextColor3 = Theme.TextFaint
    IdLabel.Text = "SERVER ID: " .. server.id
    IdLabel.Parent = InfoCol

    local pingDot = Instance.new("Frame")
    pingDot.AnchorPoint = Vector2.new(0, 0.5)
    pingDot.Position = UDim2.new(0, 0, 0, -2)
    pingDot.Size = UDim2.new(0, 6, 0, 6)
    pingDot.BackgroundColor3 = pingColor
    pingDot.BorderSizePixel = 0
    pingDot.Visible = false -- indicador redundante ocultado; cor já aplicada no texto acima
    pingDot.Parent = InfoCol

    -- ===== Coluna 4: ações (opções + join) =====
    local ActionsCol = Instance.new("Frame")
    ActionsCol.BackgroundTransparency = 1
    ActionsCol.AnchorPoint = Vector2.new(1, 0.5)
    ActionsCol.Position = UDim2.new(1, 0, 0.5, 0)
    ActionsCol.Size = UDim2.new(0, 260, 0, 40)
    ActionsCol.Parent = card

    local OptionsBtn = Instance.new("TextButton")
    OptionsBtn.AnchorPoint = Vector2.new(0, 0.5)
    OptionsBtn.Position = UDim2.new(0, 0, 0.5, 0)
    OptionsBtn.Size = UDim2.new(0, 38, 0, 38)
    OptionsBtn.BackgroundColor3 = Theme.SurfaceAlt
    OptionsBtn.Text = "⋯"
    OptionsBtn.TextSize = 18
    OptionsBtn.TextColor3 = Theme.TextDim
    OptionsBtn.Font = Theme.FontBold
    OptionsBtn.AutoButtonColor = false
    OptionsBtn.Parent = ActionsCol
    Util.Round(OptionsBtn, 9)
    Util.Stroke(OptionsBtn, Theme.BorderSoft, 1)
    OptionsBtn.MouseEnter:Connect(function() Util.Tween(OptionsBtn, { BackgroundColor3 = Theme.Border }, 0.1) end)
    OptionsBtn.MouseLeave:Connect(function() Util.Tween(OptionsBtn, { BackgroundColor3 = Theme.SurfaceAlt }, 0.1) end)
    OptionsBtn.MouseButton1Click:Connect(function()
        -- Sem conteúdo funcional definido para esta etapa (fora do escopo pedido)
        Notify.Show("Opções do servidor #" .. server.rank .. ": em breve.", "info", 2)
    end)

    local JoinBtn = Instance.new("TextButton")
    JoinBtn.AnchorPoint = Vector2.new(1, 0.5)
    JoinBtn.Position = UDim2.new(1, 0, 0.5, 0)
    JoinBtn.Size = UDim2.new(0, 148, 0, 40)
    JoinBtn.BackgroundColor3 = Theme.Accent
    JoinBtn.Text = "⚡  Join Server"
    JoinBtn.TextSize = 13
    JoinBtn.TextColor3 = Theme.AccentText
    JoinBtn.Font = Theme.FontBold
    JoinBtn.AutoButtonColor = false
    JoinBtn.Parent = ActionsCol
    Util.Round(JoinBtn, 10)
    JoinBtn.MouseEnter:Connect(function() Util.Tween(JoinBtn, { BackgroundColor3 = Theme.AccentHover }, 0.1) end)
    JoinBtn.MouseLeave:Connect(function() Util.Tween(JoinBtn, { BackgroundColor3 = Theme.Accent }, 0.1) end)
    JoinBtn.MouseButton1Click:Connect(function()
        Util.Tween(JoinBtn, { Size = UDim2.new(0, 140, 0, 36) }, 0.08)
        task.delay(0.08, function()
            if JoinBtn and JoinBtn.Parent then
                Util.Tween(JoinBtn, { Size = UDim2.new(0, 148, 0, 40) }, 0.12, Enum.EasingStyle.Back)
            end
        end)
        joinServer(server)
    end)

    -- entrada suave do card
    card.BackgroundTransparency = 1
    for _, d in ipairs(card:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then d.TextTransparency = 1 end
    end
    Util.Tween(card, { BackgroundTransparency = 0 }, 0.18)
    task.delay(0.02 * server.rank, function()
        if card and card.Parent then
            for _, d in ipairs(card:GetDescendants()) do
                if d:IsA("TextLabel") then Util.Tween(d, { TextTransparency = 0 }, 0.15)
                elseif d:IsA("TextButton") then Util.Tween(d, { TextTransparency = 0 }, 0.15) end
            end
        end
    end)

    return card
end

local function renderServerList(servers)
    for _, child in ipairs(ListFrame:GetChildren()) do
        if child:IsA("Frame") and child ~= EmptyLabel then
            child:Destroy()
        end
    end

    if #servers == 0 and not State:Get("loading") then
        EmptyLabel.Text = State:Get("errorText")
            and "Não foi possível carregar servidores. Toque em Refresh para tentar de novo."
            or "Nenhum servidor disponível no momento."
        EmptyLabel.Visible = true
    else
        EmptyLabel.Visible = false
        for i, server in ipairs(servers) do
            server.rank = i
            createServerCard(server)
        end
    end
end

-- Loading visual (barra "respirando" enquanto busca, como no script original)
local progressLoopThread = nil
local function setLoadingVisual(loading)
    if progressLoopThread then
        task.cancel(progressLoopThread)
        progressLoopThread = nil
    end
    if loading then
        CountLabel.Text = "Carregando servidores..."
        progressLoopThread = task.spawn(function()
            while true do
                Util.Tween(ProgressFill, { Size = UDim2.new(0.85, 0, 1, 0) }, 0.5)
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

--====================================================
-- BINDINGS: State -> UI (lista)
--====================================================
State:OnChange("loading", function(loading)
    setLoadingVisual(loading)
    RefreshBtn.AutoButtonColor = not loading
end)

State:OnChange("servers", function(servers)
    renderServerList(servers)
    if not State:Get("loading") then
        CountLabel.Text = ("servidores carregados %d"):format(#servers)
    end
end)

State:OnChange("errorText", function(errorText)
    if errorText then
        Notify.Show("Erro ao carregar servidores: " .. tostring(errorText), "error")
    end
end)

--====================================================
-- FOOTER: AUTO HOP
--====================================================
local Footer = Instance.new("Frame")
Footer.Name = "Footer"
Footer.BackgroundColor3 = Theme.Surface
Footer.Size = UDim2.new(1, 0, 0, 130)
Footer.LayoutOrder = 5
Footer.Parent = Content
Util.Pad(Footer, 16, 16, 14, 14)

local function makeSwitch(parent, initialOn)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 46, 0, 26)
    track.BackgroundColor3 = initialOn and Theme.Accent or Theme.SurfaceAlt
    track.BorderSizePixel = 0
    track.Parent = parent
    Util.Round(track, 13)
    Util.Stroke(track, Theme.BorderSoft, 1)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = initialOn and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    Util.Round(knob, 10)

    local on = initialOn
    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Parent = track

    local api = {}
    function api.Set(state)
        on = state
        Util.Tween(track, { BackgroundColor3 = on and Theme.Accent or Theme.SurfaceAlt }, 0.15)
        Util.Tween(knob, { Position = on and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) }, 0.15, Enum.EasingStyle.Back)
    end
    function api.Get() return on end
    btn.MouseButton1Click:Connect(function() api.Set(not on) end)
    api.Button = btn
    api.Frame = track
    return api
end

-- Linha 1: AUTO HOP | switch | modo (Melhor Ping / Mais Vazios)
local Row1 = Instance.new("Frame")
Row1.BackgroundTransparency = 1
Row1.Size = UDim2.new(1, 0, 0, 34)
Row1.LayoutOrder = 1
Row1.Parent = Footer

local AutoHopLabel = Instance.new("TextLabel")
AutoHopLabel.BackgroundTransparency = 1
AutoHopLabel.Size = UDim2.new(0, 100, 1, 0)
AutoHopLabel.Font = Theme.FontBold
AutoHopLabel.TextSize = 12
AutoHopLabel.TextXAlignment = Enum.TextXAlignment.Left
AutoHopLabel.TextColor3 = Theme.Text
AutoHopLabel.Text = "AUTO HOP"
AutoHopLabel.Parent = Row1

local autoHopSwitchHolder = Instance.new("Frame")
autoHopSwitchHolder.BackgroundTransparency = 1
autoHopSwitchHolder.Position = UDim2.new(0, 104, 0, 4)
autoHopSwitchHolder.Size = UDim2.new(0, 46, 0, 26)
autoHopSwitchHolder.Parent = Row1
local AutoHopSwitch = makeSwitch(autoHopSwitchHolder, true)
AutoHopSwitch.Frame.Position = UDim2.new(0, 0, 0, 0)

local modeButtons = {}
local autoHopMode = "ping"
local ModeHolder = Instance.new("Frame")
ModeHolder.BackgroundTransparency = 1
ModeHolder.Position = UDim2.new(0, 168, 0, 0)
ModeHolder.Size = UDim2.new(1, -168, 1, 0)
ModeHolder.Parent = Row1

local ModeLayout = Instance.new("UIListLayout")
ModeLayout.FillDirection = Enum.FillDirection.Horizontal
ModeLayout.Padding = UDim.new(0, 8)
ModeLayout.Parent = ModeHolder

local function styleModeButton(btn, active)
    if active then
        btn.BackgroundColor3 = Theme.AccentDim
        btn.TextColor3 = Theme.Accent
        btn:FindFirstChildOfClass("UIStroke").Color = Theme.Accent
    else
        btn.BackgroundColor3 = Theme.SurfaceAlt
        btn.TextColor3 = Theme.TextDim
        btn:FindFirstChildOfClass("UIStroke").Color = Theme.BorderSoft
    end
end

local function createModeButton(key, text)
    local btn = Instance.new("TextButton")
    btn.AutomaticSize = Enum.AutomaticSize.X
    btn.Size = UDim2.new(0, 0, 1, 0)
    btn.BackgroundColor3 = Theme.SurfaceAlt
    btn.Font = Theme.FontBold
    btn.TextSize = 11
    btn.Text = text
    btn.TextColor3 = Theme.TextDim
    btn.AutoButtonColor = false
    btn.Parent = ModeHolder
    Util.Round(btn, 8)
    Util.Stroke(btn, Theme.BorderSoft, 1)
    Util.Pad(btn, 12, 12, 0, 0)
    btn.MouseButton1Click:Connect(function()
        autoHopMode = key
        for k, b in pairs(modeButtons) do styleModeButton(b, k == autoHopMode) end
        State:Set("autoHopMode", key)
    end)
    modeButtons[key] = btn
    return btn
end

createModeButton("ping", "MELHOR PING  📶")
createModeButton("empty", "MAIS VAZIOS  🚫")
styleModeButton(modeButtons.ping, true)

-- Linha 2: MODO ATIVO | switch | barra "Auto Hop (Melhor Ping)"
local Row2 = Instance.new("Frame")
Row2.BackgroundTransparency = 1
Row2.Size = UDim2.new(1, 0, 0, 40)
Row2.Position = UDim2.new(0, 0, 0, 46)
Row2.LayoutOrder = 2
Row2.Parent = Footer

local ModoAtivoLabel = Instance.new("TextLabel")
ModoAtivoLabel.BackgroundTransparency = 1
ModoAtivoLabel.Size = UDim2.new(0, 100, 1, 0)
ModoAtivoLabel.Font = Theme.FontBold
ModoAtivoLabel.TextSize = 12
ModoAtivoLabel.TextXAlignment = Enum.TextXAlignment.Left
ModoAtivoLabel.TextColor3 = Theme.Text
ModoAtivoLabel.Text = "MODO ATIVO"
ModoAtivoLabel.Parent = Row2

local modoAtivoSwitchHolder = Instance.new("Frame")
modoAtivoSwitchHolder.BackgroundTransparency = 1
modoAtivoSwitchHolder.Position = UDim2.new(0, 104, 0, 7)
modoAtivoSwitchHolder.Size = UDim2.new(0, 46, 0, 26)
modoAtivoSwitchHolder.Parent = Row2
local ModoAtivoSwitch = makeSwitch(modoAtivoSwitchHolder, true)
ModoAtivoSwitch.Frame.Position = UDim2.new(0, 0, 0, 0)

local ActiveBar = Instance.new("Frame")
ActiveBar.Position = UDim2.new(0, 168, 0, 0)
ActiveBar.Size = UDim2.new(1, -168-40, 1, 0)
ActiveBar.BackgroundColor3 = Theme.Accent
ActiveBar.Parent = Row2
Util.Round(ActiveBar, 9)

local ActiveLabel = Instance.new("TextLabel")
ActiveLabel.BackgroundTransparency = 1
ActiveLabel.Size = UDim2.new(1, 0, 1, 0)
ActiveLabel.Font = Theme.FontBold
ActiveLabel.TextSize = 13
ActiveLabel.TextColor3 = Theme.AccentText
ActiveLabel.Text = "✓  Auto Hop (Melhor Ping)"
ActiveLabel.Parent = ActiveBar

local ActiveGear = Instance.new("TextButton")
ActiveGear.AnchorPoint = Vector2.new(1, 0.5)
ActiveGear.Position = UDim2.new(1, 0, 0.5, 0)
ActiveGear.Size = UDim2.new(0, 34, 0, 34)
ActiveGear.BackgroundColor3 = Theme.SurfaceAlt
ActiveGear.Text = "⚙"
ActiveGear.TextSize = 14
ActiveGear.TextColor3 = Theme.TextDim
ActiveGear.Font = Theme.Font
ActiveGear.AutoButtonColor = false
ActiveGear.Parent = Row2
Util.Round(ActiveGear, 9)
Util.Stroke(ActiveGear, Theme.BorderSoft, 1)

-- atualiza texto do "modo ativo" quando o modo muda
local function refreshActiveLabel()
    local modeName = autoHopMode == "ping" and "Melhor Ping" or "Mais Vazios"
    ActiveLabel.Text = ("✓  Auto Hop (%s)"):format(modeName)
end
for key, btn in pairs(modeButtons) do
    btn.MouseButton1Click:Connect(refreshActiveLabel)
end

-- Os dois switches (AUTO HOP e MODO ATIVO) controlam o mesmo AutoHop real,
-- ficando sempre sincronizados entre si e com o State.
local function refreshAutoHopVisual()
    local on = State:Get("autoHopOn")
    if AutoHopSwitch.Get() ~= on then AutoHopSwitch.Set(on) end
    if ModoAtivoSwitch.Get() ~= on then ModoAtivoSwitch.Set(on) end
    Util.Tween(ActiveBar, { BackgroundTransparency = on and 0 or 0.6 }, 0.15)
    ActiveLabel.Text = on and ActiveLabel.Text or "Auto Hop desativado"
    if on then refreshActiveLabel() end
end

AutoHopSwitch.Button.MouseButton1Click:Connect(function()
    if AutoHopSwitch.Get() then AutoHop.Start() else AutoHop.Stop() end
end)
ModoAtivoSwitch.Button.MouseButton1Click:Connect(function()
    if ModoAtivoSwitch.Get() then AutoHop.Start() else AutoHop.Stop() end
end)

State:OnChange("autoHopOn", refreshAutoHopVisual)

--====================================================
-- TOGGLE FLUTUANTE (abrir/fechar painel) — arrastável
--====================================================
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 54, 0, 54)
ToggleBtn.Position = UDim2.new(0, 24, 0.68, 0)
ToggleBtn.BackgroundColor3 = Theme.Panel
ToggleBtn.Text = "LH"
ToggleBtn.Font = Theme.FontBlack
ToggleBtn.TextSize = 15
ToggleBtn.TextColor3 = Theme.Accent
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = ScreenGui
Util.Round(ToggleBtn, 14)
Util.Stroke(ToggleBtn, Theme.Accent, 2)

do
    local dragging, moved, dragStart, startPos = false, false, nil, nil
    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
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
                ToggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end))
    ToggleBtn.MouseButton1Click:Connect(function()
        if moved then return end
        local open = not Main.Visible
        if open then
            Main.Visible = true
            Main.Size = UDim2.new(0, 0, 0, 0)
            local w, h = Main:GetAttribute("_w") or BASE_W, Main:GetAttribute("_h") or BASE_H
            Util.Tween(Main, { Size = UDim2.new(0, w, 0, h) }, 0.22, Enum.EasingStyle.Back)
        else
            local w, h = Main.Size.X.Offset, Main.Size.Y.Offset
            Main:SetAttribute("_w", w)
            Main:SetAttribute("_h", h)
            local tw = Util.Tween(Main, { Size = UDim2.new(0, 0, 0, 0) }, 0.18)
            tw.Completed:Connect(function() Main.Visible = false end)
        end
    end)
end

CloseBtn.MouseButton1Click:Connect(function()
    local tw = Util.Tween(Main, { Size = UDim2.new(0, 0, 0, 0) }, 0.18)
    tw.Completed:Connect(function() Main.Visible = false end)
end)

-- Arrastar painel pelo header
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
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

--====================================================
-- RESPONSIVIDADE (desktop <-> mobile)
--====================================================
local function applyResponsiveLayout()
    local viewport = ScreenGui.AbsoluteSize
    local isMobile = viewport.X <= MOBILE_BREAKPOINT

    if isMobile then
        -- Painel ocupa quase toda a tela, cards e footer se ajustam via AutomaticSize/Scale já existentes
        Main.Size = UDim2.new(0.94, 0, 0.82, 0)
        Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    else
        Main.Size = UDim2.new(0, BASE_W, 0, BASE_H)
        Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
end

GlobalMaid:Add(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout))
applyResponsiveLayout()

--====================================================
-- ENTRADA (animação inicial do painel)
--====================================================
Main.Size = UDim2.new(0, 0, 0, 0)
task.defer(function()
    local w = (ScreenGui.AbsoluteSize.X <= MOBILE_BREAKPOINT) and math.floor(ScreenGui.AbsoluteSize.X * 0.94) or BASE_W
    local h = (ScreenGui.AbsoluteSize.X <= MOBILE_BREAKPOINT) and math.floor(ScreenGui.AbsoluteSize.Y * 0.82) or BASE_H
    Util.Tween(Main, { Size = UDim2.new(0, w, 0, h) }, 0.28, Enum.EasingStyle.Back)
end)

--====================================================
-- CLEANUP
--====================================================
GlobalMaid:Add(Players.PlayerRemoving:Connect(function(p)
    if p == LocalPlayer then GlobalMaid:Cleanup() end
end))

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Light Hop Pro",
        Text = "Interface carregada. Buscando servidores...",
        Duration = 3,
    })
end)

ServerManager.Fetch()
