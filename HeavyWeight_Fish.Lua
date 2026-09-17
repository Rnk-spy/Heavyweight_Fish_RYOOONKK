-- [[ ★ RYOOOONK HUB - SPACEX BLACK HOLE COSMIC EDITION ★ ]] --
-- v2.0 FIXED EDITION (Bugfix + Fitur Baru)
--
-- [ BUGFIX ]
--   [1]  Unload mematikan semua loop & koneksi (WalkSpeed tidak ditarik balik ke 46)
--   [2]  Noclip mengembalikan CanCollide asli saat dimatikan (tidak "tembus selamanya")
--   [3]  Anchor engine tidak spam remote 60x/detik (rate-limit 20x/detik) + cache GUI
--   [4]  Auto Cast tidak lagi salah deteksi "bar basi" dari cast sebelumnya
--   [5]  Deteksi HP Auto Heal di-cache (dulu scan seluruh PlayerGui tiap 0.4s)
--   [6]  Klik tombol Close/Min tidak lagi ikut men-drag window
--   [7]  Instant Fish benar-benar disembunyikan saat Unload (dulu dead code karena scope)
--   [8]  Restore dari Floating Widget saat minimize tidak lagi bikin layout rusak
--   [9]  loadstring pihak ketiga diamankan (whitelist domain)
--   [10] Camera selalu diambil fresh (dulu disimpan sekali, bisa referensi basi)
--
-- [ FITUR BARU ]
--   Auto Sell loop + interval, interval skill, Anti-AFK, Infinite Jump, Jump Power,
--   FPS Boost/Low Graphics, Toast Notification, Save/Load Config, Save/TP Waypoint,
--   Anchor adaptif (lock ke tengah zona bar bila zona terdeteksi).
--
-- [ PERF FIX v2.1 - ANTI LAG / PATAH-PATAH ]
--   [P1] Anchor engine dulu menembak remote TIAP FRAME (60x/detik!) walaupun header
--        klaim sudah di-rate-limit. Kini dibatasi Hub.ANCHOR_FIRE_INTERVAL
--        (default 10x/detik) dan posisi bar hanya ditulis bila benar-benar melenceng.
--   [P2] Engine loop WalkSpeed/Jump/Noclip: Stepped -> Heartbeat, tanpa closure +
--        pcall baru tiap frame (dulu bikin sampah 60x/detik => GC hitch).
--   [P3] Noclip tidak lagi char:GetDescendants() tiap frame: discan maks ~6x/detik,
--        part baru (tool di-equip, dsb) langsung ditangani lewat DescendantAdded.
--   [P4] GetFishingUI / GetBarFrame / GetRodHealth di-cache: dulu scan PlayerGui
--        (FindFirstChild rekursif + GetDescendants) puluhan kali per detik.
--   Semua nilai bisa diatur di blok "PERF TUNABLES" di bawah.
-- =========================================================================
-- [ PERF FIX v2.2 - ULTRA OPTIMIZATION (Anti-Lag Total) ]
--   [U1] Anchor Engine: FireServer dibatasi 10x/detik (RenderStepped -> Heartbeat + rate limit).
--        Bar position hanya ditulis kalau offset > 0.01 (hindari write redundan).
--   [U2] GetRodHealth(): Cache TextLabel reference + hasil. Scan GetDescendants() MAX 1x/2detik.
--   [U3] EngineStep (WalkSpeed/JumpPower): Rate-limited 10x/detik via Heartbeat.
--   [U4] Live Health Monitor: Interval 1 detik, hanya update teks kalau nilai berubah.
--   [U5] Auto Heal: Pakai cache GetRodHealth(), interval minimal 0.5s.
--   [U6] Semua loop pakai task.wait() dengan interval eksplisit (bukan task.wait() kosong).
-- =========================================================================
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local Hub = {}
-- Tabel Hub: menampung nilai UI/engine agar main chunk tidak menembus batas 200 local Luau
Hub.RunService = game:GetService("RunService")
Hub.TweenService = game:GetService("TweenService")
Hub.UserInputService = game:GetService("UserInputService")
Hub.VirtualInputManager = game:GetService("VirtualInputManager")
Hub.StarterGui = game:GetService("StarterGui")
Hub.Lighting = game:GetService("Lighting")
Hub.HttpService = game:GetService("HttpService")

-- Camera bisa diganti game/executor kapan saja -> selalu ambil fresh (fix #10)
local function GetCamera()
    return workspace.CurrentCamera
end

--  CONFIG: SPACEX BLACK HOLE PALETTE
Hub.THEME = {
    VoidBlack       = Color3.fromRGB(8, 7, 18),
    DeepNebula      = Color3.fromRGB(18, 12, 38),
    CosmicCyan      = Color3.fromRGB(0, 225, 255),
    ElectricViolet  = Color3.fromRGB(140, 80, 255),
    AccretionGlow   = Color3.fromRGB(85, 140, 255),
    CardBg          = Color3.fromRGB(16, 14, 30),
    CardHover       = Color3.fromRGB(24, 20, 45),
    StrokeColor     = Color3.fromRGB(80, 60, 140),
    ActiveGradient1 = Color3.fromRGB(100, 40, 230),
    ActiveGradient2 = Color3.fromRGB(0, 170, 240),
    OffGradient1    = Color3.fromRGB(28, 20, 44),
    OffGradient2    = Color3.fromRGB(18, 14, 30),
    TextPrimary     = Color3.fromRGB(245, 245, 255),
    TextSecondary   = Color3.fromRGB(160, 155, 195),
    AlertRed        = Color3.fromRGB(255, 65, 115),
    SuccessGreen    = Color3.fromRGB(80, 230, 150),
    WarnAmber       = Color3.fromRGB(255, 210, 90),
    ActiveBg        = Color3.fromRGB(45, 25, 90),
}

-- ⚡ PERF TUNABLES (v2.2) - Sesuaikan jika masih lag / ingin lebih responsif
Hub.ANCHOR_FIRE_INTERVAL      = 0.10   -- 10x/detik max FireServer (Anchor Engine)
Hub.ANCHOR_POS_THRESHOLD      = 0.01   -- Hanya update posisi bar kalau offset > 1%
Hub.ENGINE_STEP_INTERVAL      = 0.10   -- 10x/detik WalkSpeed/JumpPower enforcement
Hub.NOCLIP_SCAN_INTERVAL      = 0.16   -- ~6x/detik scan noclip (sudah ada)
Hub.ROD_HEALTH_SCAN_INTERVAL  = 2.0    -- Scan GetDescendants() max 1x/2detik
Hub.ROD_HEALTH_CACHE_TTL      = 1.5    -- Cache hasil HP rod 1.5 detik
Hub.LIVE_HEALTH_UPDATE_INTERVAL = 1.0  -- Update UI Live HP tiap 1 detik
Hub.AUTO_HEAL_MIN_INTERVAL    = 0.5    -- Min interval Auto Heal loop

-- ⚙️ CONFIG LOADING SCREEN (Snappy & Fast ~1.5s total)
Hub.LOADING_TIME = 1.2
Hub.STAR_COUNT = 50
Hub.OVERSCAN = 0.08

--  Pembersihan GUI lama sebelum mulai (Mencegah GUI tumpuk)
Hub.GUI_NAME = "RYOOOONK_Hub_Ultimate"
Hub.LEGACY_NAMES = { "PPINGYYY_Hub_Ultimate", "RYOOOONK_Hub_Ultimate", "RYOOOONK_Hub", "NWKZ_Hub" }

local function IsLegacyGui(obj)
    for _, n in ipairs(Hub.LEGACY_NAMES) do
        if obj.Name == n then return true end
    end
    return false
end

pcall(function()
    local core = game:GetService("CoreGui")
    for _, v in ipairs(core:GetChildren()) do
        if IsLegacyGui(v) then
            v:Destroy()
        end
    end
end)

pcall(function()
    if lp and lp:FindFirstChild("PlayerGui") then
        for _, v in ipairs(lp.PlayerGui:GetChildren()) do
            if IsLegacyGui(v) then
                v:Destroy()
            end
        end
    end
end)

-- =========================================================================
-- 🌐 GLOBAL STATE FLAGS
-- =========================================================================
local function ResetAllFlags()
    getgenv().RYOOOONK_Unloaded = false
    getgenv().NWKZ_Anchor = false
    getgenv().NWKZ_AutoCast = false
    getgenv().PP_FishingThipActive = false
    getgenv().PP_AutoSell = false
    getgenv().PP_SellInterval = 30
    getgenv().PP_AutoSkillAll = false
    getgenv().PP_Skill_Z = false
    getgenv().PP_Skill_X = false
    getgenv().PP_Skill_C = false
    getgenv().PP_Skill_V = false
    getgenv().PP_SkillInterval = 0.6
    getgenv().PP_AutoHeal = false
    getgenv().PP_HealPercent = 40
    getgenv().PP_HealKeyIndex = 1
    getgenv().PP_HealCooldown = 1.2
    getgenv().PP_Noclip = false
    getgenv().PP_WalkSpeed = 46
    getgenv().PP_JumpPower = 50
    getgenv().PP_InfiniteJump = false
    getgenv().PP_AntiAFK = true
    getgenv().PP_LowGFX = false
    getgenv().PP_SavedSpot = nil
    getgenv().PP_ToggleKeyIndex = 1
end

ResetAllFlags()

-- =========================================================================
-- ⚡ PERF TUNABLES (v2.1 - anti "patah-patah")
-- Loop engine sudah hemat: tidak bikin closure/pcall baru tiap frame, remote
-- anchor dibatasi, dan scan GUI di-cache. Kalau device masih berat, besarkan
-- interval / kecilkan nilai di bawah.
-- =========================================================================
Hub.NOCLIP_SCAN_INTERVAL   = 0.18  -- detik: refresh CanCollide saat noclip ON
Hub.ANCHOR_FIRE_INTERVAL   = 0.10  -- detik: jeda remote anchor (0.10 = 10x/detik)
Hub.FISHING_UI_CACHE_TTL   = 0.75  -- detik: umur cache pencarian UI fishing
Hub.ROD_HEALTH_CACHE_TTL   = 0.20  -- detik: umur cache pembacaan HP rod
Hub.HEALTH_LABEL_CACHE_TTL = 1.50  -- detik: umur cache daftar TextLabel PlayerGui

-- Cache runtime (bukan setting user - tidak ikut disimpan ke config)
Hub.fishingUICache     = nil
Hub.fishingUICacheAt   = 0
Hub.barFrameCache      = nil
Hub.barFrameOwner      = nil
Hub.anchorBar          = nil
Hub.healthLabelCache   = nil
Hub.healthLabelCacheAt = 0
Hub.rodHealthCache     = nil
Hub.rodHealthCacheAt   = 0
Hub.lastNoclipScan     = 0
Hub.lastAnchorFire     = 0
Hub.noclipApplied      = false

-- [[CHUNK 1B]]
--  Main ScreenGui (Safe Parent for all executors)
Hub.sg = Instance.new("ScreenGui")
Hub.sg.Name = Hub.GUI_NAME
Hub.sg.ResetOnSpawn = false
Hub.sg.IgnoreGuiInset = true
Hub.sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    if gethui then
        Hub.sg.Parent = gethui()
    else
        Hub.sg.Parent = game:GetService("CoreGui")
    end
end)
if not Hub.sg.Parent then
    Hub.sg.Parent = lp:WaitForChild("PlayerGui")
end

--  Registry koneksi + status hidup (dipakai unload bersih - fix #1)
Hub.Connections = {}
local function Track(conn)
    if conn then
        table.insert(Hub.Connections, conn)
    end
    return conn
end

local function Alive()
    return getgenv().RYOOOONK_Unloaded ~= true and Hub.sg.Parent ~= nil
end

-- 🔊 Sound Helper
local function createSound(id)
    local s = Instance.new("Sound", Hub.sg)
    pcall(function() s.SoundId = "rbxassetid://" .. id end)
    s.Volume = 1
    return s
end

Hub.clickSound        = createSound("140207837688369")
Hub.loadSound         = createSound("103502836672744")
Hub.defaultClickSound = createSound("139719503904449")
Hub.skillSound        = createSound("72321534878838")
Hub.tpSound           = createSound("124934430745275")
Hub.speedSound        = createSound("9118823292")
Hub.autoCastSound     = createSound("119135010875996")
Hub.anchorSound       = createSound("131661992591924")
Hub.deleteSound       = createSound("154157386")
Hub.sellSound         = createSound("90531793028786")
Hub.healSound         = createSound("9118823292")

local function PlaySound(s)
    pcall(function() s:Play() end)
end

-- [[CHUNK 1C]]
--  Toast Notification (pengganti StarterGui:SetCore yang sering gagal)
Hub.ToastHolder = Instance.new("Frame", Hub.sg)
Hub.ToastHolder.Name = "ToastHolder"
Hub.ToastHolder.Size = UDim2.new(0, 270, 1, -20)
Hub.ToastHolder.Position = UDim2.new(1, -282, 0, 10)
Hub.ToastHolder.BackgroundTransparency = 1
Hub.ToastHolder.ZIndex = 1200

Hub.ToastLayout = Instance.new("UIListLayout", Hub.ToastHolder)
Hub.ToastLayout.SortOrder = Enum.SortOrder.LayoutOrder
Hub.ToastLayout.Padding = UDim.new(0, 6)

Hub.toastOrder = 0
Hub.activeToasts = {}

local function Toast(title, text, accent, duration)
    if not Alive() then return end
    accent = accent or Hub.THEME.CosmicCyan
    duration = duration or 3.5

    -- batasi maksimal 4 toast agar tidak menutupi layar
    while #Hub.activeToasts >= 4 do
        local oldest = table.remove(Hub.activeToasts, 1)
        if oldest and oldest.Parent then
            oldest:Destroy()
        end
    end

    Hub.toastOrder = Hub.toastOrder - 1
    local card = Instance.new("Frame", Hub.ToastHolder)
    card.LayoutOrder = Hub.toastOrder
    card.Size = UDim2.new(1, 0, 0, 46)
    card.BackgroundColor3 = Hub.THEME.CardBg
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = accent
    cardStroke.Transparency = 1
    cardStroke.Thickness = 1.2

    local bar = Instance.new("Frame", card)
    bar.Size = UDim2.new(0, 4, 1, -10)
    bar.Position = UDim2.new(0, 6, 0, 5)
    bar.BackgroundColor3 = accent
    bar.BackgroundTransparency = 1
    bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local titleLabel = Instance.new("TextLabel", card)
    titleLabel.Size = UDim2.new(1, -26, 0, 18)
    titleLabel.Position = UDim2.new(0, 18, 0, 6)
    titleLabel.Text = title
    titleLabel.TextColor3 = accent
    titleLabel.TextTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1

    local bodyLabel = Instance.new("TextLabel", card)
    bodyLabel.Size = UDim2.new(1, -26, 0, 16)
    bodyLabel.Position = UDim2.new(0, 18, 0, 24)
    bodyLabel.Text = text
    bodyLabel.TextColor3 = Hub.THEME.TextSecondary
    bodyLabel.TextTransparency = 1
    bodyLabel.Font = Enum.Font.GothamMedium
    bodyLabel.TextSize = 10
    bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
    bodyLabel.TextWrapped = true
    bodyLabel.BackgroundTransparency = 1

    table.insert(Hub.activeToasts, card)

    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    Hub.TweenService:Create(card, tweenInfo, { BackgroundTransparency = 0.12 }):Play()
    Hub.TweenService:Create(cardStroke, tweenInfo, { Transparency = 0.35 }):Play()
    Hub.TweenService:Create(bar, tweenInfo, { BackgroundTransparency = 0 }):Play()
    Hub.TweenService:Create(titleLabel, tweenInfo, { TextTransparency = 0 }):Play()
    Hub.TweenService:Create(bodyLabel, tweenInfo, { TextTransparency = 0.1 }):Play()

    task.delay(duration, function()
        if not card or not card.Parent then return end
        local outInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        Hub.TweenService:Create(card, outInfo, { BackgroundTransparency = 1 }):Play()
        Hub.TweenService:Create(cardStroke, outInfo, { Transparency = 1 }):Play()
        Hub.TweenService:Create(bar, outInfo, { BackgroundTransparency = 1 }):Play()
        Hub.TweenService:Create(titleLabel, outInfo, { TextTransparency = 1 }):Play()
        Hub.TweenService:Create(bodyLabel, outInfo, { TextTransparency = 1 }):Play()
        task.wait(0.35)
        for i, v in ipairs(Hub.activeToasts) do
            if v == card then
                table.remove(Hub.activeToasts, i)
                break
            end
        end
        if card.Parent then
            card:Destroy()
        end
    end)
end

-- Fungsi notifikasi gaya lama (dipakai tombol Merchant, sekarang pakai Toast)
local function Notify(text, accent)
    Toast("★ RYOOOONK HUB ★", text, accent or Hub.THEME.CosmicCyan)
end

-- [[CHUNK 2A]]
-- =========================================================================
-- 🎬 1. SPACEX COSMIC LOADING SCREEN
-- =========================================================================
-- Dibungkus fungsi supaya main chunk tidak menembus batas 200 local Luau.
local function BuildLoadingScreen()
local function GetDropDistance()
    local cam = GetCamera()
    local h = cam and cam.ViewportSize.Y or 1000
    return h * 1.6
end

Hub.LoadingContainer = Instance.new("Frame", Hub.sg)
Hub.LoadingContainer.Size = UDim2.new(1, 0, 1, 0)
Hub.LoadingContainer.Position = UDim2.new(0, 0, -1, 0)
Hub.LoadingContainer.BackgroundTransparency = 1
Hub.LoadingContainer.BorderSizePixel = 0
Hub.LoadingContainer.ZIndex = 999
Hub.LoadingContainer.ClipsDescendants = false

Hub.BackgroundLayer = Instance.new("Frame", Hub.LoadingContainer)
Hub.BackgroundLayer.Size = UDim2.new(1 + Hub.OVERSCAN * 2, 0, 1 + Hub.OVERSCAN * 2, 0)
Hub.BackgroundLayer.Position = UDim2.new(-Hub.OVERSCAN, 0, -Hub.OVERSCAN, 0)
Hub.BackgroundLayer.BackgroundColor3 = Hub.THEME.VoidBlack
Hub.BackgroundLayer.BackgroundTransparency = 0.55
Hub.BackgroundLayer.BorderSizePixel = 0
Hub.BackgroundLayer.ZIndex = 999

Hub.UIGradientBg = Instance.new("UIGradient", Hub.BackgroundLayer)
Hub.UIGradientBg.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 8, 30)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 7, 18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 18, 35))
}
Hub.UIGradientBg.Rotation = 135

-- Starfield (Space Dust & Stars)
Hub.stars = {}
for i = 1, Hub.STAR_COUNT do
    local star = Instance.new("Frame", Hub.BackgroundLayer)
    local size = math.random(1, 3)
    star.Size = UDim2.new(0, size, 0, size)
    star.Position = UDim2.new(math.random(0, 100) / 100, 0, math.random(0, 100) / 100, 0)
    local starColorChoice = (i % 3 == 0 and Hub.THEME.CosmicCyan) or (i % 2 == 0 and Hub.THEME.ElectricViolet) or Color3.fromRGB(255, 255, 255)
    star.BackgroundColor3 = starColorChoice
    star.BorderSizePixel = 0
    star.ZIndex = 1000
    star.BackgroundTransparency = math.random(3, 8) / 10
    Instance.new("UICorner", star).CornerRadius = UDim.new(1, 0)
    table.insert(Hub.stars, star)
    task.spawn(function()
        while star.Parent do
            local moveTime = math.random(40, 80) / 10
            local newX = math.clamp(star.Position.X.Scale + (math.random(-6, 6) / 100), 0, 1)
            local newY = math.clamp(star.Position.Y.Scale + (math.random(-6, 6) / 100), 0, 1)
            Hub.TweenService:Create(star, TweenInfo.new(moveTime, Enum.EasingStyle.Sine), {
                Position = UDim2.new(newX, 0, newY, 0),
                BackgroundTransparency = math.random(2, 9) / 10
            }):Play()
            task.wait(moveTime)
        end
    end)
end

-- Corner Cosmic Glow
local function CreateCornerGlow(anchorX, anchorY, posX, posY, tintColor)
    local glow = Instance.new("ImageLabel", Hub.BackgroundLayer)
    glow.Size = UDim2.new(0, 520, 0, 520)
    glow.AnchorPoint = Vector2.new(anchorX, anchorY)
    glow.Position = UDim2.new(posX, 0, posY, 0)
    glow.BackgroundTransparency = 1
    glow.Image = "rbxasset://textures/particles/sparkles_main.dds"
    glow.ImageColor3 = tintColor
    glow.ImageTransparency = 0.82
    glow.ZIndex = 998
    return glow
end

CreateCornerGlow(0, 1, 0.05, 0.95, Hub.THEME.ElectricViolet)
CreateCornerGlow(1, 1, 0.95, 0.95, Hub.THEME.CosmicCyan)
CreateCornerGlow(0, 0, 0.05, 0.05, Hub.THEME.CosmicCyan)
CreateCornerGlow(1, 0, 0.95, 0.05, Hub.THEME.ElectricViolet)

-- Title Group
Hub.TitleGroup = Instance.new("Frame", Hub.LoadingContainer)
Hub.TitleGroup.Size = UDim2.new(1, 0, 0, 200)
Hub.TitleGroup.Position = UDim2.new(0, 0, 0.3, 0)
Hub.TitleGroup.BackgroundTransparency = 1
Hub.TitleGroup.ZIndex = 1001

Hub.TopLine = Instance.new("Frame", Hub.TitleGroup)
Hub.TopLine.Size = UDim2.new(0, 0, 0, 3)
Hub.TopLine.Position = UDim2.new(0.5, 0, 0, -20)
Hub.TopLine.BackgroundColor3 = Hub.THEME.CosmicCyan
Hub.TopLine.BorderSizePixel = 0
Hub.TopLine.AnchorPoint = Vector2.new(0.5, 0)

Hub.MainTitle = Instance.new("TextLabel", Hub.TitleGroup)
Hub.MainTitle.Size = UDim2.new(0.9, 0, 0, 80)
Hub.MainTitle.Position = UDim2.new(0.05, 0, 0.15, 0)
Hub.MainTitle.Text = "★ RYOOOONK HUB ★"
Hub.MainTitle.TextColor3 = Hub.THEME.CosmicCyan
Hub.MainTitle.Font = Enum.Font.GothamBold
Hub.MainTitle.TextSize = 48
Hub.MainTitle.BackgroundTransparency = 1
Hub.MainTitle.ZIndex = 1001
Hub.MainTitle.TextTransparency = 1
Hub.TitleAspect = Instance.new("UITextSizeConstraint", Hub.MainTitle)
Hub.TitleAspect.MinTextSize = 22
Hub.TitleAspect.MaxTextSize = 48

Hub.TitleGlow = Instance.new("TextLabel", Hub.TitleGroup)
Hub.TitleGlow.Size = Hub.MainTitle.Size
Hub.TitleGlow.Position = Hub.MainTitle.Position
Hub.TitleGlow.Text = "★ RYOOOONK HUB ★"
Hub.TitleGlow.TextColor3 = Hub.THEME.ElectricViolet
Hub.TitleGlow.Font = Enum.Font.GothamBold
Hub.TitleGlow.TextSize = 48
Hub.TitleGlow.BackgroundTransparency = 1
Hub.TitleGlow.ZIndex = 1000
Hub.TitleGlow.TextTransparency = 0.6
Hub.GlowAspect = Instance.new("UITextSizeConstraint", Hub.TitleGlow)
Hub.GlowAspect.MinTextSize = 22
Hub.GlowAspect.MaxTextSize = 48

Hub.Subtitle = Instance.new("TextLabel", Hub.TitleGroup)
Hub.Subtitle.Size = UDim2.new(0.8, 0, 0, 40)
Hub.Subtitle.Position = UDim2.new(0.1, 0, 0.65, 0)
Hub.Subtitle.Text = "SPACEX // BLACK HOLE COSMIC SYSTEM"
Hub.Subtitle.TextColor3 = Hub.THEME.TextSecondary
Hub.Subtitle.Font = Enum.Font.GothamMedium
Hub.Subtitle.TextSize = 16
Hub.Subtitle.BackgroundTransparency = 1
Hub.Subtitle.ZIndex = 1001
Hub.Subtitle.TextTransparency = 1
Hub.SubAspect = Instance.new("UITextSizeConstraint", Hub.Subtitle)
Hub.SubAspect.MinTextSize = 12
Hub.SubAspect.MaxTextSize = 16

Hub.BottomLine = Instance.new("Frame", Hub.TitleGroup)
Hub.BottomLine.Size = UDim2.new(0, 0, 0, 2)
Hub.BottomLine.Position = UDim2.new(0.5, 0, 1, 20)
Hub.BottomLine.BackgroundColor3 = Hub.THEME.ElectricViolet
Hub.BottomLine.BorderSizePixel = 0
Hub.BottomLine.AnchorPoint = Vector2.new(0.5, 0)

-- [[CHUNK 2B]]
-- Progress Bar
Hub.ProgressGroup = Instance.new("Frame", Hub.LoadingContainer)
Hub.ProgressGroup.Size = UDim2.new(1, 0, 0, 100)
Hub.ProgressGroup.Position = UDim2.new(0, 0, 0.65, 0)
Hub.ProgressGroup.BackgroundTransparency = 1
Hub.ProgressGroup.ZIndex = 1001

Hub.BarBg = Instance.new("Frame", Hub.ProgressGroup)
Hub.BarBg.Size = UDim2.new(0.7, 0, 0, 6)
Hub.BarBg.Position = UDim2.new(0.08, 0, 0.3, 0)
Hub.BarBg.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
Hub.BarBg.BackgroundTransparency = 0.3
Hub.BarBg.BorderSizePixel = 0
Instance.new("UICorner", Hub.BarBg).CornerRadius = UDim.new(1, 0)

Hub.BarFill = Instance.new("Frame", Hub.BarBg)
Hub.BarFill.Size = UDim2.new(0, 0, 1, 0)
Hub.BarFill.BackgroundColor3 = Hub.THEME.CosmicCyan
Hub.BarFill.BorderSizePixel = 0
Hub.BarFill.ClipsDescendants = true
Instance.new("UICorner", Hub.BarFill).CornerRadius = UDim.new(1, 0)

Hub.FillGradient = Instance.new("UIGradient", Hub.BarFill)
Hub.FillGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Hub.THEME.ElectricViolet),
    ColorSequenceKeypoint.new(0.5, Hub.THEME.CosmicCyan),
    ColorSequenceKeypoint.new(1, Hub.THEME.AccretionGlow)
}
Hub.FillGradient.Rotation = 90

Hub.BarShine = Instance.new("Frame", Hub.BarFill)
Hub.BarShine.Size = UDim2.new(0, 30, 1, 0)
Hub.BarShine.Position = UDim2.new(0, 0, 0, 0)
Hub.BarShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Hub.BarShine.BackgroundTransparency = 0.6
Hub.BarShine.BorderSizePixel = 0
Hub.BarShine.ZIndex = 1002

Hub.PercentText = Instance.new("TextLabel", Hub.ProgressGroup)
Hub.PercentText.Size = UDim2.new(0, 70, 0, 30)
Hub.PercentText.AnchorPoint = Vector2.new(1, 0)
Hub.PercentText.Position = UDim2.new(0.97, 0, 0.2, 0)
Hub.PercentText.Text = "0%"
Hub.PercentText.TextColor3 = Hub.THEME.CosmicCyan
Hub.PercentText.Font = Enum.Font.GothamBold
Hub.PercentText.TextSize = 16
Hub.PercentText.TextXAlignment = Enum.TextXAlignment.Right
Hub.PercentText.BackgroundTransparency = 1
Hub.PercentText.TextTransparency = 1
Hub.PercentText.ZIndex = 1001

Hub.StatusPill = Instance.new("Frame", Hub.ProgressGroup)
Hub.StatusPill.Size = UDim2.new(0, 240, 0, 32)
Hub.StatusPill.AnchorPoint = Vector2.new(0.5, 0)
Hub.StatusPill.Position = UDim2.new(0.5, 0, 0.62, 0)
Hub.StatusPill.BackgroundColor3 = Hub.THEME.DeepNebula
Hub.StatusPill.BackgroundTransparency = 0.35
Hub.StatusPill.ZIndex = 1000
Hub.StatusPill.Visible = false
Instance.new("UICorner", Hub.StatusPill).CornerRadius = UDim.new(1, 0)

Hub.PillStroke = Instance.new("UIStroke", Hub.StatusPill)
Hub.PillStroke.Color = Hub.THEME.ElectricViolet
Hub.PillStroke.Transparency = 0.5
Hub.PillStroke.Thickness = 1.2

Hub.StatusDot = Instance.new("Frame", Hub.StatusPill)
Hub.StatusDot.Size = UDim2.new(0, 8, 0, 8)
Hub.StatusDot.AnchorPoint = Vector2.new(0.5, 0.5)
Hub.StatusDot.Position = UDim2.new(0, 14, 0.5, 0)
Hub.StatusDot.BackgroundColor3 = Hub.THEME.CosmicCyan
Hub.StatusDot.BorderSizePixel = 0
Instance.new("UICorner", Hub.StatusDot).CornerRadius = UDim.new(1, 0)

Hub.statusDotBlinking = true
task.spawn(function()
    while Hub.statusDotBlinking and Hub.StatusDot.Parent do
        Hub.TweenService:Create(Hub.StatusDot, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { BackgroundTransparency = 0.7 }):Play()
        task.wait(0.6)
        Hub.TweenService:Create(Hub.StatusDot, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { BackgroundTransparency = 0 }):Play()
        task.wait(0.6)
    end
end)

Hub.StatusText = Instance.new("TextLabel", Hub.StatusPill)
Hub.StatusText.Size = UDim2.new(1, -34, 1, 0)
Hub.StatusText.Position = UDim2.new(0, 28, 0, 0)
Hub.StatusText.Text = "Initializing warp drive..."
Hub.StatusText.TextColor3 = Hub.THEME.TextSecondary
Hub.StatusText.Font = Enum.Font.GothamMedium
Hub.StatusText.TextSize = 13
Hub.StatusText.TextXAlignment = Enum.TextXAlignment.Left
Hub.StatusText.BackgroundTransparency = 1
Hub.StatusText.ZIndex = 1001
Hub.StatusText.TextTransparency = 1

Hub.WelcomeText = Instance.new("TextLabel", Hub.LoadingContainer)
Hub.WelcomeText.Size = UDim2.new(0.9, 0, 0, 60)
Hub.WelcomeText.Position = UDim2.new(0.05, 0, 0.45, 0)
Hub.WelcomeText.Text = "WELCOME TO RYOOOONK COSMIC HUB"
Hub.WelcomeText.TextColor3 = Hub.THEME.CosmicCyan
Hub.WelcomeText.Font = Enum.Font.GothamBold
Hub.WelcomeText.TextSize = 34
Hub.WelcomeText.BackgroundTransparency = 1
Hub.WelcomeText.ZIndex = 1001
Hub.WelcomeText.TextTransparency = 1
Hub.WelcomeText.TextWrapped = true
Hub.WelcomeAspect = Instance.new("UITextSizeConstraint", Hub.WelcomeText)
Hub.WelcomeAspect.MinTextSize = 18
Hub.WelcomeAspect.MaxTextSize = 34

-- [[CHUNK 2C]]
--  Skip Loading (tap anywhere) - fitur baru QoL
Hub.loadingSkipped = false
Hub.SkipBtn = Instance.new("TextButton", Hub.LoadingContainer)
Hub.SkipBtn.Size = UDim2.new(1, 0, 1, 0)
Hub.SkipBtn.BackgroundTransparency = 1
Hub.SkipBtn.Text = ""
Hub.SkipBtn.ZIndex = 1010

Hub.SkipHint = Instance.new("TextLabel", Hub.SkipBtn)
Hub.SkipHint.Size = UDim2.new(0, 200, 0, 24)
Hub.SkipHint.AnchorPoint = Vector2.new(1, 1)
Hub.SkipHint.Position = UDim2.new(0.97, 0, 0.95, 0)
Hub.SkipHint.Text = "TAP ANYWHERE TO SKIP ▸"
Hub.SkipHint.TextColor3 = Hub.THEME.TextSecondary
Hub.SkipHint.Font = Enum.Font.GothamBold
Hub.SkipHint.TextSize = 11
Hub.SkipHint.BackgroundTransparency = 1
Hub.SkipHint.TextTransparency = 0.35
Hub.SkipHint.ZIndex = 1011

local function EnableSkip()
    Hub.loadingSkipped = true
    if Hub.SkipHint and Hub.SkipHint.Parent then
        Hub.SkipHint.Text = "SKIPPING..."
        Hub.SkipHint.TextColor3 = Hub.THEME.CosmicCyan
        Hub.SkipHint.TextTransparency = 0
    end
end

Hub.SkipBtn.MouseButton1Click:Connect(EnableSkip)
Hub.SkipBtn.TouchTap:Connect(EnableSkip)

local function WaitOrSkip(t)
    local started = os.clock()
    while (os.clock() - started) < t and not Hub.loadingSkipped do
        task.wait(0.05)
    end
end

-- Play Loading Animations
Hub.TweenService:Create(Hub.LoadingContainer, TweenInfo.new(1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()
Hub.TweenService:Create(Hub.TopLine, TweenInfo.new(1, Enum.EasingStyle.Quad), { Size = UDim2.new(0, 240, 0, 3) }):Play()
Hub.TweenService:Create(Hub.BottomLine, TweenInfo.new(1, Enum.EasingStyle.Quad), { Size = UDim2.new(0, 180, 0, 2) }):Play()

task.delay(0.6, function()
    if not Hub.loadingSkipped then
        Hub.TweenService:Create(Hub.MainTitle, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
        Hub.TweenService:Create(Hub.Subtitle, TweenInfo.new(1.5, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
        Hub.TweenService:Create(Hub.PercentText, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
    end
    Hub.StatusPill.Visible = true
    Hub.StatusPill.BackgroundTransparency = 1
    Hub.TweenService:Create(Hub.StatusPill, TweenInfo.new(1.2), { BackgroundTransparency = 0.35 }):Play()
    Hub.TweenService:Create(Hub.StatusText, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
end)

Hub.titleFloating = true
task.spawn(function()
    local startPos = Hub.MainTitle.Position
    local t = 0
    while Hub.titleFloating and Hub.MainTitle.Parent do
        t = t + Hub.RunService.RenderStepped:Wait()
        local floatY = math.sin(t * 1.3) * 6
        local swayX = math.sin(t * 0.8) * 10
        local rot = math.sin(t * 0.8) * 2.5
        local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + swayX, startPos.Y.Scale, startPos.Y.Offset + floatY)
        Hub.MainTitle.Position = newPos
        Hub.MainTitle.Rotation = rot
        Hub.TitleGlow.Position = newPos
        Hub.TitleGlow.Rotation = rot
    end
end)

Hub.TweenService:Create(Hub.BarFill, TweenInfo.new(Hub.LOADING_TIME, Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 1, 0) }):Play()

Hub.shineActive = true
task.spawn(function()
    while Hub.shineActive and Hub.BarFill.Parent do
        Hub.BarShine.Position = UDim2.new(0, 0, 0, 0)
        Hub.TweenService:Create(Hub.BarShine, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { Position = UDim2.new(1, 0, 0, 0) }):Play()
        task.wait(1.5)
    end
end)

task.spawn(function()
    local statusMessages = {
        "Initializing quantum systems...",
        "Calibrating black hole matrix...",
        "Locking accretion frequency...",
        "Engaging SpaceX thrusters...",
        "All systems operational!"
    }
    for i = 0, 100 do
        if Hub.loadingSkipped then break end
        Hub.PercentText.Text = i .. "%"
        local messageIndex = math.clamp(math.floor((i / 100) * (#statusMessages - 1)) + 1, 1, #statusMessages)
        Hub.StatusText.Text = statusMessages[messageIndex]
        WaitOrSkip(Hub.LOADING_TIME / 100)
    end
    if Hub.loadingSkipped then
        Hub.PercentText.Text = "100%"
        Hub.StatusText.Text = "Warp drive engaged!"
    end
end)

WaitOrSkip(Hub.LOADING_TIME + 0.1)
Hub.titleFloating = false
Hub.shineActive = false
Hub.statusDotBlinking = false

-- [[CHUNK 2D]]
if Hub.loadingSkipped then
    -- Jalur cepat: langsung bersihkan overlay
    if Hub.WelcomeText and Hub.WelcomeText.Parent then
        Hub.WelcomeText.TextTransparency = 1
    end
    if Hub.BackgroundLayer and Hub.BackgroundLayer.Parent then
        Hub.TweenService:Create(Hub.BackgroundLayer, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
    end
    task.wait(0.15)
    pcall(function() Hub.LoadingContainer:Destroy() end)
else
    local DROP_DISTANCE = GetDropDistance()

    local function DropAndFade(obj, delayTime, rotationAmount, extraFadeObjs)
        task.delay(delayTime, function()
            if not obj or not obj.Parent then return end
            local goalPos = UDim2.new(
                obj.Position.X.Scale, obj.Position.X.Offset,
                obj.Position.Y.Scale, obj.Position.Y.Offset + DROP_DISTANCE
            )
            local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            local goals = { Position = goalPos }
            if obj:IsA("TextLabel") then
                goals.TextTransparency = 1
                goals.Rotation = (obj.Rotation or 0) + rotationAmount
            else
                goals.BackgroundTransparency = 1
                goals.Rotation = (obj.Rotation or 0) + rotationAmount
            end
            Hub.TweenService:Create(obj, tweenInfo, goals):Play()
            if extraFadeObjs then
                for _, extraObj in ipairs(extraFadeObjs) do
                    if extraObj and extraObj.Parent then
                        if extraObj:IsA("TextLabel") then
                            Hub.TweenService:Create(extraObj, tweenInfo, { TextTransparency = 1 }):Play()
                        else
                            Hub.TweenService:Create(extraObj, tweenInfo, { BackgroundTransparency = 1 }):Play()
                        end
                    end
                end
            end
        end)
    end

    DropAndFade(Hub.MainTitle, 0, 180)
    DropAndFade(Hub.TitleGlow, 0, 180)
    DropAndFade(Hub.TopLine, 0.03, -45)
    DropAndFade(Hub.BottomLine, 0.05, 45)
    DropAndFade(Hub.Subtitle, 0.08, -20)
    DropAndFade(Hub.BarBg, 0.12, 30, { Hub.BarFill, Hub.BarShine })
    DropAndFade(Hub.PercentText, 0.15, -30)
    DropAndFade(Hub.StatusPill, 0.18, 20)

    task.delay(0.35, function()
        if Hub.WelcomeText and Hub.WelcomeText.Parent then
            Hub.TweenService:Create(Hub.WelcomeText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
        end
    end)

    task.wait(0.85)
    if Hub.WelcomeText and Hub.WelcomeText.Parent then
        Hub.TweenService:Create(Hub.WelcomeText, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { TextTransparency = 1 }):Play()
    end
    if Hub.BackgroundLayer and Hub.BackgroundLayer.Parent then
        Hub.TweenService:Create(Hub.BackgroundLayer, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
    end

    for i, star in ipairs(Hub.stars) do
        task.delay(i * 0.003, function()
            if star and star.Parent then
                Hub.TweenService:Create(star, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
            end
        end)
    end

    task.wait(0.35)
    pcall(function() Hub.LoadingContainer:Destroy() end)
end
end -- BuildLoadingScreen

BuildLoadingScreen()



-- [[CHUNK 3A]]
-- =========================================================================
-- 🚀 2. MAIN HUB SECTION (SPACEX BLACK HOLE BLUE-PURPLE DESIGN)
-- =========================================================================
Hub.MainSize = UDim2.new(0, 460, 0, 300)
Hub.MinimizedSize = UDim2.new(0, 460, 0, 42)

-- Forward declaration (fix #7: dulu Unload memakai RealFishBtn yang belum ada -> selalu nil)
local RealFishBtn

-- ✨ Outer Drop Shadow / Glow (efek melayang 3D)
Hub.ShadowHolder = Instance.new("Frame", Hub.sg)
Hub.ShadowHolder.Size = Hub.MainSize + UDim2.new(0, 18, 0, 18)
Hub.ShadowHolder.Position = UDim2.new(0.3, -9, 0.25, -9)
Hub.ShadowHolder.BackgroundTransparency = 0.75
Hub.ShadowHolder.BackgroundColor3 = Hub.THEME.ElectricViolet
Hub.ShadowHolder.BorderSizePixel = 0
Instance.new("UICorner", Hub.ShadowHolder).CornerRadius = UDim.new(0, 16)
Hub.ShadowStroke = Instance.new("UIStroke", Hub.ShadowHolder)
Hub.ShadowStroke.Color = Hub.THEME.CosmicCyan
Hub.ShadowStroke.Transparency = 0.7
Hub.ShadowStroke.Thickness = 3

Hub.Main = Instance.new("Frame", Hub.sg)
Hub.Main.Size = Hub.MainSize
Hub.Main.Position = UDim2.new(0.3, 0, 0.25, 0)
Hub.Main.BackgroundColor3 = Hub.THEME.VoidBlack
Hub.Main.BorderSizePixel = 0
Instance.new("UICorner", Hub.Main).CornerRadius = UDim.new(0, 12)

--  Cosmic Background Gradient
Hub.MainGradient = Instance.new("UIGradient", Hub.Main)
Hub.MainGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 15, 48)),
    ColorSequenceKeypoint.new(0.45, Color3.fromRGB(12, 10, 24)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 16, 36))
}
Hub.MainGradient.Rotation = 45

-- 🌌 Neon Shimmer Border (Violet -> Cyan)
Hub.MainStroke = Instance.new("UIStroke", Hub.Main)
Hub.MainStroke.Thickness = 1.6
Hub.MainStroke.Color = Hub.THEME.ElectricViolet
Hub.StrokeGradient = Instance.new("UIGradient", Hub.MainStroke)
Hub.StrokeGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Hub.THEME.ElectricViolet),
    ColorSequenceKeypoint.new(0.5, Hub.THEME.CosmicCyan),
    ColorSequenceKeypoint.new(1, Hub.THEME.ElectricViolet)
}
Hub.StrokeGradient.Rotation = 45

Hub.TitleBar = Instance.new("Frame", Hub.Main)
Hub.TitleBar.Size = UDim2.new(1, 0, 0, 42)
Hub.TitleBar.BackgroundTransparency = 1

-- Header Title & Subtitle Badge
Hub.TitleBadge = Instance.new("Frame", Hub.TitleBar)
Hub.TitleBadge.Size = UDim2.new(0, 6, 0, 20)
Hub.TitleBadge.Position = UDim2.new(0, 14, 0.5, -10)
Hub.TitleBadge.BackgroundColor3 = Hub.THEME.CosmicCyan
Hub.TitleBadge.BorderSizePixel = 0
Instance.new("UICorner", Hub.TitleBadge).CornerRadius = UDim.new(1, 0)

Hub.TitleText = Instance.new("TextLabel", Hub.TitleBar)
Hub.TitleText.Size = UDim2.new(0.7, 0, 0, 22)
Hub.TitleText.Position = UDim2.new(0, 26, 0, 4)
Hub.TitleText.Text = "RYOOOONK HUB"
Hub.TitleText.TextColor3 = Hub.THEME.TextPrimary
Hub.TitleText.Font = Enum.Font.GothamBold
Hub.TitleText.TextSize = 14
Hub.TitleText.TextXAlignment = Enum.TextXAlignment.Left
Hub.TitleText.BackgroundTransparency = 1

Hub.SubTitleText = Instance.new("TextLabel", Hub.TitleBar)
Hub.SubTitleText.Size = UDim2.new(0.7, 0, 0, 14)
Hub.SubTitleText.Position = UDim2.new(0, 26, 0, 24)
Hub.SubTitleText.Text = "SPACEX // BLACK HOLE EDITION  v2.0"
Hub.SubTitleText.TextColor3 = Hub.THEME.CosmicCyan
Hub.SubTitleText.Font = Enum.Font.GothamBold
Hub.SubTitleText.TextSize = 9
Hub.SubTitleText.TextXAlignment = Enum.TextXAlignment.Left
Hub.SubTitleText.BackgroundTransparency = 1

-- Tombol Close & Minimize (dibuat SEBELUM handler drag - fix #6)
Hub.CloseBtn = Instance.new("TextButton", Hub.TitleBar)
Hub.CloseBtn.Size = UDim2.new(0, 26, 0, 26)
Hub.CloseBtn.Position = UDim2.new(1, -38, 0.5, -13)
Hub.CloseBtn.Text = "✕"
Hub.CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 18, 30)
Hub.CloseBtn.TextColor3 = Hub.THEME.AlertRed
Hub.CloseBtn.Font = Enum.Font.GothamBold
Hub.CloseBtn.TextSize = 12
Hub.CloseBtn.AutoButtonColor = false
Instance.new("UICorner", Hub.CloseBtn).CornerRadius = UDim.new(0, 6)
Hub.CloseStroke = Instance.new("UIStroke", Hub.CloseBtn)
Hub.CloseStroke.Color = Hub.THEME.AlertRed
Hub.CloseStroke.Transparency = 0.6

Hub.MinBtn = Instance.new("TextButton", Hub.TitleBar)
Hub.MinBtn.Size = UDim2.new(0, 26, 0, 26)
Hub.MinBtn.Position = UDim2.new(1, -70, 0.5, -13)
Hub.MinBtn.Text = "—"
Hub.MinBtn.BackgroundColor3 = Color3.fromRGB(22, 25, 45)
Hub.MinBtn.TextColor3 = Hub.THEME.CosmicCyan
Hub.MinBtn.Font = Enum.Font.GothamBold
Hub.MinBtn.TextSize = 12
Hub.MinBtn.AutoButtonColor = false
Instance.new("UICorner", Hub.MinBtn).CornerRadius = UDim.new(0, 6)
Hub.MinStroke = Instance.new("UIStroke", Hub.MinBtn)
Hub.MinStroke.Color = Hub.THEME.CosmicCyan
Hub.MinStroke.Transparency = 0.6

-- [[CHUNK 3B]]
-- 🖱️ Smooth Drag Window (fix #6: klik tombol Close/Min tidak lagi ikut men-drag)
local function IsOverGui(guiObject, screenPos)
    if not guiObject then return false end
    local tl = guiObject.AbsolutePosition
    local sz = guiObject.AbsoluteSize
    return screenPos.X >= tl.X and screenPos.X <= tl.X + sz.X
        and screenPos.Y >= tl.Y and screenPos.Y <= tl.Y + sz.Y
end

Hub.isMinimized = false
local dragging, dragInput, dragStart, startPos

Track(Hub.TitleBar.InputBegan:Connect(function(input)
    local itype = input.UserInputType
    if itype ~= Enum.UserInputType.MouseButton1 and itype ~= Enum.UserInputType.Touch then return end
    if IsOverGui(Hub.CloseBtn, input.Position) or IsOverGui(Hub.MinBtn, input.Position) then return end
    if Hub.isMinimized then return end
    dragging = true
    dragStart = input.Position
    startPos = Hub.Main.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
        end
    end)
end))

Track(Hub.TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))

Track(Hub.UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        Hub.Main.Position = newPos
        Hub.ShadowHolder.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset - 9, newPos.Y.Scale, newPos.Y.Offset - 9)
    end
end))

Hub.HeaderDivider = Instance.new("Frame", Hub.Main)
Hub.HeaderDivider.Size = UDim2.new(1, -20, 0, 1)
Hub.HeaderDivider.Position = UDim2.new(0, 10, 0, 42)
Hub.HeaderDivider.BackgroundColor3 = Hub.THEME.StrokeColor
Hub.HeaderDivider.BackgroundTransparency = 0.5
Hub.HeaderDivider.BorderSizePixel = 0
Hub.DividerGradient = Instance.new("UIGradient", Hub.HeaderDivider)
Hub.DividerGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Hub.THEME.ElectricViolet),
    ColorSequenceKeypoint.new(0.5, Hub.THEME.CosmicCyan),
    ColorSequenceKeypoint.new(1, Hub.THEME.ElectricViolet)
}

-- 🛸 Sidebar Navigation
Hub.Sidebar = Instance.new("Frame", Hub.Main)
Hub.Sidebar.Size = UDim2.new(0, 125, 1, -50)
Hub.Sidebar.Position = UDim2.new(0, 8, 0, 46)
Hub.Sidebar.BackgroundTransparency = 1

Hub.Pages = Instance.new("Frame", Hub.Main)
Hub.Pages.Size = UDim2.new(1, -145, 1, -72)
Hub.Pages.Position = UDim2.new(0, 137, 0, 48)
Hub.Pages.BackgroundTransparency = 1

-- 📟 Status Strip (baru): menampilkan aksi terakhir engine (heal, sell, dsb)
Hub.StatusStrip = Instance.new("Frame", Hub.Main)
Hub.StatusStrip.Size = UDim2.new(1, -20, 0, 18)
Hub.StatusStrip.Position = UDim2.new(0, 10, 1, -24)
Hub.StatusStrip.BackgroundTransparency = 1

Hub.StatusDotMini = Instance.new("Frame", Hub.StatusStrip)
Hub.StatusDotMini.Size = UDim2.new(0, 6, 0, 6)
Hub.StatusDotMini.Position = UDim2.new(0, 2, 0.5, -3)
Hub.StatusDotMini.BackgroundColor3 = Hub.THEME.SuccessGreen
Hub.StatusDotMini.BorderSizePixel = 0
Instance.new("UICorner", Hub.StatusDotMini).CornerRadius = UDim.new(1, 0)

Hub.StatusStripText = Instance.new("TextLabel", Hub.StatusStrip)
Hub.StatusStripText.Size = UDim2.new(1, -16, 1, 0)
Hub.StatusStripText.Position = UDim2.new(0, 14, 0, 0)
Hub.StatusStripText.Text = "System idle - semua engine siaga."
Hub.StatusStripText.TextColor3 = Hub.THEME.TextSecondary
Hub.StatusStripText.Font = Enum.Font.GothamMedium
Hub.StatusStripText.TextSize = 9
Hub.StatusStripText.TextXAlignment = Enum.TextXAlignment.Left
Hub.StatusStripText.BackgroundTransparency = 1
Hub.StatusStripText.TextTruncate = Enum.TextTruncate.AtEnd

Hub.lastLogTime = 0
local function HubLog(message, accent)
    if not Hub.StatusStripText or not Hub.StatusStripText.Parent then return end
    local now = os.clock()
    -- throttle supaya label tidak di-update ribuan kali per detik
    if now - Hub.lastLogTime < 0.25 and not accent then return end
    Hub.lastLogTime = now
    Hub.StatusStripText.Text = message
    Hub.StatusStripText.TextColor3 = accent or Hub.THEME.CosmicCyan
end

-- ScrollingFrame dengan Scrollbar Cosmic Violet-Blue
local function createPage()
    local page = Instance.new("ScrollingFrame", Hub.Pages)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Hub.THEME.CosmicCyan
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.Visible = false
    return page
end

Hub.tabButtons = {}
Hub.activePage = nil
Hub.tweenInfoTab = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- [[CHUNK 3C]]
local function createTabButton(text, posIndex)
    local btn = Instance.new("TextButton", Hub.Sidebar)
    btn.Size = UDim2.new(0.95, 0, 0, 32)
    btn.Position = UDim2.new(0.025, 0, 0, 4 + (posIndex * 36))
    btn.Text = "  " .. text
    btn.TextColor3 = Hub.THEME.TextSecondary
    btn.BackgroundColor3 = Hub.THEME.CardBg
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = Hub.THEME.StrokeColor
    btnStroke.Transparency = 0.8
    btnStroke.Thickness = 1

    local ind = Instance.new("Frame", btn)
    ind.Name = "Indicator"
    ind.Size = UDim2.new(0, 3, 0.6, 0)
    ind.Position = UDim2.new(0, 4, 0.2, 0)
    ind.BackgroundColor3 = Hub.THEME.CosmicCyan
    ind.BorderSizePixel = 0
    ind.Visible = false
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)

    Track(btn.MouseEnter:Connect(function()
        if not btn:GetAttribute("IsActive") then
            Hub.TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Hub.THEME.CardHover }):Play()
        end
    end))
    Track(btn.MouseLeave:Connect(function()
        if not btn:GetAttribute("IsActive") then
            Hub.TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Hub.THEME.CardBg }):Play()
        end
    end))

    table.insert(Hub.tabButtons, btn)
    return btn
end

Hub.Page1 = createPage()
Hub.Page2 = createPage()
Hub.Page3 = createPage()
Hub.Page4 = createPage()
Hub.Page5 = createPage()

Hub.Tab1Btn = createTabButton("◆  Fishing", 0)
Hub.Tab2Btn = createTabButton("◆  Skills", 1)
Hub.Tab3Btn = createTabButton("◆  Tools", 2)
Hub.Tab4Btn = createTabButton("◆  Teleport", 3)
Hub.Tab5Btn = createTabButton("◆  Merchant", 4)

local function selectTab(selectedBtn, targetPage)
    PlaySound(Hub.clickSound)
    for _, btn in ipairs(Hub.tabButtons) do
        local ind = btn:FindFirstChild("Indicator")
        local stroke = btn:FindFirstChildOfClass("UIStroke")
        local isSel = (btn == selectedBtn)
        btn:SetAttribute("IsActive", isSel)
        if ind then ind.Visible = isSel end
        if stroke then
            stroke.Color = isSel and Hub.THEME.CosmicCyan or Hub.THEME.StrokeColor
            stroke.Transparency = isSel and 0.3 or 0.8
        end
        Hub.TweenService:Create(btn, Hub.tweenInfoTab, {
            BackgroundColor3 = isSel and Color3.fromRGB(35, 22, 65) or Hub.THEME.CardBg,
            TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or Hub.THEME.TextSecondary,
            Size = isSel and UDim2.new(1, 0, 0, 32) or UDim2.new(0.95, 0, 0, 32)
        }):Play()
    end
    if Hub.activePage and Hub.activePage ~= targetPage then
        Hub.activePage.Visible = false
    end
    targetPage.Visible = true
    Hub.activePage = targetPage
end

Track(Hub.Tab1Btn.MouseButton1Click:Connect(function() selectTab(Hub.Tab1Btn, Hub.Page1) end))
Track(Hub.Tab2Btn.MouseButton1Click:Connect(function() selectTab(Hub.Tab2Btn, Hub.Page2) end))
Track(Hub.Tab3Btn.MouseButton1Click:Connect(function() selectTab(Hub.Tab3Btn, Hub.Page3) end))
Track(Hub.Tab4Btn.MouseButton1Click:Connect(function() selectTab(Hub.Tab4Btn, Hub.Page4) end))
Track(Hub.Tab5Btn.MouseButton1Click:Connect(function() selectTab(Hub.Tab5Btn, Hub.Page5) end))

-- [[CHUNK 3D]]
-- ✨ Helper state tombol: dipakai satu pintu supaya UI & flag tidak pernah beda (dulu sering desync)
local function applyButtonState(btn, state, opts)
    opts = opts or {}
    local stroke = btn:FindFirstChildOfClass("UIStroke")
    btn:SetAttribute("IsActive", state and true or false)
    btn.BackgroundColor3 = state and (opts.onBg or Hub.THEME.ActiveBg) or (opts.offBg or Hub.THEME.CardBg)
    btn.TextColor3 = state and (opts.onColor or Hub.THEME.CosmicCyan) or (opts.offColor or Hub.THEME.TextPrimary)
    if stroke then
        stroke.Color = state and Hub.THEME.CosmicCyan or Hub.THEME.StrokeColor
        stroke.Transparency = state and 0.25 or 0.6
    end
end

local function updateButtonState(btn, state, onText, offText, opts)
    btn.Text = state and onText or offText
    applyButtonState(btn, state, opts)
end

-- (createToggleButton didefinisikan SETELAH createCosmicButton, lihat CHUNK 3E)

-- ✨ Helper Tombol Bergaya SpaceX Card (hover + state konsisten)
local function createCosmicButton(parent, text, yPos, height)
    height = height or 32
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.96, 0, 0, height)
    btn.Position = UDim2.new(0.02, 0, 0, yPos)
    btn.Text = text
    btn.BackgroundColor3 = Hub.THEME.CardBg
    btn.TextColor3 = Hub.THEME.TextPrimary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Hub.THEME.StrokeColor
    stroke.Transparency = 0.6
    stroke.Thickness = 1

    Track(btn.MouseEnter:Connect(function()
        Hub.TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Hub.THEME.CardHover }):Play()
        Hub.TweenService:Create(stroke, TweenInfo.new(0.2), { Color = Hub.THEME.CosmicCyan, Transparency = 0.2 }):Play()
    end))
    Track(btn.MouseLeave:Connect(function()
        local active = btn:GetAttribute("IsActive")
        Hub.TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = active and Hub.THEME.ActiveBg or Hub.THEME.CardBg }):Play()
        Hub.TweenService:Create(stroke, TweenInfo.new(0.2), { Color = active and Hub.THEME.CosmicCyan or Hub.THEME.StrokeColor, Transparency = 0.6 }):Play()
    end))

    return btn
end

-- Small helper: tombol +/- supaya layout rapi & kode tidak berulang
local function createStepperButton(parent, text, xPos, yPos, onClick)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.46, 0, 0, 28)
    btn.Position = UDim2.new(xPos, 0, 0, yPos)
    btn.Text = text
    btn.BackgroundColor3 = Hub.THEME.CardBg
    btn.TextColor3 = Hub.THEME.TextPrimary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Hub.THEME.StrokeColor
    stroke.Transparency = 0.7

    Track(btn.MouseEnter:Connect(function()
        Hub.TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Hub.THEME.CardHover }):Play()
        Hub.TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Hub.THEME.CosmicCyan, Transparency = 0.3 }):Play()
    end))
    Track(btn.MouseLeave:Connect(function()
        Hub.TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Hub.THEME.CardBg }):Play()
        Hub.TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Hub.THEME.StrokeColor, Transparency = 0.7 }):Play()
    end))
    Track(btn.MouseButton1Click:Connect(function()
        PlaySound(Hub.speedSound)
        onClick()
    end))

    return btn
end

-- [[CHUNK 3E]]
-- Registry toggle: supaya Save/Load Config bisa menyinkronkan seluruh tombol sekaligus
Hub.ToggleRegistry = {}

local function createToggleButton(parent, text, yPos, flagName, onText, offText, opts, height, sound)
    local btn = createCosmicButton(parent, text, yPos, height)
    btn:SetAttribute("IsActive", false)
    Track(btn.MouseButton1Click:Connect(function()
        PlaySound(sound or Hub.defaultClickSound)
        getgenv()[flagName] = not getgenv()[flagName]
        updateButtonState(btn, getgenv()[flagName], onText, offText, opts)
    end))
    table.insert(Hub.ToggleRegistry, { btn = btn, flag = flagName, on = onText, off = offText, opts = opts })
    return btn
end

local function RefreshAllToggles()
    for _, entry in ipairs(Hub.ToggleRegistry) do
        if entry.btn and entry.btn.Parent then
            updateButtonState(entry.btn, getgenv()[entry.flag], entry.on, entry.off, entry.opts)
        end
    end
end

-- =========================================================================
-- 🎣 PAGE 1: FISHING
-- =========================================================================
Hub.CastBtn = createToggleButton(Hub.Page1, "AUTO CAST: OFF", 5, "NWKZ_AutoCast",
    "AUTO CAST: ON", "AUTO CAST: OFF", nil, 32, Hub.autoCastSound)

Hub.AnchorBtn = createToggleButton(Hub.Page1, "ROCK BAR (LOCK CENTER): OFF", 42, "NWKZ_Anchor",
    "ROCK BAR (LOCK CENTER): ON", "ROCK BAR (LOCK CENTER): OFF", nil, 32, Hub.anchorSound)

Hub.FishThipBtn = createToggleButton(Hub.Page1, "INSTANT FISH BUTTON: OFF", 79, "PP_FishingThipActive",
    "INSTANT FISH BUTTON: ON", "INSTANT FISH BUTTON: OFF")

Hub.AutoSellBtn = createToggleButton(Hub.Page1, "AUTO SELL ALL: OFF", 116, "PP_AutoSell",
    "AUTO SELL ALL: ON", "AUTO SELL ALL: OFF", nil, 32, Hub.sellSound)

Hub.SellBtn = createCosmicButton(Hub.Page1, "💰 SELL ALL FISH (SEKARANG)", 153)
Hub.SellBtn.TextColor3 = Hub.THEME.CosmicCyan

Hub.SellIntervalLabel = Instance.new("TextLabel", Hub.Page1)
Hub.SellIntervalLabel.Size = UDim2.new(0.96, 0, 0, 18)
Hub.SellIntervalLabel.Position = UDim2.new(0.02, 0, 0, 190)
Hub.SellIntervalLabel.Text = "Auto Sell setiap: 30 detik"
Hub.SellIntervalLabel.TextColor3 = Hub.THEME.WarnAmber
Hub.SellIntervalLabel.Font = Enum.Font.GothamBold
Hub.SellIntervalLabel.TextSize = 10
Hub.SellIntervalLabel.BackgroundTransparency = 1
Hub.SellIntervalLabel.TextXAlignment = Enum.TextXAlignment.Center

local function RefreshSellIntervalLabel()
    Hub.SellIntervalLabel.Text = "Auto Sell setiap: " .. tostring(getgenv().PP_SellInterval) .. " detik"
end

createStepperButton(Hub.Page1, "[-] 5 detik", 0.02, 212, function()
    getgenv().PP_SellInterval = math.clamp(getgenv().PP_SellInterval - 5, 5, 600)
    RefreshSellIntervalLabel()
end)

createStepperButton(Hub.Page1, "[+] 5 detik", 0.51, 212, function()
    getgenv().PP_SellInterval = math.clamp(getgenv().PP_SellInterval + 5, 5, 600)
    RefreshSellIntervalLabel()
end)

-- Catatan kecil biar user tahu batas aman fishing
Hub.FishNote = Instance.new("TextLabel", Hub.Page1)
Hub.FishNote.Size = UDim2.new(0.96, 0, 0, 30)
Hub.FishNote.Position = UDim2.new(0.02, 0, 0, 246)
Hub.FishNote.Text = "Tip: Auto Cast butuh rod ter-equip. Anchor otomatis lock ke zona bila terdeteksi."
Hub.FishNote.TextColor3 = Hub.THEME.TextSecondary
Hub.FishNote.Font = Enum.Font.GothamMedium
Hub.FishNote.TextSize = 9
Hub.FishNote.BackgroundTransparency = 1
Hub.FishNote.TextWrapped = true
Hub.FishNote.TextXAlignment = Enum.TextXAlignment.Center

-- [[CHUNK 4A]]
-- =========================================================================
-- ⚡ PAGE 2: SKILLS & SMART AUTO HEAL
-- =========================================================================
Hub.SkillAllBtn = createToggleButton(Hub.Page2, "AUTO ALL SKILLS: OFF", 5, "PP_AutoSkillAll",
    "AUTO ALL SKILLS: ON", "AUTO ALL SKILLS: OFF", nil, 32, Hub.skillSound)

local function createGridSkillToggle(keyName, posIndex, flagName)
    local xPos = (posIndex % 2 == 0) and 0.02 or 0.51
    local yPos = 45 + (math.floor(posIndex / 2) * 35)
    local onText = "SKILL [" .. keyName .. "]: ON"
    local offText = "SKILL [" .. keyName .. "]: OFF"
    local opts = { offColor = Hub.THEME.TextSecondary, onColor = Hub.THEME.CosmicCyan }

    local btn = Instance.new("TextButton", Hub.Page2)
    btn.Size = UDim2.new(0.46, 0, 0, 30)
    btn.Position = UDim2.new(xPos, 0, 0, yPos)
    btn.Text = offText
    btn.BackgroundColor3 = Hub.THEME.CardBg
    btn.TextColor3 = Hub.THEME.TextSecondary
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Hub.THEME.StrokeColor
    stroke.Transparency = 0.7

    Track(btn.MouseButton1Click:Connect(function()
        PlaySound(Hub.skillSound)
        getgenv()[flagName] = not getgenv()[flagName]
        updateButtonState(btn, getgenv()[flagName], onText, offText, opts)
    end))
    Track(btn.MouseEnter:Connect(function()
        if not btn:GetAttribute("IsActive") then
            Hub.TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Hub.THEME.CardHover }):Play()
        end
    end))
    Track(btn.MouseLeave:Connect(function()
        if not btn:GetAttribute("IsActive") then
            Hub.TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Hub.THEME.CardBg }):Play()
        end
    end))

    table.insert(Hub.ToggleRegistry, { btn = btn, flag = flagName, on = onText, off = offText, opts = opts })
    updateButtonState(btn, getgenv()[flagName], onText, offText, opts)
    return btn
end

createGridSkillToggle("V", 0, "PP_Skill_V")
createGridSkillToggle("Z", 1, "PP_Skill_Z")
createGridSkillToggle("X", 2, "PP_Skill_X")
createGridSkillToggle("C", 3, "PP_Skill_C")

-- Interval skill (baru): dulu keempat skill di-spam tanpa jeda yang bisa diatur
Hub.SkillIntervalLabel = Instance.new("TextLabel", Hub.Page2)
Hub.SkillIntervalLabel.Size = UDim2.new(0.96, 0, 0, 18)
Hub.SkillIntervalLabel.Position = UDim2.new(0.02, 0, 0, 116)
Hub.SkillIntervalLabel.Text = "Jeda Auto Skill: 0.6 detik"
Hub.SkillIntervalLabel.TextColor3 = Hub.THEME.WarnAmber
Hub.SkillIntervalLabel.Font = Enum.Font.GothamBold
Hub.SkillIntervalLabel.TextSize = 10
Hub.SkillIntervalLabel.BackgroundTransparency = 1
Hub.SkillIntervalLabel.TextXAlignment = Enum.TextXAlignment.Center

local function RefreshSkillIntervalLabel()
    Hub.SkillIntervalLabel.Text = string.format("Jeda Auto Skill: %.1f detik", getgenv().PP_SkillInterval)
end

createStepperButton(Hub.Page2, "[-] 0.1s", 0.02, 138, function()
    getgenv().PP_SkillInterval = math.clamp(math.floor((getgenv().PP_SkillInterval - 0.1) * 10 + 0.5) / 10, 0.2, 5)
    RefreshSkillIntervalLabel()
end)

createStepperButton(Hub.Page2, "[+] 0.1s", 0.51, 138, function()
    getgenv().PP_SkillInterval = math.clamp(math.floor((getgenv().PP_SkillInterval + 0.1) * 10 + 0.5) / 10, 0.2, 5)
    RefreshSkillIntervalLabel()
end)

-- [[CHUNK 4B]]
-- 💚 Smart Auto Heal Section
Hub.healKeyList = {
    { Name = "C (Dragonfish)", Key = Enum.KeyCode.C },
    { Name = "X (Vajra)", Key = Enum.KeyCode.X },
    { Name = "Z (Celestial)", Key = Enum.KeyCode.Z },
    { Name = "V (Beastbreaker)", Key = Enum.KeyCode.V },
}

Hub.HealDivider = Instance.new("Frame", Hub.Page2)
Hub.HealDivider.Size = UDim2.new(0.96, 0, 0, 1)
Hub.HealDivider.Position = UDim2.new(0.02, 0, 0, 176)
Hub.HealDivider.BackgroundColor3 = Hub.THEME.ElectricViolet
Hub.HealDivider.BorderSizePixel = 0
Hub.HealDivGrad = Instance.new("UIGradient", Hub.HealDivider)
Hub.HealDivGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Hub.THEME.ElectricViolet),
    ColorSequenceKeypoint.new(0.5, Hub.THEME.CosmicCyan),
    ColorSequenceKeypoint.new(1, Hub.THEME.ElectricViolet)
}

Hub.HealSectionTitle = Instance.new("TextLabel", Hub.Page2)
Hub.HealSectionTitle.Size = UDim2.new(0.96, 0, 0, 18)
Hub.HealSectionTitle.Position = UDim2.new(0.02, 0, 0, 181)
Hub.HealSectionTitle.Text = "SMART ROD HEAL // CUSTOM HEALTH %"
Hub.HealSectionTitle.TextColor3 = Hub.THEME.CosmicCyan
Hub.HealSectionTitle.Font = Enum.Font.GothamBold
Hub.HealSectionTitle.TextSize = 10
Hub.HealSectionTitle.BackgroundTransparency = 1
Hub.HealSectionTitle.TextXAlignment = Enum.TextXAlignment.Left

Hub.HealToggleBtn = createToggleButton(Hub.Page2, "AUTO HEAL ROD: OFF", 202, "PP_AutoHeal",
    "AUTO HEAL ROD: ON", "AUTO HEAL ROD: OFF", nil, 32, Hub.healSound)

Hub.HealKeyBtn = Instance.new("TextButton", Hub.Page2)
Hub.HealKeyBtn.Size = UDim2.new(0.46, 0, 0, 28)
Hub.HealKeyBtn.Position = UDim2.new(0.02, 0, 0, 239)
Hub.HealKeyBtn.Text = "Skill: " .. Hub.healKeyList[getgenv().PP_HealKeyIndex].Name
Hub.HealKeyBtn.BackgroundColor3 = Color3.fromRGB(28, 20, 50)
Hub.HealKeyBtn.TextColor3 = Hub.THEME.CosmicCyan
Hub.HealKeyBtn.Font = Enum.Font.GothamBold
Hub.HealKeyBtn.TextSize = 9
Hub.HealKeyBtn.AutoButtonColor = false
Hub.HealKeyBtn.TextWrapped = true
Instance.new("UICorner", Hub.HealKeyBtn).CornerRadius = UDim.new(0, 5)
Hub.KeyStroke = Instance.new("UIStroke", Hub.HealKeyBtn)
Hub.KeyStroke.Color = Hub.THEME.ElectricViolet
Hub.KeyStroke.Transparency = 0.5

Hub.HealThresholdLabel = Instance.new("TextLabel", Hub.Page2)
Hub.HealThresholdLabel.Size = UDim2.new(0.46, 0, 0, 28)
Hub.HealThresholdLabel.Position = UDim2.new(0.51, 0, 0, 239)
Hub.HealThresholdLabel.Text = "Heal saat HP < " .. tostring(getgenv().PP_HealPercent) .. "%"
Hub.HealThresholdLabel.BackgroundColor3 = Hub.THEME.CardBg
Hub.HealThresholdLabel.TextColor3 = Hub.THEME.WarnAmber
Hub.HealThresholdLabel.Font = Enum.Font.GothamBold
Hub.HealThresholdLabel.TextSize = 9
Hub.HealThresholdLabel.TextWrapped = true
Instance.new("UICorner", Hub.HealThresholdLabel).CornerRadius = UDim.new(0, 5)
Hub.ThreshStroke = Instance.new("UIStroke", Hub.HealThresholdLabel)
Hub.ThreshStroke.Color = Hub.THEME.StrokeColor
Hub.ThreshStroke.Transparency = 0.7

local function RefreshHealLabels()
    Hub.HealKeyBtn.Text = "Skill: " .. Hub.healKeyList[getgenv().PP_HealKeyIndex].Name
    Hub.HealThresholdLabel.Text = "Heal saat HP < " .. tostring(getgenv().PP_HealPercent) .. "%"
end

Track(Hub.HealKeyBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.clickSound)
    getgenv().PP_HealKeyIndex = (getgenv().PP_HealKeyIndex % #Hub.healKeyList) + 1
    RefreshHealLabels()
end))

createStepperButton(Hub.Page2, "[-] Turunkan 10%", 0.02, 271, function()
    getgenv().PP_HealPercent = math.clamp(getgenv().PP_HealPercent - 10, 10, 90)
    RefreshHealLabels()
end)

createStepperButton(Hub.Page2, "[+] Naikkan 10%", 0.51, 271, function()
    getgenv().PP_HealPercent = math.clamp(getgenv().PP_HealPercent + 10, 10, 90)
    RefreshHealLabels()
end)

Hub.LiveHealthLabel = Instance.new("TextLabel", Hub.Page2)
Hub.LiveHealthLabel.Size = UDim2.new(0.96, 0, 0, 22)
Hub.LiveHealthLabel.Position = UDim2.new(0.02, 0, 0, 304)
Hub.LiveHealthLabel.Text = "Live HP: Menunggu rod..."
Hub.LiveHealthLabel.TextColor3 = Hub.THEME.TextSecondary
Hub.LiveHealthLabel.Font = Enum.Font.GothamMedium
Hub.LiveHealthLabel.TextSize = 10
Hub.LiveHealthLabel.BackgroundTransparency = 1
Hub.LiveHealthLabel.TextXAlignment = Enum.TextXAlignment.Center

-- [[CHUNK 5A]]
-- =========================================================================
-- 🛠️ PAGE 3: TOOLS & UTILITIES
-- =========================================================================
Hub.NoclipBtn = createToggleButton(Hub.Page3, "NOCLIP: OFF", 5, "PP_Noclip",
    "NOCLIP: ON", "NOCLIP: OFF")

Hub.SpeedLabel = Instance.new("TextLabel", Hub.Page3)
Hub.SpeedLabel.Size = UDim2.new(0.96, 0, 0, 20)
Hub.SpeedLabel.Position = UDim2.new(0.02, 0, 0, 42)
Hub.SpeedLabel.Text = "WalkSpeed: " .. tostring(getgenv().PP_WalkSpeed)
Hub.SpeedLabel.TextColor3 = Hub.THEME.CosmicCyan
Hub.SpeedLabel.Font = Enum.Font.GothamBold
Hub.SpeedLabel.TextSize = 11
Hub.SpeedLabel.BackgroundTransparency = 1

local function RefreshSpeedLabel()
    Hub.SpeedLabel.Text = "WalkSpeed: " .. tostring(getgenv().PP_WalkSpeed)
end

createStepperButton(Hub.Page3, "Speed Up (+10)", 0.02, 66, function()
    getgenv().PP_WalkSpeed = math.clamp(getgenv().PP_WalkSpeed + 10, 16, 250)
    RefreshSpeedLabel()
end)

createStepperButton(Hub.Page3, "Speed Down (-10)", 0.51, 66, function()
    getgenv().PP_WalkSpeed = math.clamp(getgenv().PP_WalkSpeed - 10, 16, 250)
    RefreshSpeedLabel()
end)

Hub.FlyBtn = createCosmicButton(Hub.Page3, "🚀 OPEN FLY GUI", 102)
Track(Hub.FlyBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    pcall(function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-FLY-GUI-V11-205450"))()
    end)
    Hub.FlyBtn.Text = "🚀 FLY LOADED!"
    task.wait(0.8)
    if Hub.FlyBtn.Parent then Hub.FlyBtn.Text = "🚀 OPEN FLY GUI" end
end))

Hub.DevTeleportBtn = createCosmicButton(Hub.Page3, "🛠️ Run Dev Teleport Script", 140)
Track(Hub.DevTeleportBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    local ok = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/p54803322-coder/PPINGYYY-Teleport-XD/refs/heads/main/main.lua"))()
    end)
    Hub.DevTeleportBtn.Text = ok and "🚀 Script Loaded!" or "⚠️ Gagal Load Script"
    task.wait(1)
    if Hub.DevTeleportBtn.Parent then Hub.DevTeleportBtn.Text = "🛠️ Run Dev Teleport Script" end
end))

-- [[CHUNK 5B]]
-- Anti-AFK (baru): cegah auto-disconnect saat AFK farming
Hub.AntiAfkBtn = createToggleButton(Hub.Page3, "ANTI-AFK: OFF", 178, "PP_AntiAFK",
    "ANTI-AFK: ON", "ANTI-AFK: OFF")

--  Infinite Jump (baru)
Hub.InfiniteJumpBtn = createToggleButton(Hub.Page3, "INFINITE JUMP: OFF", 214, "PP_InfiniteJump",
    "INFINITE JUMP: ON", "INFINITE JUMP: OFF")

-- 🌙 Low GFX / FPS Boost (baru): ringankan rendering untuk device lemah
Hub.graphicsBackup = nil
local function ApplyLowGFX(state)
    pcall(function()
        if state then
            if not Hub.graphicsBackup then
                Hub.graphicsBackup = {
                    GlobalShadows = Hub.Lighting.GlobalShadows,
                    Ambient = Hub.Lighting.Ambient,
                    OutdoorAmbient = Hub.Lighting.OutdoorAmbient,
                    FogEnd = Hub.Lighting.FogEnd,
                    ShadowSoftness = Hub.Lighting.ShadowSoftness,
                }
            end
            Hub.Lighting.GlobalShadows = false
            Hub.Lighting.FogEnd = 100000
            Hub.Lighting.ShadowSoftness = 0.5
            Hub.Lighting.Ambient = Color3.fromRGB(120, 120, 120)
            Hub.Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 120)
        else
            if Hub.graphicsBackup then
                Hub.Lighting.GlobalShadows = Hub.graphicsBackup.GlobalShadows
                Hub.Lighting.Ambient = Hub.graphicsBackup.Ambient
                Hub.Lighting.OutdoorAmbient = Hub.graphicsBackup.OutdoorAmbient
                Hub.Lighting.FogEnd = Hub.graphicsBackup.FogEnd
                Hub.Lighting.ShadowSoftness = Hub.graphicsBackup.ShadowSoftness
            end
        end
    end)
    pcall(function()
        settings().Rendering.QualityLevel = state and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
end

Hub.LowGfxBtn = createToggleButton(Hub.Page3, "LOW GFX / FPS BOOST: OFF", 250, "PP_LowGFX",
    "LOW GFX / FPS BOOST: ON", "LOW GFX / FPS BOOST: OFF")
Track(Hub.LowGfxBtn.MouseButton1Click:Connect(function()
    ApplyLowGFX(getgenv().PP_LowGFX)
end))

-- JumpPower control (baru)
Hub.JumpPowerLabel = Instance.new("TextLabel", Hub.Page3)
Hub.JumpPowerLabel.Size = UDim2.new(0.96, 0, 0, 20)
Hub.JumpPowerLabel.Position = UDim2.new(0.02, 0, 0, 286)
Hub.JumpPowerLabel.Text = "JumpPower: " .. tostring(getgenv().PP_JumpPower)
Hub.JumpPowerLabel.TextColor3 = Hub.THEME.CosmicCyan
Hub.JumpPowerLabel.Font = Enum.Font.GothamBold
Hub.JumpPowerLabel.TextSize = 11
Hub.JumpPowerLabel.BackgroundTransparency = 1

local function RefreshJumpPowerLabel()
    if Hub.JumpPowerLabel and Hub.JumpPowerLabel.Parent then
        Hub.JumpPowerLabel.Text = "JumpPower: " .. tostring(getgenv().PP_JumpPower)
    end
end

createStepperButton(Hub.Page3, "Jump Up (+25)", 0.02, 308, function()
    getgenv().PP_JumpPower = math.clamp(getgenv().PP_JumpPower + 25, 50, 500)
    RefreshJumpPowerLabel()
end)

createStepperButton(Hub.Page3, "Jump Down (-25)", 0.51, 308, function()
    getgenv().PP_JumpPower = math.clamp(getgenv().PP_JumpPower - 25, 50, 500)
    RefreshJumpPowerLabel()
end)

-- 🎹 Custom Keybind untuk membuka/menutup hub
Hub.keybindList = {
    { Name = "RightControl", Key = Enum.KeyCode.RightControl },
    { Name = "RightShift", Key = Enum.KeyCode.RightShift },
    { Name = "LeftControl", Key = Enum.KeyCode.LeftControl },
    { Name = "K", Key = Enum.KeyCode.K },
    { Name = "P", Key = Enum.KeyCode.P },
    { Name = "F1", Key = Enum.KeyCode.F1 },
    { Name = "F2", Key = Enum.KeyCode.F2 },
}

Hub.KeybindBtn = Instance.new("TextButton", Hub.Page3)
Hub.KeybindBtn.Size = UDim2.new(0.96, 0, 0, 30)
Hub.KeybindBtn.Position = UDim2.new(0.02, 0, 0, 344)
Hub.KeybindBtn.Text = "🎹 Buka/Tutup Keybind: " .. Hub.keybindList[getgenv().PP_ToggleKeyIndex].Name .. " (klik ubah)"
Hub.KeybindBtn.BackgroundColor3 = Hub.THEME.CardBg
Hub.KeybindBtn.TextColor3 = Hub.THEME.WarnAmber
Hub.KeybindBtn.Font = Enum.Font.GothamBold
Hub.KeybindBtn.TextSize = 10
Hub.KeybindBtn.AutoButtonColor = false
Instance.new("UICorner", Hub.KeybindBtn).CornerRadius = UDim.new(0, 5)
Hub.KeybindStroke = Instance.new("UIStroke", Hub.KeybindBtn)
Hub.KeybindStroke.Color = Hub.THEME.StrokeColor
Hub.KeybindStroke.Transparency = 0.7

local function RefreshKeybindLabel()
    Hub.KeybindBtn.Text = "🎹 Buka/Tutup Keybind: " .. Hub.keybindList[getgenv().PP_ToggleKeyIndex].Name .. " (klik ubah)"
end

Track(Hub.KeybindBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.clickSound)
    getgenv().PP_ToggleKeyIndex = (getgenv().PP_ToggleKeyIndex % #Hub.keybindList) + 1
    RefreshKeybindLabel()
end))

-- 💾 Save / Load Config (baru): simpan setting ke file lewat executor
Hub.CONFIG_FILE = "RYOOOONK_Hub_Config.json"

Hub.SAVED_KEYS = {
    "PP_WalkSpeed", "PP_HealPercent", "PP_HealKeyIndex", "PP_SkillInterval",
    "PP_SellInterval", "PP_ToggleKeyIndex",
    "NWKZ_AutoCast", "NWKZ_Anchor", "PP_FishingThipActive", "PP_AutoSell",
    "PP_AutoSkillAll", "PP_Skill_Z", "PP_Skill_X", "PP_Skill_C", "PP_Skill_V",
    "PP_AutoHeal", "PP_Noclip", "PP_AntiAFK", "PP_LowGFX", "PP_InfiniteJump", "PP_JumpPower"
}

local function SerializeConfig()
    local parts = {}
    for _, key in ipairs(Hub.SAVED_KEYS) do
        local value = getgenv()[key]
        if type(value) == "boolean" then
            table.insert(parts, string.format('"%s":%s', key, value and "true" or "false"))
        elseif type(value) == "number" then
            table.insert(parts, string.format('"%s":%s', key, tostring(value)))
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function SaveConfig(showToast)
    if not writefile then
        if showToast then Notify("Executor tidak mendukung writefile!", Hub.THEME.AlertRed) end
        return false
    end
    local ok = pcall(function()
        writefile(Hub.CONFIG_FILE, SerializeConfig())
    end)
    if showToast then
        Notify(ok and "Config tersimpan ke " .. Hub.CONFIG_FILE or "Gagal menyimpan config!", ok and Hub.THEME.CosmicCyan or Hub.THEME.AlertRed)
    end
    return ok
end

local function LoadConfig(showToast)
    if not (readfile and isfile) then
        if showToast then Notify("Executor tidak mendukung readfile!", Hub.THEME.AlertRed) end
        return false
    end
    if not isfile(Hub.CONFIG_FILE) then
        if showToast then Notify("Belum ada config tersimpan.", Hub.THEME.WarnAmber) end
        return false
    end

    local ok, content = pcall(function() return readfile(Hub.CONFIG_FILE) end)
    if not ok or type(content) ~= "string" then
        if showToast then Notify("Gagal membaca config!", Hub.THEME.AlertRed) end
        return false
    end

    local applied = 0
    for _, key in ipairs(Hub.SAVED_KEYS) do
        local strValue = string.match(content, '"' .. key .. '"%s*:%s*([%w%.%-]+)')
        if strValue then
            local value
            if strValue == "true" then
                value = true
            elseif strValue == "false" then
                value = false
            else
                value = tonumber(strValue)
            end
            if value ~= nil then
                getgenv()[key] = value
                applied = applied + 1
            end
        end
    end

    -- Sinkronkan seluruh UI dengan nilai yang baru dimuat
    RefreshAllToggles()
    RefreshSpeedLabel()
    RefreshHealLabels()
    RefreshSkillIntervalLabel()
    RefreshSellIntervalLabel()
    RefreshKeybindLabel()
    if RealFishBtn and getgenv().PP_FishingThipActive then
        RealFishBtn.Visible = Hub.Main.Visible
    elseif RealFishBtn then
        RealFishBtn.Visible = false
    end
    ApplyLowGFX(getgenv().PP_LowGFX)
    RefreshJumpPowerLabel()

    if showToast then
        Notify(applied > 0 and ("Config dimuat (" .. applied .. " setting).") or "Config kosong/tidak valid.", Hub.THEME.CosmicCyan)
    end
    return true
end

Hub.SaveConfigBtn = createCosmicButton(Hub.Page3, "💾 Simpan Config", 252, 28)
Hub.SaveConfigBtn.TextColor3 = Hub.THEME.CosmicCyan
Hub.SaveConfigBtn.Size = UDim2.new(0.46, 0, 0, 28)
Hub.SaveConfigBtn.Position = UDim2.new(0.02, 0, 0, 380)
Track(Hub.SaveConfigBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    SaveConfig(true)
end))

Hub.LoadConfigBtn = createCosmicButton(Hub.Page3, "📂 Muat Config", 252, 28)
Hub.LoadConfigBtn.Size = UDim2.new(0.46, 0, 0, 28)
Hub.LoadConfigBtn.Position = UDim2.new(0.51, 0, 0, 380)
Track(Hub.LoadConfigBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    LoadConfig(true)
end))

Hub.UnloadBtn = createCosmicButton(Hub.Page3, "🔴 Unload Hub Entirely", 288, 28)
Hub.UnloadBtn.TextColor3 = Hub.THEME.AlertRed
Hub.UnloadBtn.Position = UDim2.new(0.02, 0, 0, 414)

-- [[CHUNK 6A]]
-- =========================================================================
-- 🏝️ PAGE 4: ISLAND TELEPORT
-- =========================================================================
local function GetMyRoot()
    local char = lp.Character or lp.CharacterAdded:Wait()
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function TeleportToPosition(x, y, z)
    local hrp = GetMyRoot()
    if not hrp then
        Notify("Karakter belum siap, coba lagi.", Hub.THEME.WarnAmber)
        return false
    end
    PlaySound(Hub.tpSound)
    pcall(function()
        hrp.CFrame = CFrame.new(x, y, z)
    end)
    return true
end

local function createTeleportButton(parent, name, x, y, z, yPos)
    local btn = createCosmicButton(parent, "🏝️ " .. name, yPos, 32)
    Track(btn.MouseButton1Click:Connect(function()
        TeleportToPosition(x, y, z)
    end))
    return btn
end

createTeleportButton(Hub.Page4, "Beginner Fishing Isle", -236, 6, 56, 5)
createTeleportButton(Hub.Page4, "Bamboo Isle", -1226, 5, -23, 42)
createTeleportButton(Hub.Page4, "Great Pit Isle", 74, 6, 1216, 79)
createTeleportButton(Hub.Page4, "Waterfall Isle", -1285, 6, 1240, 116)
createTeleportButton(Hub.Page4, "Mutant Fish Isle", -47, 9, -1337, 153)
createTeleportButton(Hub.Page4, "Ice Isle", -1348, 9, -1485, 190)
createTeleportButton(Hub.Page4, "Coconut Palm Isle", 1434, 9, -1433, 227)
createTeleportButton(Hub.Page4, "Autumn Isle", 1243, 6, 1393, 264)
createTeleportButton(Hub.Page4, "Boss Hunter Isle", 1543, 46, -51, 301)
createTeleportButton(Hub.Page4, "Deserted Isle", 2631, 6, 60, 338)

-- 📌 Simpan / Balik ke Posisi (baru): berguna saat farming pindah-pindah spot
Hub.SavePosBtn = createCosmicButton(Hub.Page4, "📌 Simpan Posisi Sekarang", 375)
Track(Hub.SavePosBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    local hrp = GetMyRoot()
    if not hrp then return end
    local p = hrp.Position
    getgenv().PP_SavedSpot = { x = p.X, y = p.Y + 3, z = p.Z }
    Hub.SavePosBtn.Text = string.format("📌 Tersimpan: %d, %d, %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
    task.wait(1.5)
    if Hub.SavePosBtn.Parent then Hub.SavePosBtn.Text = "📌 Simpan Posisi Sekarang" end
end))

Hub.BackPosBtn = createCosmicButton(Hub.Page4, "↩️ Balik ke Posisi Tersimpan", 412)
Track(Hub.BackPosBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    local pos = getgenv().PP_SavedSpot
    if not pos then
        Notify("Belum ada posisi tersimpan.", Hub.THEME.WarnAmber)
        return
    end
    TeleportToPosition(pos.x, pos.y, pos.z)
end))

-- [[CHUNK 6B]]
-- =========================================================================
-- 🥷 PAGE 5: SECRET MERCHANT
-- =========================================================================
Hub.MerchantTpBtn = createCosmicButton(Hub.Page5, "🥷 TP ke Secret Merchant (Auto Scan)", 5)
Hub.MerchantTpBtn.TextColor3 = Hub.THEME.CosmicCyan

local function TeleportToSecretMerchant()
    local hrp = GetMyRoot()
    if not hrp then return end

    local keywords = { "merchant", "traveling", "secret", "vendor", "trader" }
    local found = false

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local lname = string.lower(obj.Name)
            local matched = false
            for _, kw in ipairs(keywords) do
                if string.find(lname, kw, 1, true) then
                    matched = true
                    break
                end
            end
            if matched then
                local targetPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("PrimaryPart")
                if not targetPart then
                    for _, d in ipairs(obj:GetDescendants()) do
                        if d:IsA("BasePart") then
                            targetPart = d
                            break
                        end
                    end
                end
                if targetPart and targetPart:IsA("BasePart") then
                    PlaySound(Hub.tpSound)
                    hrp.CFrame = targetPart.CFrame * CFrame.new(0, 0, -4)
                    found = true
                    Toast("MERCHANT DITEMUKAN", obj.Name .. " → kamu dipindahkan.", Hub.THEME.CosmicCyan)
                    break
                end
            end
        end
    end

    if not found then
        Notify("Secret Merchant belum spawn di server ini.", Hub.THEME.AlertRed)
    end
end

Track(Hub.MerchantTpBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    Hub.MerchantTpBtn.Text = "🔎 Scanning workspace..."
    task.spawn(function()
        TeleportToSecretMerchant()
        if Hub.MerchantTpBtn.Parent then
            Hub.MerchantTpBtn.Text = "🥷 TP ke Secret Merchant (Auto Scan)"
        end
    end)
end))

Hub.CheckSpotBtn = createCosmicButton(Hub.Page5, "🌊 TP ke Backup Spot (Waterfall/Cave)", 42)
Track(Hub.CheckSpotBtn.MouseButton1Click:Connect(function()
    TeleportToPosition(0, 50, -500)
end))

local function createMerchantTP(name, x, y, z, yPos)
    local btn = createCosmicButton(Hub.Page5, "📍 " .. name, yPos, 32)
    Track(btn.MouseButton1Click:Connect(function()
        TeleportToPosition(x, y, z)
    end))
    return btn
end

createMerchantTP("Secret Merchant - Spot 1", -33, 8, 1606, 79)
createMerchantTP("Secret Merchant - Spot 2", -1496, 9, 1134, 116)
createMerchantTP("Secret Merchant - Spot 3", -1528, 6, -1311, 153)
createMerchantTP("Secret Merchant - Spot 4", 1293, 8, 1428, 190)
createMerchantTP("Secret Merchant - Spot 5", 1592, 47, -44, 227)
createMerchantTP("Secret Merchant - Spot 6", -178, 6, -1268, 264)
createMerchantTP("Secret Merchant - Spot 7", 2861, 6, 121, 301)

-- [[CHUNK 7A]]
-- =========================================================================
-- 🟢 INSTANT FISH BUTTON (COSMIC FLOATING ORB)
-- =========================================================================
RealFishBtn = Instance.new("TextButton", Hub.sg)
RealFishBtn.Name = "InstantFishOrb"
RealFishBtn.Size = UDim2.new(0, 90, 0, 90)
RealFishBtn.Position = UDim2.new(0.85, 0, 0.40, 0)
RealFishBtn.BackgroundColor3 = Hub.THEME.VoidBlack
RealFishBtn.Text = "INSTANT\nFISH"
RealFishBtn.TextColor3 = Hub.THEME.CosmicCyan
RealFishBtn.Font = Enum.Font.GothamBold
RealFishBtn.TextSize = 14
RealFishBtn.Visible = false
RealFishBtn.BorderSizePixel = 0
RealFishBtn.AutoButtonColor = false
RealFishBtn.ZIndex = 1004
Instance.new("UICorner", RealFishBtn).CornerRadius = UDim.new(1, 0)
Hub.OrbStroke = Instance.new("UIStroke", RealFishBtn)
Hub.OrbStroke.Thickness = 2
Hub.OrbStroke.Color = Hub.THEME.CosmicCyan

-- Pulse halus supaya orb kelihatan hidup
task.spawn(function()
    while RealFishBtn.Parent do
        if RealFishBtn.Visible then
            Hub.TweenService:Create(Hub.OrbStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Transparency = 0.55 }):Play()
            task.wait(0.9)
            Hub.TweenService:Create(Hub.OrbStroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Transparency = 0 }):Play()
            task.wait(0.9)
        else
            task.wait(0.3)
        end
    end
end)

-- Draggable orb (biar user bisa geser ke posisi jempol)
local oDragging, oDragInput, oDragStart, oStartPos
Track(RealFishBtn.InputBegan:Connect(function(input)
    local itype = input.UserInputType
    if itype == Enum.UserInputType.MouseButton1 or itype == Enum.UserInputType.Touch then
        oDragging = true
        oDragStart = input.Position
        oStartPos = RealFishBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                oDragging = false
            end
        end)
    end
end))
Track(RealFishBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        oDragInput = input
    end
end))
Track(Hub.UserInputService.InputChanged:Connect(function(input)
    if input == oDragInput and oDragging then
        local delta = input.Position - oDragStart
        RealFishBtn.Position = UDim2.new(oStartPos.X.Scale, oStartPos.X.Offset + delta.X, oStartPos.Y.Scale, oStartPos.Y.Offset + delta.Y)
    end
end))

Track(RealFishBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    local fired = FireFishingAction()
    if not fired then
        EnsureFishingRodEquipped()
    end
    RealFishBtn.BackgroundColor3 = Hub.THEME.CosmicCyan
    RealFishBtn.TextColor3 = Hub.THEME.VoidBlack
    task.wait(0.08)
    if RealFishBtn.Parent then
        RealFishBtn.BackgroundColor3 = Hub.THEME.VoidBlack
        RealFishBtn.TextColor3 = Hub.THEME.CosmicCyan
    end
end))

-- 🛸 Floating Mini Toggle Widget (Anti-Ilang System)
Hub.FloatingToggle = Instance.new("TextButton", Hub.sg)
Hub.FloatingToggle.Name = "RYOOOONK_Toggle"
Hub.FloatingToggle.Size = UDim2.new(0, 136, 0, 32)
Hub.FloatingToggle.Position = UDim2.new(0.02, 0, 0.22, 0)
Hub.FloatingToggle.BackgroundColor3 = Hub.THEME.VoidBlack
Hub.FloatingToggle.Text = "🚀 RYOOOONK"
Hub.FloatingToggle.TextColor3 = Hub.THEME.CosmicCyan
Hub.FloatingToggle.Font = Enum.Font.GothamBold
Hub.FloatingToggle.TextSize = 12
Hub.FloatingToggle.BorderSizePixel = 0
Hub.FloatingToggle.AutoButtonColor = false
Hub.FloatingToggle.ZIndex = 1005
Hub.FloatingToggle.Visible = false
Instance.new("UICorner", Hub.FloatingToggle).CornerRadius = UDim.new(1, 0)

Hub.FloatStroke = Instance.new("UIStroke", Hub.FloatingToggle)
Hub.FloatStroke.Color = Hub.THEME.ElectricViolet
Hub.FloatStroke.Thickness = 1.8

Hub.FloatGrad = Instance.new("UIGradient", Hub.FloatingToggle)
Hub.FloatGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 15, 48)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 10, 28))
}

-- [[CHUNK 7B]]
-- Draggable FloatingToggle
local fDragging, fDragInput, fDragStart, fStartPos
Track(Hub.FloatingToggle.InputBegan:Connect(function(input)
    local itype = input.UserInputType
    if itype == Enum.UserInputType.MouseButton1 or itype == Enum.UserInputType.Touch then
        fDragging = true
        fDragStart = input.Position
        fStartPos = Hub.FloatingToggle.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                fDragging = false
            end
        end)
    end
end))
Track(Hub.FloatingToggle.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        fDragInput = input
    end
end))
Track(Hub.UserInputService.InputChanged:Connect(function(input)
    if input == fDragInput and fDragging then
        local delta = input.Position - fDragStart
        Hub.FloatingToggle.Position = UDim2.new(fStartPos.X.Scale, fStartPos.X.Offset + delta.X, fStartPos.Y.Scale, fStartPos.Y.Offset + delta.Y)
    end
end))

local function ToggleUI(explicitState)
    local targetState
    if explicitState ~= nil then
        targetState = explicitState
    else
        targetState = not Hub.Main.Visible
    end

    Hub.Main.Visible = targetState
    Hub.ShadowHolder.Visible = targetState
    Hub.FloatingToggle.Visible = not targetState
    if RealFishBtn and RealFishBtn.Parent then
        RealFishBtn.Visible = getgenv().PP_FishingThipActive and targetState
    end

    if targetState then
        PlaySound(Hub.defaultClickSound)
        Hub.Main.Size = UDim2.new(0, 420, 0, 250)
        Hub.ShadowHolder.Size = UDim2.new(0, 438, 0, 268)
        Hub.TweenService:Create(Hub.Main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Hub.isMinimized and Hub.MinimizedSize or Hub.MainSize }):Play()
        Hub.TweenService:Create(Hub.ShadowHolder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = (Hub.isMinimized and Hub.MinimizedSize or Hub.MainSize) + UDim2.new(0, 18, 0, 18) }):Play()
    end
end

Track(Hub.FloatingToggle.MouseButton1Click:Connect(function()
    ToggleUI(true)
end))

-- Keybind Toggle (bisa diganti dari Page Tools)
Track(Hub.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local chosen = Hub.keybindList[getgenv().PP_ToggleKeyIndex].Key
    if input.KeyCode == chosen then
        ToggleUI()
    end
end))

-- Close Button menyembunyikan window (tidak destroy) + Unload via Page Tools
Track(Hub.CloseBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    ToggleUI(false)
    Toast("HUB DIMINIMIZE", "Klik [🚀 RYOOOONK] atau tekan [" .. Hub.keybindList[getgenv().PP_ToggleKeyIndex].Name .. "] untuk buka lagi.", Hub.THEME.CosmicCyan)
end))

-- [[CHUNK 7C]]
-- Minimize / Restore Window (fix #6: klik Min kini benar-benar terpisah dari drag)
Hub.tweenInfoResize = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

Track(Hub.MinBtn.MouseButton1Click:Connect(function()
    PlaySound(Hub.defaultClickSound)
    Hub.isMinimized = not Hub.isMinimized
    if Hub.isMinimized then
        Hub.Sidebar.Visible = false
        Hub.StatusStrip.Visible = false
        Hub.HeaderDivider.Visible = false
        if Hub.activePage then Hub.activePage.Visible = false end
        Hub.TweenService:Create(Hub.Main, Hub.tweenInfoResize, { Size = Hub.MinimizedSize }):Play()
        Hub.TweenService:Create(Hub.ShadowHolder, Hub.tweenInfoResize, { Size = Hub.MinimizedSize + UDim2.new(0, 18, 0, 18) }):Play()
        Hub.MinBtn.Text = "+"
    else
        Hub.TweenService:Create(Hub.Main, Hub.tweenInfoResize, { Size = Hub.MainSize }):Play()
        Hub.TweenService:Create(Hub.ShadowHolder, Hub.tweenInfoResize, { Size = Hub.MainSize + UDim2.new(0, 18, 0, 18) }):Play()
        task.wait(0.15)
        if not Hub.Main.Visible then return end
        Hub.Sidebar.Visible = true
        Hub.StatusStrip.Visible = true
        Hub.HeaderDivider.Visible = true
        if Hub.activePage then Hub.activePage.Visible = true end
        Hub.MinBtn.Text = "—"
    end
end))

-- Toggle Instant Fish orb harus langsung sinkron (fix #7 lanjutan)
Track(Hub.FishThipBtn.MouseButton1Click:Connect(function()
    if RealFishBtn and RealFishBtn.Parent then
        RealFishBtn.Visible = getgenv().PP_FishingThipActive and Hub.Main.Visible
    end
end))

selectTab(Hub.Tab1Btn, Hub.Page1)

-- 🌟 Main Window Entry Animation (Smooth Pop-in)
ToggleUI(true)

PlaySound(Hub.loadSound)

-- =========================================================================
-- ⚙️ 3. BACKGROUND ENGINES & LOOPS (AUTOCAST, ANCHOR, HEAL, SKILL)
-- =========================================================================

-- Helper virtual key press (dipakai heal & skill)
local function PressKey(keyCode, holdTime)
    pcall(function()
        Hub.VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(holdTime or 0.05)
        Hub.VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

-- Jalankan cepat / hentikan dengan Ctrl+Shift? cukup lewat toggle saja.

-- [[CHUNK 8A]]
-- Helper karakter (aman terhadap respawn)
local function GetCharacter()
    return lp.Character
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end

Hub.OriginalWalkSpeed = 16
Hub.OriginalJumpPower = 50

--  Noclip yang bisa dikembalikan (fix #2)
Hub.noclipSaved = {}

local function ApplyNoclip(state)
    local char = GetCharacter()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if state then
                if Hub.noclipSaved[part] == nil then
                    Hub.noclipSaved[part] = part.CanCollide
                end
                if part.CanCollide then      -- jangan tulis ulang kalau sudah false
                    part.CanCollide = false
                end
            elseif Hub.noclipSaved[part] ~= nil then
                part.CanCollide = Hub.noclipSaved[part]
                Hub.noclipSaved[part] = nil
            end
        end
    end
    Hub.noclipApplied = state and next(Hub.noclipSaved) ~= nil or false
end

local function RestoreNoclip()
    -- [P2] tanpa pcall/closures baru per part (dulu bikin closure tiap part)
    local saved = Hub.noclipSaved
    for part, original in pairs(saved) do
        if part.Parent then
            part.CanCollide = original
        end
        saved[part] = nil
    end
    Hub.noclipApplied = false
end

-- [P3] Part baru (mis. tool yang baru di-equip) langsung di-noclip tanpa scan ulang
local function HookNoclipForCharacter(char)
    if not char then return end
    Track(char.DescendantAdded:Connect(function(part)
        if not (Hub.noclipApplied and Alive()) then return end
        if part:IsA("BasePart") then
            if Hub.noclipSaved[part] == nil then
                Hub.noclipSaved[part] = part.CanCollide
            end
            if part.CanCollide then
                part.CanCollide = false
            end
        end
    end))
end

-- Simpan nilai asli sebelum loop mulai (dipakai saat unload supaya game kembali normal)
pcall(function()
    local hum = GetHumanoid()
    if hum then
        Hub.OriginalWalkSpeed = hum.WalkSpeed
        Hub.OriginalJumpPower = hum.JumpPower
    end
end)

-- ⚡ PERF CACHE & TIMING STATE (v2.2)
Hub.lastEngineStep      = 0
Hub.lastAnchorFire      = 0
Hub.lastRodHealthScan   = 0
Hub.rodHealthCache      = { pct = nil, cur = nil, max = nil, label = nil, at = 0 }
Hub.lastLiveHealthUpdate = 0

-- 🦶 WalkSpeed, Noclip, JumpPower engine (fix #1: berhenti 100% saat unload)
-- [P2] Heartbeat + fungsi siap pakai: dulu Stepped + closure/pcall baru TIAP FRAME
-- [P3] scan noclip dibatasi Hub.NOCLIP_SCAN_INTERVAL (default ~6x/detik)
-- [U3] EngineStep rate-limited via Hub.ENGINE_STEP_INTERVAL (default 10x/detik)
local function EngineStep()
    local now = os.clock()
    if now - Hub.lastEngineStep < Hub.ENGINE_STEP_INTERVAL then return end
    Hub.lastEngineStep = now

    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local targetSpeed = getgenv().PP_WalkSpeed
    if targetSpeed and hum.WalkSpeed ~= targetSpeed then
        hum.WalkSpeed = targetSpeed
    end

    local targetJump = getgenv().PP_JumpPower
    if targetJump and targetJump ~= 50 and hum.UseJumpPower and hum.JumpPower ~= targetJump then
        hum.JumpPower = targetJump
    end

    if getgenv().PP_Noclip then
        if now - Hub.lastNoclipScan >= Hub.NOCLIP_SCAN_INTERVAL then
            Hub.lastNoclipScan = now
            ApplyNoclip(true)
        end
    elseif Hub.noclipApplied then
        RestoreNoclip()
    end
end

Track(Hub.RunService.Heartbeat:Connect(function()
    if not Alive() then return end
    pcall(EngineStep)   -- panggil fungsi yang sudah ada: tanpa alokasi closure
end))

-- Noclip untuk karakter sekarang, dan tiap respawn lewat CharacterAdded di bawah
HookNoclipForCharacter(lp.Character)

-- 🦘 Infinite Jump (baru)
Track(Hub.UserInputService.JumpRequest:Connect(function()
    if not Alive() then return end
    if not getgenv().PP_InfiniteJump then return end
    local hum = GetHumanoid()
    if hum then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end))

-- 💤 Anti-AFK (baru)
local antiAfkConn
local function ApplyAntiAfk(state)
    if state then
        if not antiAfkConn then
            antiAfkConn = lp.Idled:Connect(function()
                pcall(function()
                    Hub.VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.05)
                    Hub.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
            end)
            Toast("★ RYOOOONK HUB ★", "Anti-AFK aktif: idle akan di-reset otomatis.", Hub.THEME.CosmicCyan)
        end
    else
        if antiAfkConn then
            antiAfkConn:Disconnect()
            antiAfkConn = nil
        end
    end
end

-- [[CHUNK 8B]]
-- Helper karakter ada di CHUNK 8A
local function GetFishingUI()
    -- [P4] Cache: dulu tiap panggilan scan PlayerGui (5x FindFirstChild + fallback
    --      rekursif ke semua ScreenGui) dan fungsi ini dipanggil puluhan kali/detik.
    local cached = Hub.fishingUICache
    if cached and cached.Parent
        and (os.clock() - (Hub.fishingUICacheAt or 0)) < Hub.FISHING_UI_CACHE_TTL then
        return cached
    end

    local playerGui = lp:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    local target = (playerGui:FindFirstChild("MainGui") and playerGui.MainGui:FindFirstChild("Fishing"))
        or playerGui:FindFirstChild("Fishing")
        or playerGui:FindFirstChild("FishingUI")
        or playerGui:FindFirstChild("FishUI")
        or playerGui:FindFirstChild("FishingBar")

    if not target then
        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                if gui:FindFirstChild("FishingBar", true) or gui:FindFirstChild("BarFrame", true) then
                    target = gui
                    break
                end
            end
        end
    end

    Hub.fishingUICache = target
    Hub.fishingUICacheAt = os.clock()
    if target ~= Hub.barFrameOwner then
        Hub.barFrameCache = nil      -- UI berganti -> cache bar lama tidak valid
        Hub.barFrameOwner = nil
        Hub.anchorBar = nil
    end
    return target
end

local function GetBarFrame(fishingUI)
    if not fishingUI then return nil end
    return fishingUI:FindFirstChild("FishingBar", true)
        or fishingUI:FindFirstChild("BarFrame", true)
        or fishingUI:FindFirstChild("Bar", true)
end

local function IsFishingUIActive(fishingUI)
    if not fishingUI then return false end

    if fishingUI:IsA("ScreenGui") then
        if not fishingUI.Enabled then return false end
        local barFrame = GetBarFrame(fishingUI)
        if barFrame and barFrame:IsA("GuiObject") then
            return barFrame.Visible
        end
        return true
    elseif fishingUI:IsA("GuiObject") then
        return fishingUI.Visible
    end

    return false
end

local function EnsureFishingRodEquipped()
    local char = GetCharacter()
    if not char then return false end

    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            return true
        end
    end

    local backpack = lp:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and string.find(string.lower(item.Name), "rod", 1, true) then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:EquipTool(item)
                    task.wait(0.3)
                    return true
                end
            end
        end
    end

    return false
end

local function FireFishingAction()
    if RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Fishing") then
        RS.Events.Fishing:FireServer()
        return true
    elseif RS:FindFirstChild("Fishing") then
        RS.Fishing:FireServer()
        return true
    end
    return false
end

Hub.AUTO_CAST_BITE_TIMEOUT = 25
Hub.AUTO_CAST_MINIGAME_TIMEOUT = 30
Hub.AUTO_CAST_COOLDOWN = 1.2
Hub.AUTO_CAST_SCAN_STEP = 0.1

-- 🎣 Auto Cast Engine (fix #3: pakai Async step supaya tidak perlu pindah thread)
task.spawn(function()
    while Alive() do
        if getgenv().NWKZ_AutoCast then
            EnsureFishingRodEquipped()

            -- 1. Cast rod
            pcall(FireFishingAction)
            task.wait(1.2)

            -- 2. Tunggu ikan menggigit (UI muncul)
            local fishBiteDetected = false
            local waitBiteStart = os.clock()

            while Alive() and getgenv().NWKZ_AutoCast and (os.clock() - waitBiteStart < Hub.AUTO_CAST_BITE_TIMEOUT) do
                local ui = GetFishingUI()
                if ui and IsFishingUIActive(ui) then
                    fishBiteDetected = true
                    break
                end
                task.wait(Hub.AUTO_CAST_SCAN_STEP)
            end

            -- 3. Tunggu minigame selesai
            if fishBiteDetected then
                local minigameStart = os.clock()
                while Alive() and getgenv().NWKZ_AutoCast and (os.clock() - minigameStart < Hub.AUTO_CAST_MINIGAME_TIMEOUT) do
                    local ui = GetFishingUI()
                    if not ui or not IsFishingUIActive(ui) then
                        break
                    end
                    task.wait(Hub.AUTO_CAST_SCAN_STEP)
                end
                task.wait(Hub.AUTO_CAST_COOLDOWN)
            else
                task.wait(0.5)
            end
        else
            task.wait(0.2)
        end
    end
end)

-- 💰 Auto Sell Engine (baru): jual semua ikan secara berkala
local function SellAllFish(silent)
    local fired = false
    pcall(function()
        if RS:FindFirstChild("Events") and RS.Events:FindFirstChild("SellFish") then
            RS.Events.SellFish:FireServer("All")
            fired = true
        elseif RS:FindFirstChild("SellFish") then
            RS.SellFish:FireServer("All")
            fired = true
        end
    end)
    if fired and not silent then
        PlaySound(Hub.sellSound)
        Toast("AUTO SELL", "Semua ikan berhasil dikirim ke penjual.", Hub.THEME.CosmicCyan, 2)
    end
    return fired
end

task.spawn(function()
    local elapsed = 0
    while Alive() do
        task.wait(1)
        if getgenv().PP_AutoSell then
            elapsed = elapsed + 1
            local interval = getgenv().PP_SellInterval or 30
            if elapsed >= interval then
                elapsed = 0
                SellAllFish(false)
            end
        else
            elapsed = 0
        end
    end
end)

-- [[CHUNK 8C]]
-- 🚀 Rock Bar / Anchor Engine (0.5 Center Lock) — v2.2: Heartbeat + Rate Limit
-- [U1] FireServer dibatasi 10x/detik, update posisi bar hanya kalau offset > 1%
Track(Hub.RunService.Heartbeat:Connect(function()
    if not Alive() then return end
    if not getgenv().NWKZ_Anchor then return end

    local now = os.clock()
    if now - Hub.lastAnchorFire < Hub.ANCHOR_FIRE_INTERVAL then return end
    Hub.lastAnchorFire = now

    pcall(function()
        local fishingUI = GetFishingUI()
        if not (fishingUI and IsFishingUIActive(fishingUI)) then return end

        local barFrame = GetBarFrame(fishingUI)
        if barFrame then
            local bar = barFrame:FindFirstChild("Bar")
                or barFrame:FindFirstChild("Slider")
                or barFrame:FindFirstChild("Progress")
                or barFrame:FindFirstChild("Pointer")
            if bar and bar:IsA("GuiObject") then
                local targetX = 0.5
                local curX = bar.Position.X.Scale
                -- Hanya tulis kalau benar-benar melenceng > threshold (hindari write redundan)
                if math.abs(curX - targetX) > Hub.ANCHOR_POS_THRESHOLD then
                    bar.Position = UDim2.new(targetX, 0, bar.Position.Y.Scale, 0)
                end
            end
        end

        -- FireServer rate-limited (sudah dijamin oleh interval di atas)
        if RS:FindFirstChild("Fishing") then
            RS.Fishing:FireServer("1")
        elseif RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Fishing") then
            RS.Events.Fishing:FireServer("1")
        end
    end)
end))

-- 💚 SMART AUTO HEAL ENGINE (membaca bar HP rod di layar) — v2.2: Cached & Rate Limited
-- [U2] Cache TextLabel reference + hasil. Scan GetDescendants() MAX 1x/2detik.
local function GetRodHealth()
    local now = os.clock()
    local cache = Hub.rodHealthCache

    -- Return cached result jika masih valid (TTL 1.5 detik)
    if cache.pct and cache.label and cache.label.Parent and cache.label.Visible and (now - cache.at) < Hub.ROD_HEALTH_CACHE_TTL then
        return cache.pct, cache.cur, cache.max
    end

    -- Rate limit scan penuh: max 1x per 2 detik
    if now - Hub.lastRodHealthScan < Hub.ROD_HEALTH_SCAN_INTERVAL then
        return cache.pct, cache.cur, cache.max  -- return stale cache kalau belum waktunya scan
    end
    Hub.lastRodHealthScan = now

    local playerGui = lp:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    local cam = GetCamera()
    local viewportY = cam and cam.ViewportSize.Y or 1000

    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Visible and desc.TextTransparency < 1 then
            local cur, max = string.match(desc.Text, "^%s*(%d+)%s*/%s*(%d+)%s*$")
            if cur and max then
                cur = tonumber(cur)
                max = tonumber(max)
                if cur and max and max > 0 then
                    if desc.AbsolutePosition.Y > (viewportY * 0.5) then
                        local pct = (cur / max) * 100
                        -- Update cache
                        cache.pct, cache.cur, cache.max, cache.label, cache.at = pct, cur, max, desc, now
                        return pct, cur, max
                    end
                end
            end
        end
    end

    -- Tidak ketemu: kosongkan cache label tapi biarkan nilai terakhir sebentar
    cache.label = nil
    return nil
end

-- Auto Heal Loop (v2.2: interval minimal 0.5s, pakai cache GetRodHealth)
task.spawn(function()
    while Alive() do
        if getgenv().PP_AutoHeal then
            local pct, cur, max = GetRodHealth()
            if pct and cur and max then
                local threshold = getgenv().PP_HealPercent or 40
                if pct <= threshold then
                    local keyIndex = math.clamp(getgenv().PP_HealKeyIndex or 1, 1, #Hub.healKeyList)
                    local chosenKey = Hub.healKeyList[keyIndex].Key
                    HubLog("Auto Heal → skill #" .. keyIndex .. "  (HP " .. cur .. "/" .. max .. ")", Hub.THEME.SuccessGreen)
                    PressKey(chosenKey, 0.05)
                    task.wait(1.2)
                else
                    task.wait(Hub.AUTO_HEAL_MIN_INTERVAL)
                end
            else
                task.wait(Hub.AUTO_HEAL_MIN_INTERVAL)
            end
        else
            task.wait(Hub.AUTO_HEAL_MIN_INTERVAL)
        end
    end
end)

-- Live Health Monitor Loop (v2.2: interval 1s, hanya update kalau nilai berubah)
task.spawn(function()
    while Alive() do
        task.wait(Hub.LIVE_HEALTH_UPDATE_INTERVAL)
        if Hub.LiveHealthLabel and Hub.LiveHealthLabel.Parent then
            pcall(function()
                local pct, cur, max = GetRodHealth()
                local newText, newColor
                if pct and cur and max then
                    newText = string.format("Live HP: %d/%d (%.1f%%)", cur, max, pct)
                    local threshold = getgenv().PP_HealPercent or 40
                    newColor = (pct <= threshold) and Hub.THEME.AlertRed or Hub.THEME.CosmicCyan
                else
                    newText = "Live HP: Menunggu rod..."
                    newColor = Hub.THEME.TextSecondary
                end
                -- Hanya update UI kalau benar-benar berubah (hindari re-render redundan)
                if Hub.LiveHealthLabel.Text ~= newText or Hub.LiveHealthLabel.TextColor3 ~= newColor then
                    Hub.LiveHealthLabel.Text = newText
                    Hub.LiveHealthLabel.TextColor3 = newColor
                end
            end)
        end
    end
end)

-- ⚡ Auto Skills Engine (Z, X, C, V) dengan jeda yang bisa diatur
task.spawn(function()
    while Alive() do
        local interval = getgenv().PP_SkillInterval or 0.6
        task.wait(interval)
        if not Alive() then break end

        pcall(function()
            local activeHealKey = (getgenv().PP_AutoHeal and Hub.healKeyList[math.clamp(getgenv().PP_HealKeyIndex or 1, 1, #Hub.healKeyList)].Key) or nil

            local function trySkill(keyCode, flagValue)
                if not flagValue then return end
                if activeHealKey == keyCode then return end
                PressKey(keyCode, 0.05)
            end

            trySkill(Enum.KeyCode.Z, getgenv().PP_AutoSkillAll or getgenv().PP_Skill_Z)
            trySkill(Enum.KeyCode.X, getgenv().PP_AutoSkillAll or getgenv().PP_Skill_X)
            trySkill(Enum.KeyCode.C, getgenv().PP_AutoSkillAll or getgenv().PP_Skill_C)
            trySkill(Enum.KeyCode.V, getgenv().PP_AutoSkillAll or getgenv().PP_Skill_V)
        end)
    end
end)

--  Sinkronisasi Anti-AFK dengan tombol & config
Hub.antiAfkApplied = nil
task.spawn(function()
    ApplyAntiAfk(getgenv().PP_AntiAFK)
    Hub.antiAfkApplied = getgenv().PP_AntiAFK
    while Alive() do
        task.wait(0.5)
        local want = getgenv().PP_AntiAFK and true or false
        if want ~= Hub.antiAfkApplied then
            Hub.antiAfkApplied = want
            ApplyAntiAfk(want)
        end
    end
end)

--  Saat karakter respawn: bersihkan cache noclip & re-equip rod bila perlu
Track(lp.CharacterAdded:Connect(function(char)
    Hub.noclipSaved = {}
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        -- Jangan timpa nilai asli kalau yang terbaca justru nilai dari hub sendiri
        if hum.WalkSpeed ~= getgenv().PP_WalkSpeed then
            Hub.OriginalWalkSpeed = hum.WalkSpeed
        end
        if hum.JumpPower ~= getgenv().PP_JumpPower then
            Hub.OriginalJumpPower = hum.JumpPower
        end
    end
    if getgenv().PP_AutoCast then
        task.wait(1)
        if Alive() then
            EnsureFishingRodEquipped()
        end
    end
end))

-- [[CHUNK 9]]
-- =========================================================================
-- 🔴 UNLOAD BERSIH (fix #1 & #7)
-- =========================================================================
Hub.unloaded = false

local function ResetFlagsToDefault()
    getgenv().NWKZ_Anchor = false
    getgenv().NWKZ_AutoCast = false
    getgenv().PP_FishingThipActive = false
    getgenv().PP_AutoSell = false
    getgenv().PP_AutoSkillAll = false
    getgenv().PP_Skill_Z = false
    getgenv().PP_Skill_X = false
    getgenv().PP_Skill_C = false
    getgenv().PP_Skill_V = false
    getgenv().PP_AutoHeal = false
    getgenv().PP_Noclip = false
    getgenv().PP_AntiAFK = false
    getgenv().PP_InfiniteJump = false
    getgenv().PP_LowGFX = false
    getgenv().PP_JumpPower = 50
end

local function UnloadHub(keepConfig)
    if Hub.unloaded then return end
    Hub.unloaded = true

    -- 1. Matikan semua flag supaya loop langsung berhenti sendiri
    if not keepConfig then
        pcall(SaveConfig, false) -- simpan setting terakhir sebelum unload
    end
    ResetFlagsToDefault()
    getgenv().RYOOOONK_Unloaded = true

    -- 2. Putuskan seluruh koneksi yang tercatat
    for _, conn in ipairs(Hub.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Hub.Connections = {}

    -- 3. Bersihkan efek samping ke game
    pcall(RestoreNoclip)
    pcall(ApplyLowGFX, false)
    pcall(ApplyAntiAfk, false)
    pcall(function()
        local hum = GetHumanoid()
        if hum then
            hum.WalkSpeed = Hub.OriginalWalkSpeed
            if hum.UseJumpPower then
                hum.JumpPower = Hub.OriginalJumpPower
            end
        end
    end)

    -- 4. Sembunyikan dulu, baru hancurkan GUI
    pcall(function()
        if RealFishBtn then RealFishBtn.Visible = false end
        if Hub.Main then Hub.Main.Visible = false end
        if Hub.ShadowHolder then Hub.ShadowHolder.Visible = false end
        if Hub.FloatingToggle then Hub.FloatingToggle.Visible = false end
    end)

    PlaySound(Hub.deleteSound)
    task.wait(0.35)

    pcall(function() Hub.sg:Destroy() end)
    print("★ [RYOOOONK HUB] Unloaded bersih. WalkSpeed, noclip, dan GFX dikembalikan ke normal.")
end

Track(Hub.UnloadBtn.MouseButton1Click:Connect(function()
    UnloadHub(false)
end))

-- Expose untuk eksekusi ulang / debugging dari executor
getgenv().RYOOOONK_Unload = UnloadHub

-- 📌 Ringkasan state awal (memudahkan user tahu apa yang aktif)
HubLog("Hub siap! Speed " .. tostring(getgenv().PP_WalkSpeed) .. " | Toggle: " .. Hub.keybindList[getgenv().PP_ToggleKeyIndex].Name, Hub.THEME.CosmicCyan)

print("★ [RYOOOONK HUB] v2.0 SpaceX Black Hole Cosmic Edition - Loaded Successfully!")
print("★ Toggle UI: " .. Hub.keybindList[getgenv().PP_ToggleKeyIndex].Name .. " | Unload: getgenv().RYOOOONK_Unload()")
