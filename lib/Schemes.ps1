#Requires -Version 5.1
<#
  lib/Schemes.ps1 —— 界面方案引擎（数据 + 渲染）

  设计要点
  ----------
  1. 一个「界面方案」= 一份配方（hashtable），只描述外观：底/边/圆角/阴影/排版/装饰层/配色族。
     新增方案 = 在 $script:UiSchemes 里加一条配方，不用碰时间逻辑。
  2. 切换方案只改属性、只切装饰层显隐，不重建元素树（除非换 layout），
     所以高峰/空闲每秒刷新不受影响。
  3. 三种布局模板（card / capsule / dial）刻意使用同一套元素名，
     这样 Update-Widget 不需要为每种布局写分支。
  4. 本文件被 DeepSeekClock.ps1 dot-source；数据部分不依赖 WPF，可单独测试。
#>

# ============================ 配色族 ============================
# tone    ：中性文字色（与状态无关）
# palette ：状态色（高峰/空闲各自的强调色）

$script:SchemeTones = @{
    dark  = @{ Clock = '#F8FAFC'; Week = '#CBD5E1'; Date = '#7C8AA5'; Hint = '#5B6B82'; Marker = '#FFFFFF' }
    light = @{ Clock = '#0F172A'; Week = '#334155'; Date = '#64748B'; Hint = '#94A3B8'; Marker = '#0F172A' }
    paper = @{ Clock = '#1C1917'; Week = '#44403C'; Date = '#78716C'; Hint = '#A8A29E'; Marker = '#1C1917' }
    lcd   = @{ Clock = '#7DF7A8'; Week = '#3FD97C'; Date = '#22A85C'; Hint = '#166534'; Marker = '#7DF7A8' }
    mono  = @{ Clock = '#E5E7EB'; Week = '#9CA3AF'; Date = '#6B7280'; Hint = '#4B5563'; Marker = '#E5E7EB' }
    # 暖棕黑底 + 琥珀字（点阵液晶 E5）
    amber = @{ Clock = '#FFD166'; Week = '#C08A2E'; Date = '#C08A2E'; Hint = '#8A6A2E'; Marker = '#FFD166' }
}

# Text 里的 onAccent=true 表示文字要压在满版状态色上，用深色
$script:SchemePalettes = @{
    'glass-dark' = @{
        Peak = @{ Accent = '#F59E0B'; AccentSoft = '#FCD34D'; BadgeBg = '#22F59E0B'; Track = '#332A3A4D'; Segment = '#F59E0B'; Glow = $true }
        Idle = @{ Accent = '#34D399'; AccentSoft = '#6EE7B7'; BadgeBg = '#2234D399'; Track = '#3D34D399'; Segment = '#F59E0B'; Glow = $true }
        Badge = 'tint'
    }
    'glass-light' = @{
        Peak = @{ Accent = '#D97706'; AccentSoft = '#B45309'; BadgeBg = '#33F59E0B'; Track = '#1F0F172A'; Segment = '#F59E0B'; Glow = $false }
        Idle = @{ Accent = '#059669'; AccentSoft = '#047857'; BadgeBg = '#3334D399'; Track = '#1F0F172A'; Segment = '#D97706'; Glow = $false }
        Badge = 'tint'
    }
    'panel' = @{
        Peak = @{ Accent = '#FFB020'; AccentSoft = '#FFD166'; BadgeBg = '#26FFB020'; Track = '#1AFFFFFF'; Segment = '#FFB020'; Glow = $false }
        Idle = @{ Accent = '#37E0A0'; AccentSoft = '#7CF0C4'; BadgeBg = '#2637E0A0'; Track = '#1AFFFFFF'; Segment = '#FFB020'; Glow = $false }
        Badge = 'tint'
    }
    'paper' = @{
        Peak = @{ Accent = '#B45309'; AccentSoft = '#92400E'; BadgeBg = '#1AB45309'; Track = '#1F1C1917'; Segment = '#B45309'; Glow = $false }
        Idle = @{ Accent = '#0F766E'; AccentSoft = '#115E59'; BadgeBg = '#1A0F766E'; Track = '#1F1C1917'; Segment = '#B45309'; Glow = $false }
        Badge = 'tint'
    }
    'solid' = @{
        Peak = @{ Accent = '#F59E0B'; AccentSoft = '#0A0D14'; BadgeBg = '#1F000000'; Track = '#33000000'; Segment = '#0A0D14'; Glow = $false; OnAccent = $true }
        Idle = @{ Accent = '#34D399'; AccentSoft = '#052E22'; BadgeBg = '#1F000000'; Track = '#33000000'; Segment = '#0A0D14'; Glow = $false; OnAccent = $true }
        Badge = 'onAccent'
    }
    'brutal' = @{
        Peak = @{ Accent = '#111111'; AccentSoft = '#3F3F46'; BadgeBg = '#111111'; Track = '#22000000'; Segment = '#111111'; Glow = $false }
        Idle = @{ Accent = '#111111'; AccentSoft = '#3F3F46'; BadgeBg = '#111111'; Track = '#22000000'; Segment = '#111111'; Glow = $false }
        Badge = 'solid'
    }
    'lcd' = @{
        Peak = @{ Accent = '#FFB020'; AccentSoft = '#FFD166'; BadgeBg = '#26FFB020'; Track = '#1A7DF7A8'; Segment = '#FFB020'; Glow = $true }
        Idle = @{ Accent = '#7DF7A8'; AccentSoft = '#B9FFD0'; BadgeBg = '#1A7DF7A8'; Track = '#1A7DF7A8'; Segment = '#FFB020'; Glow = $true }
        Badge = 'tint'
    }
    'scope' = @{
        Peak = @{ Accent = '#F87171'; AccentSoft = '#FCA5A5'; BadgeBg = '#26F87171'; Track = '#1AFFFFFF'; Segment = '#F87171'; Glow = $true }
        Idle = @{ Accent = '#4ADE80'; AccentSoft = '#86EFAC'; BadgeBg = '#264ADE80'; Track = '#1AFFFFFF'; Segment = '#F87171'; Glow = $true }
        Badge = 'tint'
    }
    # F1 峰谷示波器：网页稿整卡是琥珀色，峰谷用同一套色，只换文案
    'amber-scope' = @{
        Peak = @{ Accent = '#F59E0B'; AccentSoft = '#FCD34D'; BadgeBg = '#26F59E0B'; Track = '#1AF59E0B'; Segment = '#F59E0B'; Glow = $true }
        Idle = @{ Accent = '#34D399'; AccentSoft = '#6EE7B7'; BadgeBg = '#2634D399'; Track = '#1A34D399'; Segment = '#34D399'; Glow = $true }
        Badge = 'tint'
    }
    # E5 点阵液晶：整屏琥珀，空闲时压暗一档，不换色相
    'amber-crt' = @{
        Peak = @{ Accent = '#FFB020'; AccentSoft = '#FFD166'; BadgeBg = '#26FFB020'; Track = '#1AFFB020'; Segment = '#FFB020'; Glow = $true }
        Idle = @{ Accent = '#D99A2B'; AccentSoft = '#E8B961'; BadgeBg = '#26D99A2B'; Track = '#1AD99A2B'; Segment = '#D99A2B'; Glow = $false }
        Badge = 'tint'
    }
    # E4 双色瑞士分屏：左栏实色就是状态色
    'swiss' = @{
        Peak = @{ Accent = '#C2600A'; AccentSoft = '#F5A623'; BadgeBg = '#26C2600A'; Track = '#1AFFFFFF'; Segment = '#F5A623'; Glow = $false }
        Idle = @{ Accent = '#1F7A6B'; AccentSoft = '#2AB5A0'; BadgeBg = '#261F7A6B'; Track = '#1AFFFFFF'; Segment = '#2AB5A0'; Glow = $false }
        Badge = 'tint'
    }
    # D3 K 线：标题跟着状态换（峰橙红 / 谷青绿），蜡烛本身固定双色
    'kline' = @{
        Peak = @{ Accent = '#E4552E'; AccentSoft = '#F08A6E'; BadgeBg = '#26E4552E'; Track = '#1AFFFFFF'; Segment = '#E4552E'; Glow = $false }
        Idle = @{ Accent = '#2E9E85'; AccentSoft = '#5FC4AE'; BadgeBg = '#262E9E85'; Track = '#1AFFFFFF'; Segment = '#2E9E85'; Glow = $false }
        Badge = 'tint'
    }
    # D6 半谷：整卡都是白字，压在橙 / 青双色块上
    'half' = @{
        Peak = @{ Accent = '#FFFFFF'; AccentSoft = '#FFE8E0'; BadgeBg = '#26FFFFFF'; Track = '#1AFFFFFF'; Segment = '#FFFFFF'; Glow = $false }
        Idle = @{ Accent = '#FFFFFF'; AccentSoft = '#E8FFF9'; BadgeBg = '#26FFFFFF'; Track = '#1AFFFFFF'; Segment = '#FFFFFF'; Glow = $false }
        Badge = 'tint'
    }
}

# ============================ 配方默认值 ============================

$script:SchemeDefaults = @{
    Num       = ''
    Layout    = 'card'
    Width     = 316
    Height    = 0          # 0 = 高度自适应
    Tone      = 'dark'
    Palette   = 'glass-dark'
    ClockFont = 'Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI'
    ClockSize = 34
    WeekSize  = 13
    Radius    = 18
    Margin    = 14
    BodyPad   = '16,13,16,13'
    StatusSize = 18
    Surface   = @{ Type = 'gradient'; From = '#FC182233'; To = '#FC0B1018' }
    Border    = '#26FFFFFF'
    BorderWidth = 1
    Shadow    = @{ Blur = 20; Depth = 5; Opacity = 0.5; Color = '#000000' }
    StatusDot = $true
    HideStatus = $false
    SurfaceByState = $false
    AccentBar = $false
    Badge     = 'auto'     # auto = 跟随配色族
    Timeline  = $true
    Decor     = @()
    CountdownSize = 12
    # ---- 网页稿的通用排版开关 ----
    PlainRate = $false       # 价格只写「1.0×」，不带药丸底和「价格」前缀
    RateSize  = 10.5
    StatusPillStyle = $false # 状态是药丸（带底色/描边）还是裸排
    StatusSquare = $false    # 状态标记用方块（C6 / E3 那种）而不是圆点
    ClockSecSize = 15        # 时钟后面「:24」的字号
    DateInline = $false      # 日期排在时钟下方一行（「10月28日 周三」），否则右对齐竖排
    CdIdle = ''              # 倒计时标签（下一次是空闲），留空用「距空闲」
    CdPeak = ''              # 倒计时标签（下一次是高峰），留空用「距高峰」
    Text      = @{}
}

function New-SchemeSpec {
    param([hashtable]$Spec)

    $merged = @{}
    foreach ($name in $script:SchemeDefaults.Keys) {
        $merged[$name] = $script:SchemeDefaults[$name]
    }
    foreach ($name in $Spec.Keys) {
        $merged[$name] = $Spec[$name]
    }
    if (-not $merged.ContainsKey('Name')) { $merged['Name'] = $merged['Key'] }
    return [pscustomobject]$merged
}

# ============================ 方案清单 ============================
# 顺序即右键菜单顺序：默认界面在最前，其余按 A/B/C/D/E/F 分组。
# 每条配方都在菜单里可直接切，不存在「预览有、程序没有」的方案。

$script:UiSchemes = @()

function Add-Scheme {
    param([hashtable]$Spec)
    $script:UiSchemes += (New-SchemeSpec -Spec $Spec)
}

# ---------- 默认界面（原来的线上 v1.0，L1–L4 四种状态共用这一套）----------
Add-Scheme @{
    Key = 'default'; Num = ''; Name = '默认界面'
    Hint = '深色玻璃渐变 + 状态点光晕（原来线上那一版）'
    Layout = 'card'; Width = 316
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#FC182233'; To = '#FC0B1018' }
}

# ---------- A · 初版液态玻璃 ----------
Add-Scheme @{
    Key = 'a1'; Num = 'A1'; Name = 'A1 · 极简折射流光'
    Hint = '克制通透的玻璃 + 一道缓慢扫过的折射光'
    Layout = 'card'; Width = 316
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#D92A3448'; To = '#E6101620' }
    Border = '#38FFFFFF'; BorderWidth = 1; Radius = 20
    Shadow = @{ Blur = 26; Depth = 6; Opacity = 0.45; Color = '#000000' }
    Decor = @('sheen')
}

Add-Scheme @{
    Key = 'a3'; Num = 'A3'; Name = 'A3 · 灵动极简胶囊'
    Hint = '横向胶囊 500×120，左侧状态光球呼吸，最省桌面空间'
    Layout = 'capsule'; Width = 500; Height = 120
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#E61A2233'; To = '#F00B1018' }
    Radius = 26; BodyPad = '18,9,18,9'
    ClockSize = 38; StatusSize = 15; CountdownSize = 12
    Decor = @('orb')
}

Add-Scheme @{
    Key = 'a5'; Num = 'A5'; Name = 'A5 · 霜白明澈玻璃'
    Hint = '浅色壁纸首选：霜白玻璃 + 深色字，像控制中心'
    Layout = 'card'; Width = 316
    Tone = 'light'; Palette = 'glass-light'
    Surface = @{ Type = 'gradient'; From = '#F2FFFFFF'; To = '#E6E8EEF6' }
    Border = '#80FFFFFF'; BorderWidth = 1; Radius = 20
    Shadow = @{ Blur = 24; Depth = 6; Opacity = 0.22; Color = '#1E293B' }
}

Add-Scheme @{
    Key = 'a6'; Num = 'A6'; Name = 'A6 · 24h 环形轨道玻璃'
    Hint = '圆形表盘 Ø300，外圈 24 小时轨道，当前时刻一根指针'
    Layout = 'dial'; Width = 300; Height = 300
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#F0182233'; To = '#F00B1018' }
    Radius = 150; Margin = 10; BodyPad = '0,52,0,44'
    ClockSize = 40; StatusSize = 15
    Timeline = $false
    Decor = @('ring')
}

# ---------- B · v2 玻璃材质深化 ----------
Add-Scheme @{
    Key = 'b1'; Num = 'B1'; Name = 'B1 · 深空琥珀'
    Hint = '深色厚玻璃，状态光晕从右上角渗出'
    Layout = 'card'; Width = 316
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'radial'; From = '#24F59E0B'; To = '#F00A0D14'; Center = '0.92,0.06' }
    Radius = 20
    Text = @{ Date = '#A9B6C9'; Hint = '#7C8AA5' }
    Decor = @('glowcorner')
}

Add-Scheme @{
    Key = 'b3'; Num = 'B3'; Name = 'B3 · 流光胶囊'
    Hint = '横向胶囊 500×120，左侧光球呼吸 + 右侧信息横排，像桌面小宠物'
    Layout = 'capsule'; Width = 500; Height = 120
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#F0141A24'; To = '#F0080A0F' }
    Radius = 26; BodyPad = '18,9,18,9'
    ClockSize = 36; StatusSize = 15
    Decor = @('orb')
}

Add-Scheme @{
    Key = 'b4'; Num = 'B4'; Name = 'B4 · 石英表盘'
    Hint = '24 小时压成一圈，两段高峰弧 + 当前时刻指针'
    Layout = 'dial'; Width = 300; Height = 300
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#F0161C26'; To = '#F006080C' }
    Radius = 150; Margin = 10; BodyPad = '0,58,0,40'
    ClockSize = 38; StatusSize = 14
    Timeline = $false
    Decor = @('quartz')
}

Add-Scheme @{
    Key = 'b5'; Num = 'B5'; Name = 'B5 · 熔岩边缘'
    Hint = '去掉流光颗粒，只留左侧 3px 状态光柱，最安静'
    Layout = 'card'; Width = 316
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#1E2028'; To = '#090A0E' }
    Border = '#1AFFFFFF'; Radius = 16
    StatusDot = $false; AccentBar = $true
    Shadow = @{ Blur = 24; Depth = 6; Opacity = 0.55; Color = '#000000' }
}

# ---------- C · v3 仪器方向 ----------
Add-Scheme @{
    Key = 'c1'; Num = 'C1'; Name = 'C1 · 仪表盘'
    Hint = '实色仪器面板 + 等宽数字 + 底部刻度尺'
    Layout = 'card'; Width = 316
    Tone = 'mono'; Palette = 'panel'
    ClockFont = 'Consolas, Cascadia Mono, Microsoft YaHei UI'
    ClockSize = 32
    Surface = @{ Type = 'solid'; From = '#10151C'; To = '#10151C' }
    Border = '#2A3441'; Radius = 10
    Shadow = @{ Blur = 16; Depth = 4; Opacity = 0.4; Color = '#000000' }
    BodyPad = '16,13,16,28'
    Timeline = $false
    Decor = @('ticks')
}

Add-Scheme @{
    Key = 'c2'; Num = 'C2'; Name = 'C2 · 报表'
    Hint = '米白纸感 + 衬线数字，左侧 4px 竖色条是唯一状态信号'
    Layout = 'card'; Width = 316
    Tone = 'paper'; Palette = 'paper'
    ClockFont = 'Cambria, Georgia, Microsoft YaHei UI'
    ClockSize = 34
    Surface = @{ Type = 'solid'; From = '#F7F3EA'; To = '#F7F3EA' }
    Border = '#E2D9C8'; Radius = 4
    Shadow = @{ Blur = 14; Depth = 3; Opacity = 0.18; Color = '#57534E' }
    AccentBar = $true
}

Add-Scheme @{
    Key = 'c3'; Num = 'C3'; Name = 'C3 · 刻度带'
    Hint = '520×120 横向窄条，整条刻度尺贯穿底部'
    Layout = 'capsule'; Width = 520; Height = 120
    Tone = 'mono'; Palette = 'panel'
    ClockFont = 'Consolas, Cascadia Mono, Microsoft YaHei UI'
    ClockSize = 32
    Surface = @{ Type = 'solid'; From = '#0E1319'; To = '#0E1319' }
    Border = '#232C38'; Radius = 8
    BodyPad = '18,9,18,9'
    Timeline = $false
    Decor = @('ticks')
}

Add-Scheme @{
    Key = 'c4'; Num = 'C4'; Name = 'C4 · 圆表'
    Hint = '真仪表盘 Ø300：外圈刻度 + 内环高峰弧 + 白色游标'
    Layout = 'gauge'; Width = 300; Height = 300
    Tone = 'mono'; Palette = 'panel'
    ClockFont = 'Consolas, Cascadia Mono, Microsoft YaHei UI'
    ClockSize = 26
    Surface = @{ Type = 'solid'; From = '#12161D'; To = '#12161D' }
    Border = '#1E242E'; BorderWidth = 1
    Radius = 150; Margin = 10; BodyPad = '0,-10,0,10'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 22; Depth = 5; Opacity = 0.5; Color = '#000000' }
    Text = @{ Status = '#1A1A1A'; Week = '#8A94A6'; Date = '#8A94A6' }
    Decor = @('gauge')
}

Add-Scheme @{
    Key = 'c6'; Num = 'C6'; Name = 'C6 · 色块'
    Hint = '整块底色就是状态：高峰满版琥珀、空闲满版青绿'
    Layout = 'solid'; Width = 280; Height = 182
    Tone = 'light'; Palette = 'solid'
    Surface = @{ Type = 'solid'; From = '#E8A33D'; To = '#E8A33D' }
    Border = '#00000000'; BorderWidth = 0; Radius = 10; Margin = 12
    StatusDot = $false; Timeline = $false
    BodyPad = '16,12,16,10'
    SurfaceByState = $true
    Shadow = @{ Blur = 18; Depth = 4; Opacity = 0.45; Color = '#000000' }
    Text = @{ Rate = '#111111' }
    Decor = @('scalebar')
}

# ---------- D · v4 波峰波谷 ----------
Add-Scheme @{
    Key = 'd1'; Num = 'D1'; Name = 'D1 · 示波器'
    Hint = '一整天画成一条连续波形：两个平台是峰，中间凹陷是谷'
    Layout = 'card'; Width = 320
    Tone = 'dark'; Palette = 'scope'
    ClockFont = 'Consolas, Cascadia Mono, Microsoft YaHei UI'
    ClockSize = 32
    Surface = @{ Type = 'solid'; From = '#0B0F14'; To = '#0B0F14' }
    Border = '#1E2836'; Radius = 12
    BodyPad = '16,13,16,38'
    Timeline = $false
    Decor = @('wave')
}

Add-Scheme @{
    Key = 'd3'; Num = 'D3'; Name = 'D3 · K 线'
    Hint = '24 根蜡烛，越高越贵；高峰橙红粗柱、空闲暗绿矮块'
    Layout = 'candle'; Width = 316; Height = 230
    Tone = 'dark'; Palette = 'kline'
    ClockFont = 'Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI'
    ClockSize = 33
    Surface = @{ Type = 'solid'; From = '#131313'; To = '#131313' }
    Border = '#262626'; BorderWidth = 1; Radius = 12; Margin = 12
    BodyPad = '14,12,14,10'
    Timeline = $false; StatusDot = $false
    Decor = @('kline')
}

Add-Scheme @{
    Key = 'd6'; Num = 'D6'; Name = 'D6 · 半谷'
    Hint = '整块斜切成两半，红是峰、绿是谷，面积比就是时长比'
    Layout = 'half'; Width = 300; Height = 206
    Tone = 'dark'; Palette = 'half'
    ClockSize = 38
    Surface = @{ Type = 'solid'; From = '#E4552E'; To = '#E4552E' }
    Border = '#00000000'; BorderWidth = 0; Radius = 14; Margin = 12
    BodyPad = '16,14,16,12'
    Timeline = $false; StatusDot = $false
    Text = @{ Status = '#FFFFFF'; Clock = '#FFFFFF'; Week = '#FFE8E0'; Date = '#FFE8E0'; Hint = '#F3C4B4' }
    Shadow = @{ Blur = 20; Depth = 5; Opacity = 0.4; Color = '#000000' }
    Decor = @('halfsplit')
}

# ---------- E · 全新风格 ----------
Add-Scheme @{
    Key = 'e2'; Num = 'E2'; Name = 'E2 · 工业级仪表 HUD'
    Hint = '顶部琥珀条 + 描边框 + 8 段发光进度，随当前窗口实时推进'
    Layout = 'hud'; Width = 290; Height = 198
    Tone = 'mono'; Palette = 'lcd'
    ClockFont = 'Consolas, Cascadia Mono, Microsoft YaHei UI'
    ClockSize = 30
    Surface = @{ Type = 'solid'; From = '#111318'; To = '#111318' }
    Border = '#242833'; BorderWidth = 1; Radius = 4; Margin = 12
    BodyPad = '14,13,14,12'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 18; Depth = 4; Opacity = 0.45; Color = '#000000' }
    Decor = @('hudprogress')
}

Add-Scheme @{
    Key = 'e3'; Num = 'E3'; Name = 'E3 · 新野兽派'
    Hint = '白底 + 2px 黑边 + 零模糊硬投影，高对比年轻化'
    Layout = 'brutal'; Width = 290; Height = 226
    Tone = 'light'; Palette = 'brutal'
    Surface = @{ Type = 'solid'; From = '#FFFFFF'; To = '#FFFFFF' }
    Border = '#111111'; BorderWidth = 2; Radius = 0; Margin = 12
    BodyPad = '14,12,14,12'
    ClockSize = 38
    StatusDot = $false; Timeline = $false
    Text = @{ Status = '#111111'; Clock = '#111111'; Week = '#111111'; Date = '#111111'; Hint = '#52525B' }
    Shadow = @{ Blur = 0; Depth = 5; Opacity = 1; Color = '#111111' }
}

Add-Scheme @{
    Key = 'e4'; Num = 'E4'; Name = 'E4 · 双色瑞士分屏'
    Hint = '左侧实色状态铭牌（高峰/PEAK/1.0×/工作日）+ 右侧黑曜石大字'
    Layout = 'split'; Width = 330; Height = 172
    Tone = 'dark'; Palette = 'swiss'
    Surface = @{ Type = 'solid'; From = '#141414'; To = '#141414' }
    Border = '#00000000'; BorderWidth = 0; Radius = 0; Margin = 10
    ClockSize = 32
    StatusDot = $false; HideStatus = $true; Timeline = $false
    BodyPad = '16,14,16,12'
    Shadow = @{ Blur = 18; Depth = 4; Opacity = 0.45; Color = '#000000' }
}

Add-Scheme @{
    Key = 'e5'; Num = 'E5'; Name = 'E5 · 点阵液晶'
    Hint = '暖棕黑底 + 琥珀液晶数字，屏槽框 + 双虚线分隔'
    Layout = 'lcd'; Width = 310; Height = 178
    Tone = 'amber'; Palette = 'amber-crt'
    ClockFont = 'Consolas, Cascadia Mono, Microsoft YaHei UI'
    ClockSize = 40
    Surface = @{ Type = 'solid'; From = '#241A10'; To = '#241A10' }
    Border = '#4A3820'; BorderWidth = 1; Radius = 8; Margin = 10
    BodyPad = '14,12,14,12'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 20; Depth = 5; Opacity = 0.5; Color = '#000000' }
    Text = @{ Rate = '#C08A2E'; Status = '#E8B961' }
}

# ---------- F · 梗图向 ----------
Add-Scheme @{
    Key = 'f1'; Num = 'F1'; Name = 'F1 · 峰谷示波器'
    Hint = '琥珀描边波形框：两个圆峰 + 峰顶 PEAK 标记 + 当前时刻竖虚线'
    Layout = 'scope'; Width = 300; Height = 220
    Tone = 'dark'; Palette = 'amber-scope'
    ClockFont = 'Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI'
    ClockSize = 29
    Surface = @{ Type = 'solid'; From = '#0E1116'; To = '#0E1116' }
    Border = '#1E2836'; BorderWidth = 1; Radius = 14; Margin = 12
    BodyPad = '12,10,12,10'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 20; Depth = 5; Opacity = 0.5; Color = '#000000' }
    Text = @{ Hint = '#475569'; Week = '#94A3B8'; Date = '#94A3B8' }
    Decor = @('scope')
}

# ============================ 网页稿对齐补丁 ============================
# 逐个方案把「网页稿里到底怎么排的」补进来，全是排版开关，不动配色。
# 判断依据是 design/ 下 7 份原稿 + live-v1-states.html 的实际截图，
# 对照脚本：tools/capture-web-refs.mjs（把每张卡片单独截出来）。
$script:SchemeTweaks = @{
    # 默认界面：价格是药丸，倒计时整句「距空闲时段还有」
    'default' = @{ ClockSecSize = 16; RateSize = 11; CdIdle = '距空闲时段还有'; CdPeak = '距高峰时段还有' }
    # A1 / A5：状态和价格都是药丸（带底色和细描边）
    'a1'      = @{ StatusSize = 15; StatusPillStyle = $true; RateSize = 11; CdIdle = '距空闲时段还有'; CdPeak = '距高峰时段还有' }
    'a5'      = @{ StatusSize = 15; StatusPillStyle = $true; RateSize = 11; CdIdle = '距空闲时段还有'; CdPeak = '距高峰时段还有' }
    # B 组：价格是裸文字「1.0×」，字号明显大于小标签
    'b1'      = @{ StatusSize = 14; DateInline = $true; PlainRate = $true; RateSize = 17; ClockSecSize = 17; CdIdle = '距空闲'; CdPeak = '距高峰' }
    'b5'      = @{ StatusSize = 14; DateInline = $true; PlainRate = $true; RateSize = 17; ClockSecSize = 17; CdIdle = '距空闲'; CdPeak = '距高峰' }
    # C 组：仪表类，时钟全同号（等宽），价格裸文字
    'c1'      = @{ StatusSize = 13; DateInline = $true; PlainRate = $true; RateSize = 17; StatusPillStyle = $true; StatusPillSolid = $true; ClockSecSize = 34; CdIdle = '距空闲'; CdPeak = '距高峰' }
    'c2'      = @{ StatusSize = 13; DateInline = $true; PlainRate = $true; RateSize = 17; ClockSecSize = 34; CdIdle = '距空闲'; CdPeak = '距高峰' }
    'c6'      = @{ StatusSize = 15; DateInline = $true; PlainRate = $true; RateSize = 17; StatusSquare = $true; ClockSecSize = 30; CdIdle = '距空闲'; CdPeak = '距高峰' }
    # D 组：梗图向，倒计时写成「距梁文谷 / 距梁文峰」
    'd1'      = @{ StatusSize = 15; DateInline = $true; PlainRate = $true; RateSize = 17; ClockSecSize = 17; CdIdle = '距梁文谷'; CdPeak = '距梁文峰' }
    'd3'      = @{ StatusSize = 15; DateInline = $true; PlainRate = $true; RateSize = 17; ClockSecSize = 17; CdIdle = '距梁文谷'; CdPeak = '距梁文峰' }
    'd6'      = @{ StatusSize = 15; DateInline = $true; PlainRate = $true; RateSize = 17; ClockSecSize = 17; CdIdle = '距梁文谷'; CdPeak = '距梁文峰' }
    # E 组：工业 HUD / 液晶，全英文等宽标签
    'e2'      = @{ StatusSize = 13; DateInline = $true; PlainRate = $true; RateSize = 13; StatusPillStyle = $true; ClockSecSize = 30; CdIdle = 'NEXT IDLE IN:'; CdPeak = 'NEXT PEAK IN:' }
    'e3'      = @{ StatusSize = 12; DateInline = $true; PlainRate = $true; RateSize = 17; ClockSecSize = 34; CdIdle = '距空闲倒计时'; CdPeak = '距高峰倒计时'; Timeline = $false }
    'e4'      = @{ StatusSize = 15; DateInline = $true; PlainRate = $true; RateSize = 17; ClockSecSize = 34; CdIdle = '距空闲'; CdPeak = '距高峰'; Timeline = $false }
    'e5'      = @{ StatusSize = 14; DateInline = $true; PlainRate = $true; RateSize = 13; StatusPillStyle = $true; ClockSecSize = 36; CdIdle = 'NEXT IDLE:'; CdPeak = 'NEXT PEAK:' }
    # F1：倒计时带价格后缀
    'f1'      = @{ StatusSize = 14; DateInline = $true; PlainRate = $true; RateSize = 14; ClockSecSize = 16; CdIdle = '距入谷 (0.5×)'; CdPeak = '距入峰 (1.0×)' }
}

foreach ($key in $script:SchemeTweaks.Keys) {
    for ($i = 0; $i -lt $script:UiSchemes.Count; $i++) {
        if ([string]$script:UiSchemes[$i].Key -ne $key) { continue }
        $tweak = $script:SchemeTweaks[$key]
        foreach ($name in $tweak.Keys) {
            $script:UiSchemes[$i] | Add-Member -NotePropertyName $name -NotePropertyValue $tweak[$name] -Force
        }
    }
}

# ============================ 查询 ============================

$script:SchemeIndex = @{}
foreach ($scheme in $script:UiSchemes) {
    $script:SchemeIndex[[string]$scheme.Key] = $scheme
}

function Get-SchemeSpec {
    param([string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key)) { return $script:SchemeIndex['default'] }
    if ($script:SchemeIndex.ContainsKey($Key)) { return $script:SchemeIndex[$Key] }
    return $script:SchemeIndex['default']
}

function Test-SchemeKey {
    param([string]$Key)
    return $script:SchemeIndex.ContainsKey([string]$Key)
}

function Get-SchemeNeighbor {
    param([string]$Key, [int]$Step)
    $count = $script:UiSchemes.Count
    if ($count -eq 0) { return 'default' }
    $index = 0
    for ($i = 0; $i -lt $count; $i++) {
        if ([string]$script:UiSchemes[$i].Key -eq [string]$Key) { $index = $i; break }
    }
    $index = (($index + $Step) % $count + $count) % $count
    return [string]$script:UiSchemes[$index].Key
}

# 状态色：把配色族 + tone 合成一份「这次该用什么颜色」的表
function Get-SchemeColors {
    param([object]$Spec, [object]$Status)
    $palette = $script:SchemePalettes[[string]$Spec.Palette]
    if ($null -eq $palette) { $palette = $script:SchemePalettes['glass-dark'] }
    $state = $palette.Idle
    if ($Status.IsPeak) { $state = $palette.Peak }
    $tone = $script:SchemeTones[[string]$Spec.Tone]
    if ($null -eq $tone) { $tone = $script:SchemeTones['dark'] }

    $colors = @{
        Accent     = [string]$state.Accent
        AccentSoft = [string]$state.AccentSoft
        BadgeBg    = [string]$state.BadgeBg
        Track      = [string]$state.Track
        Segment    = [string]$state.Segment
        Glow       = [bool]$state.Glow
        Clock      = [string]$tone.Clock
        Week       = [string]$tone.Week
        Date       = [string]$tone.Date
        Hint       = [string]$tone.Hint
        Marker     = [string]$tone.Marker
        Badge      = [string]$palette.Badge
        OnAccent   = [bool]$state.OnAccent
        Status     = [string]$state.Accent
    }
    # 方案级覆写（个别方案需要特殊文字色时用）
    foreach ($name in $Spec.Text.Keys) {
        $colors[$name] = [string]$Spec.Text[$name]
    }
    if ($colors.OnAccent) {
        $colors.Status = '#0A0D14'
        $colors.Clock = '#0A0D14'
        $colors.Week = '#1B2A33'
        $colors.Date = '#33454F'
        $colors.Hint = '#3A4A54'
        $colors.Marker = '#0A0D14'
    }
    return $colors
}

# ============================ 布局模板 ============================
# 三种布局刻意使用同一套元素名（StatusDot/ClockText/TimelineCanvas…），
# 这样 Update-Widget 不用为布局写分支。

$script:LayoutCard = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="18" Margin="14" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#FC182233" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#26FFFFFF" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Margin="0,20,0,20" RadiusX="1.5" RadiusY="1.5" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#F59E0B" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="16,13,16,13">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <Border x:Name="StatusPill" Background="#00000000" BorderThickness="0" CornerRadius="10" Padding="0" HorizontalAlignment="Left" VerticalAlignment="Center">
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#34D399" VerticalAlignment="Center">
              <Ellipse.Effect>
                <DropShadowEffect BlurRadius="10" ShadowDepth="0" Opacity="0.95" Color="#34D399" />
              </Ellipse.Effect>
            </Ellipse>
            <Rectangle x:Name="StatusSquare" Width="9" Height="9" Fill="#34D399" VerticalAlignment="Center" Visibility="Collapsed" />
            <TextBlock x:Name="StatusText" Text="空闲时段" Margin="8,0,0,0" FontSize="18" FontWeight="SemiBold" Foreground="#34D399" VerticalAlignment="Center" />
          </StackPanel>
        </Border>
        <Border x:Name="RateBadge" Grid.Column="1" CornerRadius="9" Padding="8,3" Background="#2234D399" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="1.0×" FontSize="10.5" Foreground="#6EE7B7" />
        </Border>
      </Grid>
      <Grid Grid.Row="1" Margin="0,10,0,0">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto" />
          <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Row="0" Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Bottom">
          <TextBlock x:Name="ClockText" Text="08:54" FontSize="34" FontWeight="Bold" Foreground="#F8FAFC" />
          <TextBlock x:Name="ClockSec" Text=":21" FontSize="15" Foreground="#8FA0B8" Margin="1,0,0,6" VerticalAlignment="Bottom" />
        </StackPanel>
        <StackPanel x:Name="DateBox" Grid.Row="0" Grid.Column="1" Orientation="Vertical" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="12,0,0,0">
          <TextBlock x:Name="DateText" Text="10月28日" FontSize="13" Foreground="#CBD5E1" HorizontalAlignment="Right" TextTrimming="CharacterEllipsis" MaxWidth="170" />
          <TextBlock x:Name="WeekText" Text="周三" FontSize="11" Foreground="#7C8AA5" HorizontalAlignment="Right" Margin="0,3,0,0" />
        </StackPanel>
      </Grid>
      <Grid Grid.Row="2" Margin="0,10,0,0" Height="10">
        <Canvas x:Name="TimelineCanvas" Height="10" ClipToBounds="True" HorizontalAlignment="Stretch">
          <Rectangle x:Name="TimelineTrack" Canvas.Left="0" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#332A3A4D" />
          <Rectangle x:Name="PeakSegment1" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="PeakSegment2" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="TimeMarker" Canvas.Top="0" Width="2" Height="10" RadiusX="1" RadiusY="1" Fill="#F8FAFC" />
        </Canvas>
      </Grid>
      <Grid Grid.Row="3" Margin="0,8,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="12" Foreground="#94A3B8" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="10" Foreground="#5B6B82" Margin="10,2,0,0" VerticalAlignment="Center" />
        </StackPanel>
        <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:40:00" FontSize="12" Foreground="#94A3B8" VerticalAlignment="Center" Margin="10,0,0,0" />
      </Grid>
    </Grid>
  </Grid>
</Border>
'@

$script:LayoutCapsule = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="26" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#F01A2233" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#26FFFFFF" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Margin="0,16,0,16" RadiusX="1.5" RadiusY="1.5" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#F59E0B" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="18,0,18,0" VerticalAlignment="Center">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="StatusDot" Width="20" Height="20" Fill="#34D399" VerticalAlignment="Center">
            <Ellipse.Effect>
              <DropShadowEffect BlurRadius="16" ShadowDepth="0" Opacity="0.95" Color="#34D399" />
            </Ellipse.Effect>
          </Ellipse>
          <TextBlock x:Name="StatusText" Text="空闲时段" Margin="9,0,0,0" FontSize="15" FontWeight="SemiBold" Foreground="#34D399" VerticalAlignment="Center" />
        </StackPanel>
        <StackPanel Grid.Column="1" Margin="16,0,16,0" VerticalAlignment="Center">
          <TextBlock x:Name="ClockText" Text="08:54:21" FontSize="38" FontWeight="Bold" Foreground="#F8FAFC" />
          <StackPanel Orientation="Horizontal" Margin="0,1,0,0">
            <TextBlock x:Name="WeekText" Text="周三" FontSize="12" Foreground="#CBD5E1" />
            <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" Foreground="#7C8AA5" Margin="8,0,0,0" />
          </StackPanel>
        </StackPanel>
        <StackPanel Grid.Column="2" HorizontalAlignment="Right" VerticalAlignment="Center">
          <Border x:Name="RateBadge" CornerRadius="9" Padding="8,3" Background="#2234D399" HorizontalAlignment="Right">
            <TextBlock x:Name="RateText" Text="价格 0.5×" FontSize="10.5" Foreground="#6EE7B7" />
          </Border>
          <TextBlock x:Name="CountdownText" Text="距高峰时段还有 00:12:00" FontSize="11" Foreground="#94A3B8" Margin="0,5,0,0" HorizontalAlignment="Right" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9.5" Foreground="#5B6B82" Margin="0,2,0,0" HorizontalAlignment="Right" />
        </StackPanel>
      </Grid>
      <Grid Grid.Row="1" Height="8" Margin="0,8,0,0">
        <Canvas x:Name="TimelineCanvas" Height="8" ClipToBounds="True" HorizontalAlignment="Stretch">
          <Rectangle x:Name="TimelineTrack" Canvas.Left="0" Canvas.Top="1" Height="6" RadiusX="3" RadiusY="3" Fill="#332A3A4D" />
          <Rectangle x:Name="PeakSegment1" Canvas.Top="1" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="PeakSegment2" Canvas.Top="1" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="TimeMarker" Canvas.Top="0" Width="2" Height="8" RadiusX="1" RadiusY="1" Fill="#F8FAFC" />
        </Canvas>
      </Grid>
    </Grid>
  </Grid>
</Border>
'@

$script:LayoutDial = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="150" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#F0182233" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#26FFFFFF" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Margin="0,20,0,20" RadiusX="1.5" RadiusY="1.5" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#F59E0B" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" VerticalAlignment="Center" HorizontalAlignment="Center">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Center">
        <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#34D399" VerticalAlignment="Center">
          <Ellipse.Effect>
            <DropShadowEffect BlurRadius="10" ShadowDepth="0" Opacity="0.95" Color="#34D399" />
          </Ellipse.Effect>
        </Ellipse>
        <TextBlock x:Name="StatusText" Text="空闲时段" Margin="8,0,0,0" FontSize="15" FontWeight="SemiBold" Foreground="#34D399" VerticalAlignment="Center" />
      </StackPanel>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="08:54:21" FontSize="40" FontWeight="Bold" Foreground="#F8FAFC" HorizontalAlignment="Center" Margin="0,2,0,0" />
      <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,2,0,0">
        <TextBlock x:Name="WeekText" Text="周三" FontSize="12" Foreground="#CBD5E1" />
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" Foreground="#7C8AA5" Margin="8,0,0,0" />
      </StackPanel>
      <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,0">
        <Border x:Name="RateBadge" CornerRadius="9" Padding="8,3" Background="#2234D399">
          <TextBlock x:Name="RateText" Text="价格 0.5×" FontSize="10.5" Foreground="#6EE7B7" />
        </Border>
        <TextBlock x:Name="CountdownText" Text="距高峰时段还有 00:12:00" FontSize="11" Foreground="#94A3B8" Margin="8,0,0,0" VerticalAlignment="Center" />
      </StackPanel>
      <Grid Grid.Row="4" Height="0">
        <Canvas x:Name="TimelineCanvas" Height="10" Visibility="Collapsed">
          <Rectangle x:Name="TimelineTrack" Canvas.Left="0" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#332A3A4D" />
          <Rectangle x:Name="PeakSegment1" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="PeakSegment2" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="TimeMarker" Canvas.Top="0" Width="2" Height="10" RadiusX="1" RadiusY="1" Fill="#F8FAFC" />
        </Canvas>
      </Grid>
      <TextBlock x:Name="HintText" Grid.Row="4" Text="拖动 / 右键" FontSize="9.5" Foreground="#5B6B82" HorizontalAlignment="Center" Margin="0,6,0,0" />
    </Grid>
  </Grid>
</Border>
'@

$script:LayoutXaml = @{
    card    = $script:LayoutCard
    capsule = $script:LayoutCapsule
    dial    = $script:LayoutDial
}

# 9 个「结构本身就不一样」的方案走专属模板（峰谷示波器 / 点阵液晶 / 瑞士分屏 /
# 新野兽派 / 半谷 / K 线 / 色块 / HUD / 圆表），模板与装饰器都在 SchemesPro.ps1。
. (Join-Path $PSScriptRoot 'SchemesPro.ps1')

# ============================ 渲染工具 ============================

$script:DecorRefs = @{}
$script:FontCache = @{}

function New-BrushSafe {
    param([string]$ColorText, [double]$Opacity = 1.0)
    if ([string]::IsNullOrWhiteSpace($ColorText)) { $ColorText = '#00000000' }
    $brush = ConvertTo-Brush $ColorText
    $brush.Opacity = $Opacity
    return $brush
}

function New-GradientBrush {
    param([string]$From, [string]$To)
    $brush = New-Object System.Windows.Media.LinearGradientBrush
    $brush.StartPoint = New-Object System.Windows.Point -ArgumentList 0, 0
    $brush.EndPoint = New-Object System.Windows.Point -ArgumentList 1, 1
    $c1 = [System.Windows.Media.ColorConverter]::ConvertFromString($From)
    $c2 = [System.Windows.Media.ColorConverter]::ConvertFromString($To)
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $c1, 0.0))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $c2, 1.0))
    return $brush
}

function New-CardShadow {
    param([double]$Blur, [double]$Depth, [double]$Opacity)
    $effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $effect.BlurRadius = $Blur
    $effect.ShadowDepth = $Depth
    $effect.Direction = 270
    $effect.Opacity = $Opacity
    $effect.Color = [System.Windows.Media.ColorConverter]::ConvertFromString('#000000')
    return $effect
}

# 按优先级挑一个系统里真实存在的字体，避免 FontFamily 乱回退
function Resolve-FontFamily {
    param([string]$FontList)
    if ($script:FontCache.ContainsKey($FontList)) { return $script:FontCache[$FontList] }
    $installed = @()
    try {
        foreach ($family in [System.Windows.Media.Fonts]::SystemFontFamilies) {
            $installed += $family.Source
        }
    } catch { }
    $chosen = 'Segoe UI'
    foreach ($name in ($FontList -split ',')) {
        $candidate = $name.Trim()
        if ($candidate -eq '') { continue }
        if ($installed -contains $candidate) { $chosen = $candidate; break }
    }
    $family = New-Object System.Windows.Media.FontFamily -ArgumentList $chosen
    $script:FontCache[$FontList] = $family
    return $family
}

function New-ArcGeometry {
    param(
        [double]$Cx, [double]$Cy, [double]$Radius,
        [double]$StartAngle, [double]$EndAngle
    )
    $a1 = ($StartAngle - 90.0) * [Math]::PI / 180.0
    $a2 = ($EndAngle - 90.0) * [Math]::PI / 180.0
    $p1 = New-Object System.Windows.Point -ArgumentList ($Cx + $Radius * [Math]::Cos($a1)), ($Cy + $Radius * [Math]::Sin($a1))
    $p2 = New-Object System.Windows.Point -ArgumentList ($Cx + $Radius * [Math]::Cos($a2)), ($Cy + $Radius * [Math]::Sin($a2))

    $figure = New-Object System.Windows.Media.PathFigure
    $figure.StartPoint = $p1
    $figure.IsClosed = $false
    $segment = New-Object System.Windows.Media.ArcSegment
    $segment.Point = $p2
    $segment.Size = New-Object System.Windows.Size -ArgumentList $Radius, $Radius
    $segment.IsLargeArc = (($EndAngle - $StartAngle) -gt 180.0)
    $segment.SweepDirection = [System.Windows.Media.SweepDirection]::Clockwise
    $segment.IsStroked = $true
    [void]$figure.Segments.Add($segment)

    $geometry = New-Object System.Windows.Media.PathGeometry
    [void]$geometry.Figures.Add($figure)
    return $geometry
}

function New-PieGeometry {
    param(
        [double]$Cx, [double]$Cy, [double]$Radius,
        [double]$StartAngle, [double]$EndAngle
    )
    $a1 = ($StartAngle - 90.0) * [Math]::PI / 180.0
    $a2 = ($EndAngle - 90.0) * [Math]::PI / 180.0
    $p1 = New-Object System.Windows.Point -ArgumentList ($Cx + $Radius * [Math]::Cos($a1)), ($Cy + $Radius * [Math]::Sin($a1))
    $p2 = New-Object System.Windows.Point -ArgumentList ($Cx + $Radius * [Math]::Cos($a2)), ($Cy + $Radius * [Math]::Sin($a2))

    $figure = New-Object System.Windows.Media.PathFigure
    $figure.StartPoint = New-Object System.Windows.Point -ArgumentList $Cx, $Cy
    $figure.IsClosed = $true
    [void]$figure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList $p1, $true))
    $arc = New-Object System.Windows.Media.ArcSegment
    $arc.Point = $p2
    $arc.Size = New-Object System.Windows.Size -ArgumentList $Radius, $Radius
    $arc.IsLargeArc = (($EndAngle - $StartAngle) -gt 180.0)
    $arc.SweepDirection = [System.Windows.Media.SweepDirection]::Clockwise
    $arc.IsStroked = $true
    [void]$figure.Segments.Add($arc)

    $geometry = New-Object System.Windows.Media.PathGeometry
    [void]$geometry.Figures.Add($figure)
    return $geometry
}

function New-LineShape {
    param([double]$X1, [double]$Y1, [double]$X2, [double]$Y2, [string]$Color, [double]$Thickness = 1.0)
    $line = New-Object System.Windows.Shapes.Line
    $line.X1 = $X1; $line.Y1 = $Y1; $line.X2 = $X2; $line.Y2 = $Y2
    $line.Stroke = New-BrushSafe $Color
    $line.StrokeThickness = $Thickness
    $line.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
    $line.StrokeEndLineCap = [System.Windows.Media.PenLineCap]::Round
    return $line
}

function New-RectShape {
    param([double]$X, [double]$Y, [double]$W, [double]$H, [string]$Color, [double]$Radius = 0)
    $rect = New-Object System.Windows.Shapes.Rectangle
    $rect.Width = [Math]::Max(0.0, $W)
    $rect.Height = [Math]::Max(0.0, $H)
    $rect.RadiusX = $Radius
    $rect.RadiusY = $Radius
    $rect.Fill = New-BrushSafe $Color
    [System.Windows.Controls.Canvas]::SetLeft($rect, $X)
    [System.Windows.Controls.Canvas]::SetTop($rect, $Y)
    return $rect
}

# 时钟底部到倒计时顶部之间那段空白：装饰层往这里放，就不会压住文字
function Get-DecorBand {
    param([double]$H)
    $top = $H * 0.74
    $bottom = $H - 6
    try {
        if (($null -ne $script:CountdownText) -and ($null -ne $script:Card)) {
            $p2 = $script:CountdownText.TransformToAncestor($script:Card).Transform((New-Object System.Windows.Point -ArgumentList 0, 0))
            $top = $p2.Y + $script:CountdownText.ActualHeight + 4
            $bottom = $H - 6
        }
    } catch { }
    if ($bottom -lt ($top + 10)) { $bottom = $top + 10 }
    return @($top, $bottom)
}

# 某一时刻处在什么档位：1.0 = 高峰，0 = 空闲；Soft 是窗口边缘的过渡宽度
function Get-DayRate {
    param([double]$Fraction, $Windows, [double]$Soft = 0.012)
    $rate = 0.0
    foreach ($window in $Windows) {
        $a = [double]$window.Start
        $b = [double]$window.End
        if (($Fraction -ge $a) -and ($Fraction -le $b)) { return 1.0 }
        $d = [Math]::Min([Math]::Abs($Fraction - $a), [Math]::Abs($Fraction - $b))
        if ($d -lt $Soft) {
            $value = 1.0 - ($d / $Soft)
            if ($value -gt $rate) { $rate = $value }
        }
    }
    return $rate
}

# ============================ 装饰层 ============================
# 每个装饰器都是「一次性画完」，状态变化时整层重建（一天最多几次，开销可忽略）。
# 需要每秒动的（指针、呼吸灯）另外走 Update-DecorTick。

function Add-DecorSheen {
    param($Layer, [double]$W, [double]$H)

    # 静态的一层斜向高光：让「玻璃质感」在不动的时候也看得出来
    $static = New-Object System.Windows.Shapes.Rectangle
    $static.Width = $W
    $static.Height = $H
    $staticBrush = New-Object System.Windows.Media.LinearGradientBrush
    $staticBrush.StartPoint = New-Object System.Windows.Point -ArgumentList 0, 0
    $staticBrush.EndPoint = New-Object System.Windows.Point -ArgumentList 0.85, 1
    [void]$staticBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(34, 255, 255, 255)), 0.0))
    [void]$staticBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(10, 255, 255, 255)), 0.45))
    [void]$staticBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0, 255, 255, 255)), 0.72))
    $static.Fill = $staticBrush
    $static.IsHitTestVisible = $false
    [void]$Layer.Children.Add($static)

    $rect = New-Object System.Windows.Shapes.Rectangle
    $rect.Width = [Math]::Max(70.0, $W * 0.35)
    $rect.Height = $H * 2.6
    $brush = New-Object System.Windows.Media.LinearGradientBrush
    $brush.StartPoint = New-Object System.Windows.Point -ArgumentList 0, 0
    $brush.EndPoint = New-Object System.Windows.Point -ArgumentList 1, 0
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0, 255, 255, 255)), 0.0))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(26, 255, 255, 255)), 0.5))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0, 255, 255, 255)), 1.0))
    $rect.Fill = $brush
    $rect.IsHitTestVisible = $false

    $group = New-Object System.Windows.Media.TransformGroup
    $rotate = New-Object System.Windows.Media.RotateTransform -ArgumentList 16
    $translate = New-Object System.Windows.Media.TranslateTransform
    [void]$group.Children.Add($rotate)
    [void]$group.Children.Add($translate)
    $rect.RenderTransform = $group
    [System.Windows.Controls.Canvas]::SetLeft($rect, (-$W * 0.6))
    [System.Windows.Controls.Canvas]::SetTop($rect, (-$H * 0.8))
    [void]$Layer.Children.Add($rect)

    $animation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $animation.From = 0.0
    $animation.To = ($W * 1.9)
    $animation.Duration = [TimeSpan]::FromSeconds(6.5)
    $animation.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $translate.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $animation)
}

function Add-DecorGlowCorner {
    param($Layer, [double]$W, [double]$H, $Colors)
    $ellipse = New-Object System.Windows.Shapes.Ellipse
    $ellipse.Width = $W * 1.05
    $ellipse.Height = $H * 1.5
    $brush = New-Object System.Windows.Media.RadialGradientBrush
    $brush.GradientOrigin = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
    $brush.Center = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
    $brush.RadiusX = 0.5; $brush.RadiusY = 0.5
    $accent = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$Colors.Accent)
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(70, $accent.R, $accent.G, $accent.B)), 0.0))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0, $accent.R, $accent.G, $accent.B)), 1.0))
    $ellipse.Fill = $brush
    [System.Windows.Controls.Canvas]::SetLeft($ellipse, ($W * 0.25))
    [System.Windows.Controls.Canvas]::SetTop($ellipse, (-$H * 0.55))
    [void]$Layer.Children.Add($ellipse)
}

function Add-DecorRing {
    param($Layer, [double]$W, [double]$H, $Colors, $Status, [switch]$Quartz)
    $cx = $W / 2.0
    $cy = $H / 2.0
    $outer = [Math]::Min($W, $H) / 2.0 - 9.0
    $accent = [string]$Colors.Accent

    $track = New-Object System.Windows.Shapes.Ellipse
    $track.Width = $outer * 2
    $track.Height = $outer * 2
    $track.Stroke = New-BrushSafe '#14FFFFFF'
    $track.StrokeThickness = 6
    $track.Fill = New-BrushSafe '#00000000'
    [System.Windows.Controls.Canvas]::SetLeft($track, ($cx - $outer))
    [System.Windows.Controls.Canvas]::SetTop($track, ($cy - $outer))
    [void]$Layer.Children.Add($track)

    # 24 小时刻度：整点短，6 点长
    for ($hour = 0; $hour -lt 24; $hour++) {
        $angle = $hour / 24.0 * 360.0
        $rad = ($angle - 90.0) * [Math]::PI / 180.0
        $length = 5.0
        $opacity = '#33FFFFFF'
        if (($hour % 6) -eq 0) { $length = 10.0; $opacity = '#66FFFFFF' }
        $r1 = $outer - $length
        $r2 = $outer
        $line = New-LineShape -X1 ($cx + $r1 * [Math]::Cos($rad)) -Y1 ($cy + $r1 * [Math]::Sin($rad)) `
            -X2 ($cx + $r2 * [Math]::Cos($rad)) -Y2 ($cy + $r2 * [Math]::Sin($rad)) -Color $opacity -Thickness 1
        [void]$Layer.Children.Add($line)
    }

    if ($Quartz) {
        $inner = New-Object System.Windows.Shapes.Ellipse
        $inner.Width = ($outer - 18) * 2
        $inner.Height = ($outer - 18) * 2
        $inner.Stroke = New-BrushSafe '#10FFFFFF'
        $inner.StrokeThickness = 1
        $inner.Fill = New-BrushSafe '#00000000'
        [System.Windows.Controls.Canvas]::SetLeft($inner, ($cx - $outer + 18))
        [System.Windows.Controls.Canvas]::SetTop($inner, ($cy - $outer + 18))
        [void]$Layer.Children.Add($inner)
    }

    # 高峰窗口弧段
    foreach ($window in $Status.PeakWindows) {
        $startAngle = [double]$window.Start * 360.0
        $endAngle = [double]$window.End * 360.0
        $path = New-Object System.Windows.Shapes.Path
        $path.Data = New-ArcGeometry -Cx $cx -Cy $cy -Radius ($outer - 3) -StartAngle $startAngle -EndAngle $endAngle
        $path.Stroke = New-BrushSafe $accent
        $path.StrokeThickness = 6
        $path.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
        $path.StrokeEndLineCap = [System.Windows.Media.PenLineCap]::Round
        [void]$Layer.Children.Add($path)
    }

    # 当前时刻：外圈一根短游标（不画到圆心，避免压住中间的时间数字）
    $needle = New-LineShape -X1 $cx -Y1 ($cy - $outer + 16) -X2 $cx -Y2 ($cy - $outer + 1) -Color $accent -Thickness 2.5
    $needle.Opacity = 0.95
    [void]$Layer.Children.Add($needle)

    $tip = New-Object System.Windows.Shapes.Ellipse
    $tip.Width = 7; $tip.Height = 7
    $tip.Fill = New-BrushSafe $accent
    [System.Windows.Controls.Canvas]::SetLeft($tip, ($cx - 3.5))
    [System.Windows.Controls.Canvas]::SetTop($tip, ($cy - $outer - 2.5))
    [void]$Layer.Children.Add($tip)

    $script:DecorRefs['RingNeedle'] = $needle
    $script:DecorRefs['RingTip'] = $tip
    $script:DecorRefs['RingCenterX'] = $cx
    $script:DecorRefs['RingCenterY'] = $cy
    $script:DecorRefs['RingRadius'] = $outer
    $script:DecorRefs['RingColors'] = $Colors
}

function Add-DecorSectors {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $cx = $W / 2.0
    $cy = $H / 2.0
    $radius = [Math]::Min($W, $H) / 2.0 - 22.0
    foreach ($window in $Status.PeakWindows) {
        $startAngle = [double]$window.Start * 360.0
        $endAngle = [double]$window.End * 360.0
        $path = New-Object System.Windows.Shapes.Path
        $path.Data = New-PieGeometry -Cx $cx -Cy $cy -Radius $radius -StartAngle $startAngle -EndAngle $endAngle
        $path.Fill = New-BrushSafe ([string]$Colors.Accent) 0.10
        $path.Stroke = New-BrushSafe ([string]$Colors.Accent) 0.30
        $path.StrokeThickness = 1
        [void]$Layer.Children.Add($path)
    }
}

function Add-DecorWave {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $padX = 14.0
    $band = Get-DecorBand -H $H
    $top = [double]$band[0]
    $bottom = [double]$band[1]
    $baseY = ($top + $bottom) / 2.0
    $amplitude = ($bottom - $top) / 2.0 - 1.0
    if ($amplitude -lt 3.0) { $amplitude = 3.0 }
    $steps = 160
    $points = New-Object System.Windows.Media.PointCollection
    for ($i = 0; $i -le $steps; $i++) {
        $fraction = $i / [double]$steps
        $rate = Get-DayRate -Fraction $fraction -Windows $Status.PeakWindows
        $x = $padX + $fraction * ($W - $padX * 2)
        $y = $baseY - ($rate - 0.5) * 2.0 * $amplitude
        [void]$points.Add((New-Object System.Windows.Point -ArgumentList $x, $y))
    }

    $figure = New-Object System.Windows.Media.PathFigure
    $figure.StartPoint = $points[0]
    $figure.IsClosed = $false
    for ($i = 1; $i -lt $points.Count; $i++) {
        [void]$figure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList $points[$i], $true))
    }
    $geometry = New-Object System.Windows.Media.PathGeometry
    [void]$geometry.Figures.Add($figure)

    $glow = New-Object System.Windows.Shapes.Path
    $glow.Data = $geometry
    $glow.Stroke = New-BrushSafe ([string]$Colors.Accent) 0.16
    $glow.StrokeThickness = 6
    $glow.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
    [void]$Layer.Children.Add($glow)

    $path = New-Object System.Windows.Shapes.Path
    $path.Data = $geometry
    $path.Stroke = New-BrushSafe ([string]$Colors.Accent) 0.8
    $path.StrokeThickness = 1.5
    $path.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
    [void]$Layer.Children.Add($path)

    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 6; $dot.Height = 6
    $dot.Fill = New-BrushSafe '#FFFFFF'
    $dot.Opacity = 0.9
    [void]$Layer.Children.Add($dot)

    $script:DecorRefs['WaveBaseY'] = $baseY
    $script:DecorRefs['WaveAmplitude'] = $amplitude
    $script:DecorRefs['WaveDot'] = $dot
    $script:DecorRefs['WavePadX'] = $padX
    $script:DecorRefs['WaveWidth'] = $W
    $script:DecorRefs['WaveWindows'] = $Status.PeakWindows
}

function Add-DecorSine {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $padX = 14.0
    $band = Get-DecorBand -H $H
    $top = [double]$band[0]
    $bottom = [double]$band[1]
    $midY = ($top + $bottom) / 2.0
    $span = $bottom - $top
    $amplitude = $span / 2.0 - 18.0
    if ($amplitude -lt 4.0) { $amplitude = [Math]::Max(2.0, $span / 2.0 - 3.0) }
    $steps = 140
    $figure = New-Object System.Windows.Media.PathFigure
    for ($i = 0; $i -le $steps; $i++) {
        $fraction = $i / [double]$steps
        $x = $padX + $fraction * ($W - $padX * 2)
        $y = $midY - [Math]::Sin($fraction * [Math]::PI * 2.0) * $amplitude
        $point = New-Object System.Windows.Point -ArgumentList $x, $y
        if ($i -eq 0) {
            $figure.StartPoint = $point
            $figure.IsClosed = $false
        } else {
            [void]$figure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList $point, $true))
        }
    }
    $geometry = New-Object System.Windows.Media.PathGeometry
    [void]$geometry.Figures.Add($figure)

    $glow = New-Object System.Windows.Shapes.Path
    $glow.Data = $geometry
    $glow.Stroke = New-BrushSafe ([string]$Colors.Accent) 0.18
    $glow.StrokeThickness = 5
    [void]$Layer.Children.Add($glow)

    $path = New-Object System.Windows.Shapes.Path
    $path.Data = $geometry
    $path.Stroke = New-BrushSafe ([string]$Colors.Accent) 0.8
    $path.StrokeThickness = 1.4
    [void]$Layer.Children.Add($path)

    if ($span -ge 34) {
        $crestX = $padX + ($W - $padX * 2) * 0.25
        $troughX = $padX + ($W - $padX * 2) * 0.75

        $peakLabel = New-Object System.Windows.Controls.TextBlock
        $peakLabel.Text = '梁文峰'
        $peakLabel.FontSize = 9
        $peakLabel.Foreground = New-BrushSafe ([string]$Colors.Accent) 0.85
        [System.Windows.Controls.Canvas]::SetLeft($peakLabel, ($crestX - 14))
        [System.Windows.Controls.Canvas]::SetTop($peakLabel, ($top - 2))
        [void]$Layer.Children.Add($peakLabel)

        $valleyLabel = New-Object System.Windows.Controls.TextBlock
        $valleyLabel.Text = '梁文谷'
        $valleyLabel.FontSize = 9
        $valleyLabel.Foreground = New-BrushSafe ([string]$Colors.Accent) 0.7
        [System.Windows.Controls.Canvas]::SetLeft($valleyLabel, ($troughX - 14))
        [System.Windows.Controls.Canvas]::SetTop($valleyLabel, ($bottom - 16))
        [void]$Layer.Children.Add($valleyLabel)
    }
}

function Add-DecorCandles {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $padX = 14.0
    $band = Get-DecorBand -H $H
    $top = [double]$band[0]
    $bottom = [double]$band[1]
    $baseY = $bottom - 1.0
    $peakHeight = $bottom - $top - 2.0
    if ($peakHeight -lt 8.0) { $peakHeight = 8.0 }
    $slot = ($W - $padX * 2) / 24.0
    $barWidth = [Math]::Max(3.0, $slot - 3.0)
    for ($hour = 0; $hour -lt 24; $hour++) {
        $rate = Get-DayRate -Fraction (($hour + 0.5) / 24.0) -Windows $Status.PeakWindows -Soft 0.0001
        $barHeight = 3.0
        $color = '#26333F'
        if ($rate -gt 0.5) { $barHeight = $peakHeight; $color = [string]$Colors.Accent }
        $x = $padX + $hour * $slot + ($slot - $barWidth) / 2.0
        $bar = New-RectShape -X $x -Y ($baseY - $barHeight) -W $barWidth -H $barHeight -Color $color -Radius 1
        $bar.Opacity = 0.92
        [void]$Layer.Children.Add($bar)
        $wick = New-LineShape -X1 ($x + $barWidth / 2.0) -Y1 ($baseY - $barHeight - 3) `
            -X2 ($x + $barWidth / 2.0) -Y2 $baseY -Color $color -Thickness 1
        $wick.Opacity = 0.45
        [void]$Layer.Children.Add($wick)
    }
}

function Add-DecorLamps {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $padX = 16.0
    $count = 12
    $gap = 4.0
    $slot = ($W - $padX * 2 - $gap * ($count - 1)) / $count
    $litCount = [int][Math]::Floor([double]$Status.DayFraction * $count) + 1
    if ($litCount -gt $count) { $litCount = $count }
    $y = $H - 24.0
    for ($i = 0; $i -lt $count; $i++) {
        $x = $padX + $i * ($slot + $gap)
        $color = '#12241B'
        if ($i -lt $litCount) { $color = [string]$Colors.Accent }
        $lamp = New-RectShape -X $x -Y $y -W $slot -H 8 -Color $color -Radius 2
        [void]$Layer.Children.Add($lamp)
        if ($i -lt $litCount) {
            $lamp.Effect = New-CardShadow -Blur 7 -Depth 0 -Opacity 0.7
            try { $lamp.Effect.Color = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$Colors.Accent) } catch { }
        }
    }
    $script:DecorRefs['LampCount'] = $count
}

function Add-DecorTicks {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $padX = 16.0
    $baseY = $H - 12.0
    $span = $W - $padX * 2
    foreach ($window in $Status.PeakWindows) {
        $startX = $padX + [double]$window.Start * $span
        $endX = $padX + [double]$window.End * $span
        $band = New-RectShape -X $startX -Y ($baseY - 3) -W ($endX - $startX) -H 3 -Color ([string]$Colors.Accent)
        $band.Opacity = 0.75
        [void]$Layer.Children.Add($band)
    }
    for ($hour = 0; $hour -le 24; $hour++) {
        $x = $padX + $hour / 24.0 * $span
        $length = 4.0
        $opacity = '#40FFFFFF'
        if (($hour % 6) -eq 0) { $length = 8.0; $opacity = '#8AFFFFFF' }
        $line = New-LineShape -X1 $x -Y1 ($baseY - $length) -X2 $x -Y2 $baseY -Color $opacity -Thickness 1
        [void]$Layer.Children.Add($line)
    }
}

function Add-DecorSplit {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $peakHours = 0.0
    foreach ($window in $Status.PeakWindows) {
        $peakHours += ([double]$window.End - [double]$window.Start) * 24.0
    }
    $ratio = $peakHours / 24.0

    $base = New-RectShape -X 0 -Y 0 -W $W -H $H -Color '#0F2A22'
    [void]$Layer.Children.Add($base)

    if ($ratio -gt 0.01) {
        $peakColor = '#F87171'
        $points = New-Object System.Windows.Media.PointCollection
        [void]$points.Add((New-Object System.Windows.Point -ArgumentList 0, 0))
        [void]$points.Add((New-Object System.Windows.Point -ArgumentList ($W * $ratio + 26), 0))
        [void]$points.Add((New-Object System.Windows.Point -ArgumentList ($W * $ratio - 26), $H))
        [void]$points.Add((New-Object System.Windows.Point -ArgumentList 0, $H))
        $polygon = New-Object System.Windows.Shapes.Polygon
        $polygon.Points = $points
        $polygon.Fill = New-BrushSafe $peakColor
        [void]$Layer.Children.Add($polygon)
    }

    # 压一层暗幕，保证深色文字在亮色斜块上也能读
    $scrim = New-RectShape -X 0 -Y 0 -W $W -H $H -Color '#000000'
    $scrim.Opacity = 0.38
    [void]$Layer.Children.Add($scrim)

    $script:DecorRefs['SplitRatio'] = $ratio
}

function Add-DecorPlate {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $plateWidth = 96.0
    $plate = New-RectShape -X 0 -Y 0 -W $plateWidth -H $H -Color ([string]$Colors.Accent)
    [void]$Layer.Children.Add($plate)

    # 铭牌上竖排状态字，状态一变整层重建，所以这里可以直接读 Status
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = [string]$Status.StatusText
    $label.FontSize = 15
    $label.FontWeight = [System.Windows.FontWeights]::SemiBold
    $label.Foreground = New-BrushSafe '#FFFFFF'
    $label.RenderTransformOrigin = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
    $label.RenderTransform = New-Object System.Windows.Media.RotateTransform -ArgumentList (-90)
    $label.Measure((New-Object System.Windows.Size -ArgumentList ([double]::PositiveInfinity), ([double]::PositiveInfinity)))
    $textW = $label.DesiredSize.Width
    $textH = $label.DesiredSize.Height
    [System.Windows.Controls.Canvas]::SetLeft($label, ($plateWidth / 2.0 - $textW / 2.0))
    [System.Windows.Controls.Canvas]::SetTop($label, ($H / 2.0 - $textH / 2.0))
    [void]$Layer.Children.Add($label)

    $divider = New-RectShape -X $plateWidth -Y 0 -W 2 -H $H -Color '#FFFFFF'
    $divider.Opacity = 0.85
    [void]$Layer.Children.Add($divider)
}

function Add-DecorLcd {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $frame = New-Object System.Windows.Controls.Border
    $frame.Width = $W - 24
    $frame.Height = $H * 0.42
    $frame.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 6
    $frame.Background = New-BrushSafe '#08120C'
    $frame.BorderBrush = New-BrushSafe '#1E3A2A'
    $frame.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 1
    [System.Windows.Controls.Canvas]::SetLeft($frame, 12)
    [System.Windows.Controls.Canvas]::SetTop($frame, ($H * 0.30))
    [void]$Layer.Children.Add($frame)
}

function Add-DecorScanlines {
    param($Layer, [double]$W, [double]$H)
    for ($y = 0; $y -lt $H; $y += 3) {
        $line = New-RectShape -X 0 -Y $y -W $W -H 1 -Color '#0BFFFFFF'
        $line.Opacity = 0.35
        [void]$Layer.Children.Add($line)
    }
}

function Add-DecorOrb {
    param($Layer, [double]$W, [double]$H, $Colors)
    $dot = $script:StatusDot
    if ($null -eq $dot) { return }
    $dot.Width = 20
    $dot.Height = 20
    $animation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $animation.From = 1.0
    $animation.To = 0.45
    $animation.Duration = [TimeSpan]::FromSeconds(1.9)
    $animation.AutoReverse = $true
    $animation.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $dot.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animation)
}

# ============================ 装饰调度 ============================

function Clear-SchemeDecor {
    param($Layer)
    if ($null -eq $Layer) { return }
    $Layer.Children.Clear()
    $script:DecorRefs = @{}
    if ($null -ne $script:StatusDot) {
        $script:StatusDot.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
        $script:StatusDot.Opacity = 1.0
    }
}

function Build-SchemeDecor {
    param([object]$Spec, [object]$Status, [hashtable]$Colors)
    $hostLayer = $script:DecorHost
    if ($null -eq $hostLayer) { return }
    Clear-SchemeDecor -Layer $hostLayer
    if ($null -eq $Status) { return }

    $w = [double]$script:Card.ActualWidth
    $h = [double]$script:Card.ActualHeight
    if ($w -le 1) { $w = [double]$Spec.Width }
    if ($h -le 1) { $h = 220.0 }

    $canvas = New-Object System.Windows.Controls.Canvas
    $canvas.Width = $w
    $canvas.Height = $h
    $canvas.IsHitTestVisible = $false
    [void]$hostLayer.Children.Add($canvas)

    foreach ($name in $Spec.Decor) {
        switch ([string]$name) {
            'sheen'      { Add-DecorSheen -Layer $canvas -W $w -H $h }
            'glowcorner' { Add-DecorGlowCorner -Layer $canvas -W $w -H $h -Colors $Colors }
            'ring'       { Add-DecorRing -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'quartz'     { Add-DecorRing -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status -Quartz }
            'sectors'    { Add-DecorSectors -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'wave'       { Add-DecorWave -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'sine'       { Add-DecorSine -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'candles'    { Add-DecorCandles -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'lamps'      { Add-DecorLamps -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'ticks'      { Add-DecorTicks -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'split'      { Add-DecorSplit -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'plate'      { Add-DecorPlate -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'lcd'        { Add-DecorLcd -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'scanlines'  { Add-DecorScanlines -Layer $canvas -W $w -H $h }
            'orb'        { Add-DecorOrb -Layer $canvas -W $w -H $h -Colors $Colors }
            # ---- SchemesPro.ps1 里的专属装饰 ----
            'scope'      { Add-DecorScope -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'kline'      { Add-DecorKline -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'halfsplit'  { Add-DecorHalfSplit -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'scalebar'   { Add-DecorScaleBar -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'gauge'      { Add-DecorGauge -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'hudprogress' { Add-DecorHudProgress -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            default      { }
        }
    }
}

# 每秒调用：只动需要动的那一个点
function Update-SchemeDecorTick {
    param([object]$Status)
    if ($null -eq $Status) { return }
    $needle = $script:DecorRefs['RingNeedle']
    if ($null -ne $needle) {
        $cx = [double]$script:DecorRefs['RingCenterX']
        $cy = [double]$script:DecorRefs['RingCenterY']
        $radius = [double]$script:DecorRefs['RingRadius']
        $angle = [double]$Status.DayFraction * 360.0
        $rad = ($angle - 90.0) * [Math]::PI / 180.0
        $needle.X1 = $cx + ($radius - 15) * [Math]::Cos($rad)
        $needle.Y1 = $cy + ($radius - 15) * [Math]::Sin($rad)
        $needle.X2 = $cx + ($radius - 1) * [Math]::Cos($rad)
        $needle.Y2 = $cy + ($radius - 1) * [Math]::Sin($rad)
        $tip = $script:DecorRefs['RingTip']
        if ($null -ne $tip) {
            [System.Windows.Controls.Canvas]::SetLeft($tip, ($cx + ($radius + 2) * [Math]::Cos($rad) - 3.5))
            [System.Windows.Controls.Canvas]::SetTop($tip, ($cy + ($radius + 2) * [Math]::Sin($rad) - 3.5))
        }
    }
    $dot = $script:DecorRefs['WaveDot']
    if ($null -ne $dot) {
        $padX = [double]$script:DecorRefs['WavePadX']
        $w = [double]$script:DecorRefs['WaveWidth']
        $baseY = [double]$script:DecorRefs['WaveBaseY']
        $amplitude = [double]$script:DecorRefs['WaveAmplitude']
        $windows = $script:DecorRefs['WaveWindows']
        $fraction = [double]$Status.DayFraction
        $x = $padX + $fraction * ($w - $padX * 2)
        $rate = Get-DayRate -Fraction $fraction -Windows $windows
        $y = $baseY - ($rate - 0.5) * 2.0 * $amplitude
        [System.Windows.Controls.Canvas]::SetLeft($dot, ($x - 3.5))
        [System.Windows.Controls.Canvas]::SetTop($dot, ($y - 3.5))
    }
}

# ============================ 应用方案 ============================

function ConvertTo-Thickness {
    param([string]$Text)
    $parts = @($Text -split ',')
    $values = @()
    foreach ($part in $parts) { $values += [double]::Parse($part.Trim()) }
    switch ($values.Count) {
        1 { return New-Object System.Windows.Thickness -ArgumentList $values[0] }
        2 { return New-Object System.Windows.Thickness -ArgumentList $values[0], $values[1] }
        4 { return New-Object System.Windows.Thickness -ArgumentList $values[0], $values[1], $values[2], $values[3] }
        default { return New-Object System.Windows.Thickness -ArgumentList 0 }
    }
}

function New-SurfaceBrush {
    param($Surface)
    $type = [string]$Surface.Type
    if ($type -eq 'solid') {
        return ConvertTo-Brush ([string]$Surface.From)
    }
    if ($type -eq 'radial') {
        $brush = New-Object System.Windows.Media.RadialGradientBrush
        $center = '1,0'
        if ($Surface.ContainsKey('Center')) { $center = [string]$Surface.Center }
        $pair = $center -split ','
        $point = New-Object System.Windows.Point -ArgumentList ([double]$pair[0]), ([double]$pair[1])
        $brush.Center = $point
        $brush.GradientOrigin = $point
        $brush.RadiusX = 0.52
        $brush.RadiusY = 0.62
        [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString([string]$Surface.From)), 0.0))
        [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString([string]$Surface.To)), 1.0))
        return $brush
    }
    return New-GradientBrush ([string]$Surface.From) ([string]$Surface.To)
}

# 只处理「跟状态无关」的外观：底/边/圆角/阴影/排版/元素显隐
function Apply-SchemeSurface {
    param([object]$Spec)

    # 专属模板（SchemesPro.ps1）的骨架写死在各自 XAML 里，
    # 通用排版开关（药丸/裸价/日期换位）不能套上去，否则会把结构改坏。
    $isCustom = -not (@('card', 'capsule', 'dial') -contains [string]$Spec.Layout)

    $script:Card.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList ([double]$Spec.Radius)
    $script:Card.Margin = ConvertTo-Thickness ([string]$Spec.Margin)
    $script:Card.BorderThickness = New-Object System.Windows.Thickness -ArgumentList ([double]$Spec.BorderWidth)
    $script:Card.BorderBrush = ConvertTo-Brush ([string]$Spec.Border)
    $script:Card.Background = New-SurfaceBrush -Surface $Spec.Surface

    $shadow = $Spec.Shadow
    $effect = New-CardShadow -Blur ([double]$shadow.Blur) -Depth ([double]$shadow.Depth) -Opacity ([double]$shadow.Opacity)
    try { $effect.Color = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$shadow.Color) } catch { }
    $script:Card.Effect = $effect

    $script:Body.Margin = ConvertTo-Thickness ([string]$Spec.BodyPad)
    $script:ClockText.FontFamily = Resolve-FontFamily ([string]$Spec.ClockFont)
    $script:ClockText.FontSize = [double]$Spec.ClockSize
    if (-not $isCustom) {
        # 专属模板的字号写在自己的 XAML 里（每个方案的信息密度差很多），
        # 通用补丁表里的 StatusSize / CountdownSize 不往它们身上套。
        $script:StatusText.FontSize = [double]$Spec.StatusSize
        $script:CountdownText.FontSize = [double]$Spec.CountdownSize
    }

    # ---- 网页稿的通用排版开关 ----
    # 时钟后面的「:24」：网页稿里是小号灰字，只有仪表类方案才全同号
    if ($null -ne $script:ClockSec) {
        $script:ClockSec.FontFamily = $script:ClockText.FontFamily
        $script:ClockSec.FontSize = [double]$Spec.ClockSecSize
    }
    # 价格：裸文字（1.0×）还是药丸（价格 1.0×）
    $script:RateText.FontSize = [double]$Spec.RateSize
    if ($isCustom) {
        # 专属模板自己决定价格长什么样（E3 的方框、E5 的 RATE: 1.0X、C6 的 1.0 + ×）
    } elseif ([bool]$Spec.PlainRate) {
        $script:RateBadge.Background = ConvertTo-Brush '#00000000'
        $script:RateBadge.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 0
        $script:RateBadge.Padding = New-Object System.Windows.Thickness -ArgumentList 0
    } else {
        $script:RateBadge.Padding = New-Object System.Windows.Thickness -ArgumentList 8, 3, 8, 3
    }
    # 状态：药丸底（A1 / A5 那种）还是裸排
    if (($null -ne $script:StatusPill) -and (-not $isCustom)) {
        if ([bool]$Spec.StatusPillStyle) {
            $script:StatusPill.Padding = New-Object System.Windows.Thickness -ArgumentList 10, 5, 12, 5
            $script:StatusPill.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 14
        } else {
            $script:StatusPill.Padding = New-Object System.Windows.Thickness -ArgumentList 0
            $script:StatusPill.Background = ConvertTo-Brush '#00000000'
            $script:StatusPill.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 0
        }
    }
    if (($null -ne $script:CountdownValue) -and (-not $isCustom)) {
        $script:CountdownValue.FontSize = [double]$Spec.CountdownSize
    }

    # 日期行：网页稿有两种排法——A1/A5 是右对齐竖排（日期在上、周几在下），
    # B/C/D/E/F 组是「10月28日 周三」横排塞在时钟下面。同一个 StackPanel 换位置和方向。
    # 只有通用卡片模板的 DateBox 是放在两行 Grid 里的，专属模板的 DateBox 位置写死在
    # 自己的 XAML 里，不能在这里被 SetRow/SetColumn 挪走。
    if (($null -ne $script:DateBox) -and ([string]$Spec.Layout -eq 'card')) {
        if ([bool]$Spec.DateInline) {
            [System.Windows.Controls.Grid]::SetRow($script:DateBox, 1)
            [System.Windows.Controls.Grid]::SetColumn($script:DateBox, 0)
            [System.Windows.Controls.Grid]::SetColumnSpan($script:DateBox, 2)
            $script:DateBox.Orientation = [System.Windows.Controls.Orientation]::Horizontal
            $script:DateBox.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
            $script:DateBox.Margin = New-Object System.Windows.Thickness -ArgumentList 0, 3, 0, 0
            $script:DateText.FontSize = 12
            $script:WeekText.FontSize = 12
            $script:WeekText.Margin = New-Object System.Windows.Thickness -ArgumentList 6, 0, 0, 0
            $script:DateText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
            $script:WeekText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
        } else {
            [System.Windows.Controls.Grid]::SetRow($script:DateBox, 0)
            [System.Windows.Controls.Grid]::SetColumn($script:DateBox, 1)
            [System.Windows.Controls.Grid]::SetColumnSpan($script:DateBox, 1)
            $script:DateBox.Orientation = [System.Windows.Controls.Orientation]::Vertical
            $script:DateBox.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
            $script:DateBox.Margin = New-Object System.Windows.Thickness -ArgumentList 12, 0, 0, 0
            $script:DateText.FontSize = 13
            $script:WeekText.FontSize = 11
            $script:WeekText.Margin = New-Object System.Windows.Thickness -ArgumentList 0, 3, 0, 0
            $script:DateText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
            $script:WeekText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
        }
    }

    # 卡片布局里日期列被大号时钟挤在右边，宽度只够放下「10月28日」这一行；
    # 胶囊 / 表盘布局横向有余量。节日名放哪儿由这个标记决定（见 Update-Widget）。
    $script:CompactDate = ([string]$Spec.Layout -eq 'card')

    # 状态点：胶囊布局要放大成光球，由 orb 装饰接管
    $script:StatusDot.Width = 9
    $script:StatusDot.Height = 9
    if ([bool]$Spec.HideStatus) {
        $script:StatusDot.Visibility = [System.Windows.Visibility]::Collapsed
        if ($null -ne $script:StatusSquare) { $script:StatusSquare.Visibility = [System.Windows.Visibility]::Collapsed }
        $script:StatusText.Visibility = [System.Windows.Visibility]::Collapsed
    } else {
        $script:StatusText.Visibility = [System.Windows.Visibility]::Visible
        if (($null -ne $script:StatusSquare) -and [bool]$Spec.StatusSquare) {
            # C6 / E3 那种实心方块
            $script:StatusSquare.Visibility = [System.Windows.Visibility]::Visible
            $script:StatusSquare.Width = 9
            $script:StatusSquare.Height = 9
            $script:StatusDot.Visibility = [System.Windows.Visibility]::Collapsed
        } elseif ([bool]$Spec.StatusDot) {
            $script:StatusDot.Visibility = [System.Windows.Visibility]::Visible
            if ($null -ne $script:StatusSquare) { $script:StatusSquare.Visibility = [System.Windows.Visibility]::Collapsed }
        } else {
            $script:StatusDot.Visibility = [System.Windows.Visibility]::Collapsed
            if ($null -ne $script:StatusSquare) { $script:StatusSquare.Visibility = [System.Windows.Visibility]::Collapsed }
        }
    }

    # 左侧状态光柱
    if ([bool]$Spec.AccentBar) {
        $script:AccentBar.Visibility = [System.Windows.Visibility]::Visible
        $script:AccentBar.Width = 4
        $script:AccentBar.Margin = New-Object System.Windows.Thickness -ArgumentList 0, 0, 0, 0
        $script:AccentBar.RadiusX = 0
        $script:AccentBar.RadiusY = 0
        $script:AccentBar.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    } else {
        $script:AccentBar.Visibility = [System.Windows.Visibility]::Collapsed
    }

    if ([bool]$Spec.Timeline) {
        $script:TimelineCanvas.Visibility = [System.Windows.Visibility]::Visible
        $timelineHost = $script:TimelineCanvas.Parent
        if ($null -ne $timelineHost) { $timelineHost.Visibility = [System.Windows.Visibility]::Visible }
    } else {
        $script:TimelineCanvas.Visibility = [System.Windows.Visibility]::Collapsed
        $timelineHost = $script:TimelineCanvas.Parent
        if ($null -ne $timelineHost) { $timelineHost.Visibility = [System.Windows.Visibility]::Collapsed }
    }
}

# 处理「跟高峰/空闲有关」的配色 + 装饰层重绘
function Apply-SchemeState {
    param([object]$Spec, [object]$Status)

    $colors = Get-SchemeColors -Spec $Spec -Status $Status
    # 专属模板的价格 / 状态块长什么样由各自 XAML 定，这里只换文字色
    $isCustom = -not (@('card', 'capsule', 'dial') -contains [string]$Spec.Layout)

    $script:StatusText.Foreground = ConvertTo-Brush ([string]$colors.Status)
    $script:ClockText.Foreground = ConvertTo-Brush ([string]$colors.Clock)
    $script:WeekText.Foreground = ConvertTo-Brush ([string]$colors.Week)
    $script:DateText.Foreground = ConvertTo-Brush ([string]$colors.Date)
    $script:CountdownText.Foreground = ConvertTo-Brush ([string]$colors.AccentSoft)
    $script:HintText.Foreground = ConvertTo-Brush ([string]$colors.Hint)

    # 可选元素（只有卡片布局有）
    if ($null -ne $script:ClockSec) {
        $secColor = ''
        if ($colors.ContainsKey('ClockSec')) { $secColor = [string]$colors.ClockSec }
        if ([string]::IsNullOrWhiteSpace($secColor)) { $secColor = [string]$colors.Week }
        $script:ClockSec.Foreground = ConvertTo-Brush $secColor
    }
    if ($null -ne $script:CountdownValue) {
        $script:CountdownValue.Foreground = ConvertTo-Brush ([string]$colors.AccentSoft)
    }
    if ($null -ne $script:StatusSquare) {
        # 满版色块方案（C6）里方块必须用对比色，跟状态文字同色，否则和底色糊在一起
        $script:StatusSquare.Fill = ConvertTo-Brush ([string]$colors.Status)
    }
    if (($null -ne $script:StatusPill) -and [bool]$Spec.StatusPillStyle -and (-not $isCustom)) {
        if ([bool]$Spec.StatusPillSolid) {
            # C1 那种实底 chip：琥珀底 + 深色字
            $script:StatusPill.Background = ConvertTo-Brush ([string]$colors.Accent)
            $script:StatusPill.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 0
            $script:StatusText.Foreground = ConvertTo-Brush '#0B0F14'
            $script:StatusDot.Fill = ConvertTo-Brush '#0B0F14'
        } else {
            $script:StatusPill.Background = ConvertTo-Brush ([string]$colors.BadgeBg)
            $borderColor = [string]$Spec.Text['StatusPillBorder']
            if ([string]::IsNullOrWhiteSpace($borderColor)) { $borderColor = [string]$colors.Accent }
            $script:StatusPill.BorderBrush = ConvertTo-Brush $borderColor
            $script:StatusPill.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 1
        }
    }

    $script:StatusDot.Fill = ConvertTo-Brush ([string]$colors.Accent)
    $glow = $script:StatusDot.Effect
    if ($null -ne $glow) {
        try {
            if ([bool]$colors.Glow) {
                $glow.Color = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$colors.Accent)
                $glow.Opacity = 0.95
            } else {
                $glow.Color = [System.Windows.Media.ColorConverter]::ConvertFromString('#000000')
                $glow.Opacity = 0.0
            }
        } catch { }
    }

    if ([bool]$Spec.SurfaceByState) {
        $script:Card.Background = ConvertTo-Brush ([string]$colors.Accent)
    }

    $script:AccentBar.Fill = ConvertTo-Brush ([string]$colors.Accent)
    $script:PeakSegment1.Fill = ConvertTo-Brush ([string]$colors.Segment)
    $script:PeakSegment2.Fill = ConvertTo-Brush ([string]$colors.Segment)
    $script:TimelineTrack.Fill = ConvertTo-Brush ([string]$colors.Track)
    $script:TimeMarker.Fill = ConvertTo-Brush ([string]$colors.Marker)

    if ($isCustom) {
        # 专属模板：只换价格文字的颜色，底色 / 描边 / 内边距保持模板原样
        $rateColor = [string]$colors.Accent
        if ($colors.ContainsKey('Rate')) { $rateColor = [string]$colors.Rate }
        $script:RateText.Foreground = ConvertTo-Brush $rateColor
    } elseif ([bool]$Spec.PlainRate) {
        # 裸文字价格（B1 / B5 / C1 / C6 那类），直接跟状态同色
        $script:RateBadge.Background = ConvertTo-Brush '#00000000'
        $script:RateBadge.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 0
        $script:RateText.Foreground = ConvertTo-Brush ([string]$colors.Accent)
    } else {
        switch ([string]$colors.Badge) {
            'onAccent' {
                $script:RateBadge.Background = ConvertTo-Brush '#1F000000'
                $script:RateText.Foreground = ConvertTo-Brush ([string]$colors.AccentSoft)
            }
            'solid' {
                $script:RateBadge.Background = ConvertTo-Brush ([string]$colors.BadgeBg)
                $script:RateText.Foreground = ConvertTo-Brush '#FFFFFF'
            }
            default {
                $script:RateBadge.Background = ConvertTo-Brush ([string]$colors.BadgeBg)
                $script:RateText.Foreground = ConvertTo-Brush ([string]$colors.AccentSoft)
            }
        }
    }

    # ---- 专属模板里需要跟状态走的部件 ----
    if ($null -ne $script:PlateBox) {
        # E4 左栏铭牌整块换成当前状态色
        $script:PlateBox.Background = ConvertTo-Brush ([string]$colors.Accent)
        if ($null -ne $script:PlateStatus) { $script:PlateStatus.Foreground = ConvertTo-Brush '#FFFFFF' }
        if ($null -ne $script:PlateStatusEn) { $script:PlateStatusEn.Foreground = ConvertTo-Brush '#FFE0BF' }
        if ($null -ne $script:PlateRate) { $script:PlateRate.Foreground = ConvertTo-Brush '#FFFFFF' }
        if ($null -ne $script:PlateDay) { $script:PlateDay.Foreground = ConvertTo-Brush '#FFE0BF' }
    }
    if ($null -ne $script:HudTopBar) {
        $script:HudTopBar.Fill = ConvertTo-Brush ([string]$colors.Accent)
    }
    if ($null -ne $script:StatusPill) {
        # C4 的琥珀药丸 / E2 的描边框都跟着状态色
        if ([string]$Spec.Layout -eq 'gauge') {
            $script:StatusPill.Background = ConvertTo-Brush ([string]$colors.Accent)
        } elseif ([string]$Spec.Layout -eq 'hud') {
            $script:StatusPill.Background = ConvertTo-Brush '#00000000'
        }
    }
    if ($null -ne $script:WinLeft) {
        $script:WinLeft.Foreground = ConvertTo-Brush ([string]$colors.AccentSoft)
        if ($null -ne $script:WinMid) { $script:WinMid.Foreground = ConvertTo-Brush ([string]$colors.AccentSoft) }
        if ($null -ne $script:WinRight) { $script:WinRight.Foreground = ConvertTo-Brush ([string]$colors.AccentSoft) }
    }
    if ($null -ne $script:RateTail) {
        # C6 的「×」压在琥珀底上，必须跟价格同色，不能用强调色
        $tailColor = [string]$colors.Accent
        if ($colors.ContainsKey('Rate')) { $tailColor = [string]$colors.Rate }
        $script:RateTail.Foreground = ConvertTo-Brush $tailColor
    }

    Build-SchemeDecor -Spec $Spec -Status $Status -Colors $colors
}

# ============================ 布局安装 ============================

$script:LayoutRoot = $null
$script:DecorHost = $null
$script:ContextMenuRef = $null
$script:InstallingLayout = $false
# 日期行是否只有「10月28日」这么宽（卡片布局为真），决定节日名放哪一行
$script:CompactDate = $false

function Get-LayoutElement {
    param([string]$Name)
    $element = $null
    if ($null -ne $script:LayoutRoot) { $element = $script:LayoutRoot.FindName($Name) }
    if (($null -eq $element) -and ($null -ne $script:Window)) { $element = $script:Window.FindName($Name) }
    if ($null -eq $element) { throw ('XAML 元素缺失：' + $Name) }
    return $element
}

# 可选元素：三套布局的元素不完全一致（胶囊/表盘没有秒数、没有分段倒计时），
# 找不到就返回 $null，调用方自己判空，不要抛异常。
function Find-LayoutElement {
    param([string]$Name)
    $element = $null
    if ($null -ne $script:LayoutRoot) { $element = $script:LayoutRoot.FindName($Name) }
    if (($null -eq $element) -and ($null -ne $script:Window)) { $element = $script:Window.FindName($Name) }
    return $element
}

function Install-Layout {
    param([object]$Spec)

    $layout = [string]$Spec.Layout
    if (-not $script:LayoutXaml.ContainsKey($layout)) { $layout = 'card' }

    $oldWidth = 0.0
    try { $oldWidth = [double]$script:Window.ActualWidth } catch { }
    $oldRight = 0.0
    if ($oldWidth -gt 1) { $oldRight = [double]$script:Window.Left + $oldWidth }

    $script:InstallingLayout = $true
    $root = [System.Windows.Markup.XamlReader]::Parse($script:LayoutXaml[$layout])
    $holder = New-Object System.Windows.Controls.Grid
    [void]$holder.Children.Add($root)
    $script:Window.Content = $holder
    $script:LayoutRoot = $root

    $script:Card = Get-LayoutElement 'Card'
    $script:CardRoot = Get-LayoutElement 'CardRoot'
    $script:DecorHost = Get-LayoutElement 'DecorHost'
    $script:Body = Get-LayoutElement 'Body'
    $script:AccentBar = Get-LayoutElement 'AccentBar'
    $script:StatusDot = Get-LayoutElement 'StatusDot'
    $script:StatusText = Get-LayoutElement 'StatusText'
    $script:RateBadge = Get-LayoutElement 'RateBadge'
    $script:RateText = Get-LayoutElement 'RateText'
    $script:ClockText = Get-LayoutElement 'ClockText'
    $script:WeekText = Get-LayoutElement 'WeekText'
    $script:DateText = Get-LayoutElement 'DateText'
    $script:TimelineCanvas = Get-LayoutElement 'TimelineCanvas'
    $script:TimelineTrack = Get-LayoutElement 'TimelineTrack'
    $script:PeakSegment1 = Get-LayoutElement 'PeakSegment1'
    $script:PeakSegment2 = Get-LayoutElement 'PeakSegment2'
    $script:TimeMarker = Get-LayoutElement 'TimeMarker'
    $script:CountdownText = Get-LayoutElement 'CountdownText'
    $script:HintText = Get-LayoutElement 'HintText'
    # 以下为可选元素（目前只有卡片布局有）
    $script:ClockSec = Find-LayoutElement 'ClockSec'
    $script:CountdownValue = Find-LayoutElement 'CountdownValue'
    $script:StatusPill = Find-LayoutElement 'StatusPill'
    $script:StatusSquare = Find-LayoutElement 'StatusSquare'
    $script:DateBox = Find-LayoutElement 'DateBox'
    # 专属模板（SchemesPro.ps1）才有的元素，通用模板里全为 $null
    $script:ScopeBox = Find-LayoutElement 'ScopeBox'
    $script:CandleBox = Find-LayoutElement 'CandleBox'
    $script:ScaleBox = Find-LayoutElement 'ScaleBox'
    $script:HudProgress = Find-LayoutElement 'HudProgress'
    $script:HudTopBar = Find-LayoutElement 'HudTopBar'
    $script:StatusIcon = Find-LayoutElement 'StatusIcon'
    $script:RateTail = Find-LayoutElement 'RateTail'
    $script:DateIcon = Find-LayoutElement 'DateIcon'
    $script:CdIcon = Find-LayoutElement 'CdIcon'
    $script:TzText = Find-LayoutElement 'TzText'
    $script:PlateBox = Find-LayoutElement 'PlateBox'
    $script:PlateStatus = Find-LayoutElement 'PlateStatus'
    $script:PlateStatusEn = Find-LayoutElement 'PlateStatusEn'
    $script:PlateRate = Find-LayoutElement 'PlateRate'
    $script:PlateDay = Find-LayoutElement 'PlateDay'
    $script:HalfRule = Find-LayoutElement 'HalfRule'
    $script:HalfFootText = Find-LayoutElement 'HalfFootText'
    $script:BrutalRule = Find-LayoutElement 'BrutalRule'
    $script:WinLeft = Find-LayoutElement 'WinLeft'
    $script:WinMid = Find-LayoutElement 'WinMid'
    $script:WinRight = Find-LayoutElement 'WinRight'
    $script:CdBox = Find-LayoutElement 'CdBox'
    # 换布局后 HUD 进度条是一块新的 Canvas，缓存必须作废，否则不会重画
    $script:HudCacheKey = ''

    Apply-SchemeWindowSize -Spec $Spec -OldRight $oldRight

    if ($null -ne $script:ContextMenuRef) { $script:Card.ContextMenu = $script:ContextMenuRef }
    Attach-CardInteractions
    $script:Card.Add_SizeChanged({
        if ($script:InstallingLayout) { return }
        $spec = Get-SchemeSpec -Key ([string]$script:Settings.UiScheme)
        if (@($spec.Decor).Count -eq 0) { return }
        if ($null -eq $script:LastStatus) { return }
        $colors = Get-SchemeColors -Spec $spec -Status $script:LastStatus
        Build-SchemeDecor -Spec $spec -Status $script:LastStatus -Colors $colors
    })

    $script:InstallingLayout = $false
    try { $script:Window.UpdateLayout() } catch { }
}

# 窗口尺寸：同一种布局下不同方案的宽度也可能不一样，所以每次切换都要重算
function Apply-SchemeWindowSize {
    param([object]$Spec, [double]$OldRight = 0)

    $width = [double]$Spec.Width
    if ($width -lt 120) { $width = 316 }

    $oldWidth = 0.0
    try { $oldWidth = [double]$script:Window.ActualWidth } catch { }
    if ($OldRight -le 1) {
        if ($oldWidth -gt 1) { $OldRight = [double]$script:Window.Left + $oldWidth }
    }

    # 注意：Height 可能是 NaN（自适应），NaN 参与比较永远为 False，
    # 所以不能直接写 Abs(cur - want) -gt 0.5，必须先判 NaN。
    $currentWidth = [double]$script:Window.Width
    if ([double]::IsNaN($currentWidth) -or ([Math]::Abs($currentWidth - $width) -gt 0.5)) {
        $script:Window.Width = $width
    }

    if ([double]$Spec.Height -gt 0) {
        $script:Window.SizeToContent = [System.Windows.SizeToContent]::Manual
        $wantHeight = [double]$Spec.Height
        $currentHeight = [double]$script:Window.Height
        if ([double]::IsNaN($currentHeight) -or ([Math]::Abs($currentHeight - $wantHeight) -gt 0.5)) {
            $script:Window.Height = $wantHeight
        }
    } else {
        $script:Window.SizeToContent = [System.Windows.SizeToContent]::Height
        $currentHeight = [double]$script:Window.Height
        if (-not [double]::IsNaN($currentHeight)) {
            $script:Window.Height = [double]::NaN
        }
    }

    # 以右边缘为锚点，换宽度时挂件不会跳位置
    if ($OldRight -gt 1) { $script:Window.Left = $OldRight - $width }
}

# ============================ 方案切换 ============================

function Set-UiScheme {
    param([string]$Key, [switch]$Quiet)

    if (-not (Test-SchemeKey -Key $Key)) { $Key = 'default' }
    $spec = Get-SchemeSpec -Key $Key
    $script:Settings.UiScheme = $Key

    # 布局变了才重建元素树，同布局内切换只改属性
    $needsInstall = $true
    if ($null -ne $script:LayoutRoot) {
        $needsInstall = ([string]$script:ActiveLayout -ne [string]$spec.Layout)
    }
    if ($needsInstall) {
        Install-Layout -Spec $spec
        $script:ActiveLayout = [string]$spec.Layout
    }

    Apply-SchemeWindowSize -Spec $spec
    Apply-SchemeSurface -Spec $spec

    # 强制重刷一次主题 + 装饰层
    $script:ThemeKey = ''
    $script:LastIsPeakDay = $null
    $script:LastTimelineWidth = $null
    try { $script:Window.UpdateLayout() } catch { }
    try { Update-Widget } catch { }
    if ($null -ne $script:LastStatus) {
        Apply-SchemeState -Spec $spec -Status $script:LastStatus
        Update-SchemeDecorTick -Status $script:LastStatus
    }

    foreach ($pair in $script:SchemeMenuItems.GetEnumerator()) {
        $pair.Value.IsChecked = ($pair.Key -eq $Key)
    }
    if (-not $Quiet) {
        try { $script:MenuSchemeHeader.Tag = '当前：' + [string]$spec.Name } catch { }
    }
}
