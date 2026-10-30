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
        Peak = @{ Accent = '#FFB020'; AccentSoft = '#FFD166'; BadgeBg = '#26FFB020'; Track = '#1AFFFFFF'; Segment = '#FFB020'; Glow = $false; CdLabel = '#5A6272'; CdValue = '#E9ECF2'; Date = '#8A93A4'; Week = '#8A93A4'; Band = '#8CFFB020' }
        Idle = @{ Accent = '#37E0A0'; AccentSoft = '#7CF0C4'; BadgeBg = '#2637E0A0'; Track = '#1AFFFFFF'; Segment = '#FFB020'; Glow = $false; CdLabel = '#5A6272'; CdValue = '#E9ECF2'; Date = '#8A93A4'; Week = '#8A93A4'; Band = '#8CFFB020' }
        Badge = 'tint'
    }
    'paper' = @{
        Peak = @{ Accent = '#B45309'; AccentSoft = '#92400E'; BadgeBg = '#1AB45309'; Track = '#1F1C1917'; Segment = '#B45309'; Glow = $false; CdLabel = '#78716C'; CdValue = '#1C1917'; Date = '#78716C'; Week = '#44403C'; Band = '#8CB45309' }
        Idle = @{ Accent = '#0F766E'; AccentSoft = '#115E59'; BadgeBg = '#1A0F766E'; Track = '#1F1C1917'; Segment = '#B45309'; Glow = $false; CdLabel = '#78716C'; CdValue = '#1C1917'; Date = '#78716C'; Week = '#44403C'; Band = '#8CB45309' }
        Badge = 'tint'
    }
    'solid' = @{
        Peak = @{ Accent = '#F59E0B'; AccentSoft = '#0A0D14'; BadgeBg = '#1F000000'; Track = '#33000000'; Segment = '#0A0D14'; Glow = $false; OnAccent = $true }
        Idle = @{ Accent = '#34D399'; AccentSoft = '#052E22'; BadgeBg = '#1F000000'; Track = '#33000000'; Segment = '#0A0D14'; Glow = $false; OnAccent = $true }
        Badge = 'onAccent'
    }
    'brutal' = @{
        # 网页稿：高峰徽章琥珀底黑字，空闲徽章翠绿底白字；倒计时数字跟着状态变色
        Peak = @{ Accent = '#F59E0B'; AccentSoft = '#B45309'; BadgeBg = '#F59E0B'; Track = '#22000000'; Segment = '#111111'; Glow = $false; Status = '#000000'; Rate = '#111111'; CdLabel = '#111111'; CdValue = '#B45309'; Fg = '#111111'; Clock = '#000000'; Date = '#000000'; Week = '#000000' }
        Idle = @{ Accent = '#10B981'; AccentSoft = '#047857'; BadgeBg = '#10B981'; Track = '#22000000'; Segment = '#111111'; Glow = $false; Status = '#FFFFFF'; Rate = '#111111'; CdLabel = '#111111'; CdValue = '#047857'; Fg = '#111111'; Clock = '#000000'; Date = '#000000'; Week = '#000000' }
        Badge = 'solid'
    }
    'lcd' = @{
        Peak = @{ Accent = '#FFB020'; AccentSoft = '#FFD166'; BadgeBg = '#26FFB020'; Track = '#1A7DF7A8'; Segment = '#FFB020'; Glow = $true }
        Idle = @{ Accent = '#7DF7A8'; AccentSoft = '#B9FFD0'; BadgeBg = '#1A7DF7A8'; Track = '#1A7DF7A8'; Segment = '#FFB020'; Glow = $true }
        Badge = 'tint'
    }
    # E2 工业级 HUD：网页稿的琥珀 / 翠绿双状态 + 碳黑底
    'hud' = @{
        Peak = @{ Accent = '#F59E0B'; AccentSoft = '#F59E0B'; BadgeBg = '#00000000'; Track = '#1E293B'; Segment = '#F59E0B'; Glow = $true;
            Surface = '#0A0E14'; Border = '#1E293B'; Clock = '#E2E8F0'; Date = '#64748B'; Week = '#64748B'; CdLabel = '#64748B'; CdValue = '#F59E0B' }
        Idle = @{ Accent = '#10B981'; AccentSoft = '#10B981'; BadgeBg = '#00000000'; Track = '#1E293B'; Segment = '#10B981'; Glow = $true;
            Surface = '#0A0E14'; Border = '#1E293B'; Clock = '#E2E8F0'; Date = '#64748B'; Week = '#64748B'; CdLabel = '#64748B'; CdValue = '#10B981' }
        Badge = 'plain'
    }
    # E5 点阵液晶：网页稿的暖棕（峰）/ 墨绿（谷）两套屏色
    'amber-crt' = @{
        Peak = @{ Accent = '#EAB366'; AccentSoft = '#EAB366'; BadgeBg = '#00000000'; Track = '#1AEAB366'; Segment = '#EAB366'; Glow = $true;
            Clock = '#FDE68A'; Week = '#EAB366'; Date = '#EAB366'; Status = '#EAB366'; Rate = '#EAB366';
            CdLabel = '#EAB366'; CdValue = '#FDE68A'; Surface = '#262016'; Border = '#453721' }
        Idle = @{ Accent = '#92B09A'; AccentSoft = '#92B09A'; BadgeBg = '#00000000'; Track = '#1A92B09A'; Segment = '#92B09A'; Glow = $false;
            Clock = '#BBF7D0'; Week = '#92B09A'; Date = '#92B09A'; Status = '#92B09A'; Rate = '#92B09A';
            CdLabel = '#92B09A'; CdValue = '#BBF7D0'; Surface = '#1C241E'; Border = '#2D3B32' }
        Badge = 'tint'
    }
    # E4 双色瑞士分屏：左栏实色就是状态色（网页稿 #B45309 / #047857）
    'swiss' = @{
        Peak = @{ Accent = '#B45309'; AccentSoft = '#FBBF24'; BadgeBg = '#00000000'; Track = '#1AFFFFFF'; Segment = '#FBBF24'; Glow = $false;
            CdLabel = '#71717A'; CdValue = '#FBBF24'; Clock = '#FAFAFA'; Date = '#A1A1AA' }
        Idle = @{ Accent = '#047857'; AccentSoft = '#34D399'; BadgeBg = '#00000000'; Track = '#1AFFFFFF'; Segment = '#34D399'; Glow = $false;
            CdLabel = '#71717A'; CdValue = '#34D399'; Clock = '#FAFAFA'; Date = '#A1A1AA' }
        Badge = 'tint'
    }
    # C6 色块：满版实色，文字用深墨色（网页稿 #E8A33A / #2FAE93）
    'block' = @{
        Peak = @{ Accent = '#E8A33A'; AccentSoft = '#1A1206'; BadgeBg = '#00000000'; Track = '#3D1A1206'; Segment = '#1A1206'; Glow = $false;
            Clock = '#1A1206'; Week = '#9E1A1206'; Date = '#9E1A1206'; Status = '#1A1206'; Rate = '#1A1206';
            CdLabel = '#701A1206'; CdValue = '#1A1206'; Rule = '#3D1A1206'; Tick = '#521A1206'; Band = '#8C1A1206'; Now = '#1A1206'; CardBorder = '#D08F28'; FreeBand = '#2E04140F' }
        Idle = @{ Accent = '#2FAE93'; AccentSoft = '#04140F'; BadgeBg = '#00000000'; Track = '#3D04140F'; Segment = '#04140F'; Glow = $false;
            Clock = '#04140F'; Week = '#A804140F'; Date = '#A804140F'; Status = '#04140F'; Rate = '#04140F';
            CdLabel = '#7504140F'; CdValue = '#04140F'; Rule = '#3D04140F'; Tick = '#4D04140F'; Band = '#6B04140F'; Now = '#04140F'; CardBorder = '#1E947C'; FreeBand = '#2E04140F' }
        Badge = 'onAccent'
    }
    # C4 圆表：高峰弧始终琥珀，只有 chip / 倍率跟状态换色（网页稿 #2FAE93）
    'gauge' = @{
        Peak = @{ Accent = '#E8A33A'; AccentSoft = '#E8A33A'; BadgeBg = '#E8A33A'; Track = '#1AFFFFFF'; Segment = '#E8A33A'; Glow = $false;
            Chip = '#E8A33A'; ChipInk = '#1A1206'; Rate = '#E8A33A'; Clock = '#E9ECF2'; Date = '#8A93A4'; Week = '#8A93A4';
            CdLabel = '#5A6272'; CdValue = '#8A93A4'; Free = '#422FAE93'; Tick = '#29FFFFFF'; Cursor = '#FFFFFF' }
        Idle = @{ Accent = '#E8A33A'; AccentSoft = '#E8A33A'; BadgeBg = '#2FAE93'; Track = '#1AFFFFFF'; Segment = '#E8A33A'; Glow = $false;
            Chip = '#2FAE93'; ChipInk = '#04140F'; Rate = '#2FAE93'; Clock = '#E9ECF2'; Date = '#8A93A4'; Week = '#8A93A4';
            CdLabel = '#5A6272'; CdValue = '#8A93A4'; Free = '#422FAE93'; Tick = '#29FFFFFF'; Cursor = '#FFFFFF' }
        Badge = 'onAccent'
    }
    'scope' = @{
        Peak = @{ Accent = '#E85D3D'; AccentSoft = '#E85D3D'; BadgeBg = '#26E85D3D'; Track = '#1AFFFFFF'; Segment = '#E85D3D'; Glow = $true;
            Status = '#E85D3D'; Rate = '#E85D3D'; Clock = '#E9EDF3'; Date = '#8B94A5'; Week = '#8B94A5'; CdLabel = '#5A6272'; CdValue = '#8B94A5'; StatusIcon = '#E85D3D' }
        Idle = @{ Accent = '#2FB89A'; AccentSoft = '#2FB89A'; BadgeBg = '#262FB89A'; Track = '#1AFFFFFF'; Segment = '#2FB89A'; Glow = $true;
            Status = '#2FB89A'; Rate = '#2FB89A'; Clock = '#E9EDF3'; Date = '#8B94A5'; Week = '#8B94A5'; CdLabel = '#5A6272'; CdValue = '#8B94A5'; StatusIcon = '#2FB89A' }
        Badge = 'tint'
    }
    # F1 峰谷示波器：网页稿整卡是琥珀色，峰/谷换色，周末与节假日换成青蓝平线
    'amber-scope' = @{
        Peak = @{ Accent = '#F59E0B'; AccentSoft = '#F59E0B'; BadgeBg = '#26F59E0B'; Track = '#1AF59E0B'; Segment = '#F59E0B'; Glow = $true;
            Status = '#FBBF24'; Rate = '#F59E0B'; CdLabel = '#64748B'; CdValue = '#F59E0B'; Date = '#94A3B8'; Week = '#94A3B8';
            BadgeBorder = '#4DF59E0B'; ScopeBorder = '#40F59E0B'; ScopeGlow = '#1AF59E0B'; ScopeBg1 = '#161F30'; ScopeBg2 = '#080C14'; StatusIcon = '#F59E0B'; Marker = '#FFFFFF' }
        Idle = @{ Accent = '#10B981'; AccentSoft = '#10B981'; BadgeBg = '#2610B981'; Track = '#1A10B981'; Segment = '#10B981'; Glow = $true;
            Status = '#34D399'; Rate = '#10B981'; CdLabel = '#64748B'; CdValue = '#10B981'; Date = '#94A3B8'; Week = '#94A3B8';
            BadgeBorder = '#4D10B981'; ScopeBorder = '#4010B981'; ScopeGlow = '#1A10B981'; ScopeBg1 = '#0F2420'; ScopeBg2 = '#080C14'; StatusIcon = '#10B981'; Marker = '#FFFFFF' }
        Weekend = @{ Accent = '#06B6D4'; AccentSoft = '#06B6D4'; BadgeBg = '#2606B6D4'; Track = '#1A06B6D4'; Segment = '#06B6D4'; Glow = $true;
            Status = '#22D3EE'; Rate = '#06B6D4'; CdLabel = '#64748B'; CdValue = '#06B6D4'; Date = '#94A3B8'; Week = '#94A3B8';
            BadgeBorder = '#4D06B6D4'; ScopeBorder = '#4006B6D4'; ScopeGlow = '#1A06B6D4'; ScopeBg1 = '#0A1B24'; ScopeBg2 = '#080C14'; StatusIcon = '#06B6D4'; Marker = '#FFFFFF' }
        Holiday = @{ Accent = '#06B6D4'; AccentSoft = '#06B6D4'; BadgeBg = '#2606B6D4'; Track = '#1A06B6D4'; Segment = '#06B6D4'; Glow = $true;
            Status = '#22D3EE'; Rate = '#06B6D4'; CdLabel = '#64748B'; CdValue = '#06B6D4'; Date = '#94A3B8'; Week = '#94A3B8';
            BadgeBorder = '#4D06B6D4'; ScopeBorder = '#4006B6D4'; ScopeGlow = '#1A06B6D4'; ScopeBg1 = '#0A1B24'; ScopeBg2 = '#080C14'; StatusIcon = '#06B6D4'; Marker = '#FFFFFF' }
        Badge = 'tint'
    }
    # D3 K 线：标题跟着状态换（峰橙红 / 谷青绿），蜡烛本身固定双色
    'kline' = @{
        Peak = @{ Accent = '#E85D3D'; AccentSoft = '#E85D3D'; BadgeBg = '#26E85D3D'; Track = '#1AFFFFFF'; Segment = '#E85D3D'; Glow = $false;
            Status = '#E85D3D'; Rate = '#E85D3D'; Clock = '#E9EDF3'; Date = '#8B94A5'; Week = '#8B94A5'; CdLabel = '#5A6272'; CdValue = '#8B94A5'; StatusIcon = '#E85D3D' }
        Idle = @{ Accent = '#2FB89A'; AccentSoft = '#2FB89A'; BadgeBg = '#262FB89A'; Track = '#1AFFFFFF'; Segment = '#2FB89A'; Glow = $false;
            Status = '#2FB89A'; Rate = '#2FB89A'; Clock = '#E9EDF3'; Date = '#8B94A5'; Week = '#8B94A5'; CdLabel = '#5A6272'; CdValue = '#8B94A5'; StatusIcon = '#2FB89A' }
        Badge = 'tint'
    }
    # D6 半谷：整卡都是白字，压在橙 / 青双色块上
    'half' = @{
        Peak = @{ Accent = '#FFFFFF'; AccentSoft = '#FFFFFF'; BadgeBg = '#00000000'; Track = '#1AFFFFFF'; Segment = '#FFFFFF'; Glow = $false;
            Status = '#FFFFFF'; Rate = '#FFFFFF'; Clock = '#FFFFFF'; CdLabel = '#8AFFFFFF'; CdValue = '#B8FFFFFF'; Date = '#B8FFFFFF'; Week = '#B8FFFFFF'; StatusIcon = '#FFD9C9' }
        Idle = @{ Accent = '#FFFFFF'; AccentSoft = '#FFFFFF'; BadgeBg = '#00000000'; Track = '#1AFFFFFF'; Segment = '#FFFFFF'; Glow = $false;
            Status = '#FFFFFF'; Rate = '#FFFFFF'; Clock = '#FFFFFF'; CdLabel = '#8AFFFFFF'; CdValue = '#B8FFFFFF'; Date = '#B8FFFFFF'; Week = '#B8FFFFFF'; StatusIcon = '#CFF3E9' }
        Badge = 'tint'
    }
}

# ============================ 玻璃背景画（网页稿的彩色底片） ============================
# 网页里这些玻璃方案的彩色底来自页面背景 + backdrop-filter。WPF 没有真背景模糊，
# 这里把同一套「紫 / 蓝 / 粉 / 青」光斑直接烘进卡片，再压一层半透明白玻璃。
# 每个光斑：C=颜色，A=透明度(0-255)，X/Y=中心相对位置，R=直径相对卡片对角线的大小。
$script:ArtStyles = @{
    'a1' = @{
        Base1 = '#1A1236'; Base2 = '#070B18'
        Glass = 62; GlassMid = 14; Glass2 = 30; Grid = 0
        Blobs = @(
            @{ C = '#8B5CF6'; A = 155; X = 0.10; Y = 0.02; R = 1.15 },
            @{ C = '#EC4899'; A = 115; X = 0.92; Y = 0.98; R = 1.05 },
            @{ C = '#3B82F6'; A = 125; X = 0.55; Y = 0.28; R = 1.00 },
            @{ C = '#14B8A6'; A = 75;  X = 0.10; Y = 0.95; R = 0.85 },
            @{ C = '#FFFFFF'; A = 110; X = 0.88; Y = 0.88; R = 0.65 }
        )
        Glow = $true
    }
    'a5' = @{
        Base1 = '#FDFEFF'; Base2 = '#ECF4FB'
        Glass = 88; GlassMid = 26; Glass2 = 62; Grid = 0
        Blobs = @(
            @{ C = '#FFD08A'; A = 150; X = 0.10; Y = 1.00; R = 0.95 },
            @{ C = '#8FE3D0'; A = 135; X = 0.92; Y = 0.95; R = 0.95 },
            @{ C = '#BBD3F5'; A = 90;  X = 0.50; Y = 0.00; R = 0.80 }
        )
        Glow = $true
    }
    'b1' = @{
        Base1 = '#1B2940'; Base2 = '#080C16'
        Glass = 30; GlassMid = 7; Glass2 = 15; Grid = 16
        Blobs = @(
            @{ C = '#FFB020'; A = 125; X = 0.86; Y = 0.02; R = 0.90 },
            @{ C = '#3B82F6'; A = 55;  X = 0.10; Y = 0.92; R = 0.90 },
            @{ C = '#FFFFFF'; A = 35;  X = 0.35; Y = 0.00; R = 0.65 }
        )
        Glow = $true
    }
    'b5' = @{
        Base1 = '#1A1D2A'; Base2 = '#06090F'
        Glass = 22; GlassMid = 4; Glass2 = 10; Grid = 16
        Blobs = @(
            @{ C = '#FFB020'; A = 105; X = 0.04; Y = 0.00; R = 0.80 },
            @{ C = '#3B82F6'; A = 45;  X = 0.92; Y = 0.92; R = 0.85 }
        )
        Glow = $true
    }
    'a3' = @{
        Base1 = '#1A1330'; Base2 = '#0A0F22'
        Glass = 40; GlassMid = 8; Glass2 = 20; Grid = 0
        Blobs = @(
            @{ C = '#8B5CF6'; A = 120; X = 0.10; Y = 0.00; R = 1.05 },
            @{ C = '#EC4899'; A = 90;  X = 0.92; Y = 1.00; R = 1.00 },
            @{ C = '#3B82F6'; A = 90;  X = 0.55; Y = 0.25; R = 0.95 },
            @{ C = '#14B8A6'; A = 55;  X = 0.10; Y = 1.00; R = 0.80 }
        )
        Glow = $true
    }
    'b3' = @{
        Base1 = '#141A2E'; Base2 = '#080C16'
        Glass = 30; GlassMid = 6; Glass2 = 16; Grid = 16
        Blobs = @(
            @{ C = '#FFB020'; A = 100; X = 0.12; Y = 0.10; R = 0.85 },
            @{ C = '#3B82F6'; A = 90;  X = 0.55; Y = 0.35; R = 0.95 },
            @{ C = '#8B5CF6'; A = 60;  X = 0.95; Y = 0.90; R = 0.85 }
        )
        Glow = $true
    }
    'a6' = @{
        Base1 = '#0C1224'; Base2 = '#05080F'
        Glass = 24; GlassMid = 6; Glass2 = 14; Grid = 46
        Blobs = @(
            @{ C = '#3B82F6'; A = 105; X = 0.50; Y = 0.30; R = 0.95 },
            @{ C = '#8B5CF6'; A = 85;  X = 0.85; Y = 0.90; R = 0.90 },
            @{ C = '#FFFFFF'; A = 45;  X = 0.30; Y = 0.02; R = 0.60 }
        )
        Glow = $true
    }
    'b4' = @{
        Base1 = '#101A2E'; Base2 = '#06090F'
        Glass = 20; GlassMid = 5; Glass2 = 12; Grid = 46
        Blobs = @(
            @{ C = '#2E4A7D'; A = 115; X = 0.15; Y = 0.00; R = 0.90 },
            @{ C = '#FFB020'; A = 55;  X = 0.05; Y = 0.20; R = 0.60 },
            @{ C = '#8B5CF6'; A = 45;  X = 0.90; Y = 0.90; R = 0.80 }
        )
        Glow = $true
    }
    'c1' = @{
        Base1 = '#15171D'; Base2 = '#111318'
        Glass = 8; GlassMid = 2; Glass2 = 4; Grid = 15
        Blobs = @(); Glow = $false
    }
    'c3' = @{
        Base1 = '#12141A'; Base2 = '#0E1015'
        Glass = 10; GlassMid = 3; Glass2 = 6; Grid = 15
        Blobs = @(); Glow = $false
    }
    'd1' = @{
        Base1 = '#111318'; Base2 = '#0B0D12'
        Glass = 6; GlassMid = 2; Glass2 = 4; Grid = 16
        Blobs = @(); Glow = $false
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
    Art       = ''          # 玻璃底片样式名（$script:ArtStyles）
    InlineCountdown = $false
    ClockSecSame = $false
    OrbSize   = 0
    OrbAura   = 0
    OrbRing   = 0
    RatePad   = '8,3,8,3'
    RateRadius = 9
    ClockWeight = 'Bold'
    PillPad   = '10,5,12,5'
    PillRadius = 14
    StatusDotSize = 9
    TickDark  = $false
    MarkerWidth = 2        # 时间轴游标的宽度（A1 需要更明显的「刻度线」）
    MarkerGlow = $false    # 时间轴游标是否带白色辉光
    HudDrain = $false      # HUD 进度条：true = 满格开始逐渐排空（剩余量）
    HudBarHeight = 5       # HUD 分段进度条的高度
    HudSegments = 8        # HUD 分段数量
    HudTopBar = $true      # HUD 顶部状态色横线是否显示
    WeekFirst = $false
    DateFontSize = 13
    WeekFontSize = 11
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
    Border = '#38FFFFFF'; BorderWidth = 1; Radius = 24; Margin = 10
    BodyPad = '18,16,18,16'
    ClockSize = 34; ClockSecSize = 13; StatusSize = 12; CountdownSize = 10.5
    DateFontSize = 11; WeekFontSize = 10
    RatePad = '8,4,8,4'; RateRadius = 9
    Shadow = @{ Blur = 26; Depth = 7; Opacity = 0.55; Color = '#000000' }
    # 轨道改成半透明白：在彩色玻璃底上原来的深蓝几乎看不见
    Text = @{ Status = '#FFFFFF'; PillBg = '#13FFFFFF'; StatusPillBorder = '#2BFFFFFF'; RateBorder = '#2BFFFFFF'; Date = '#A9B6C9'; Week = '#E8EDF6'; Hint = '#7C8AA5'; CdLabel = '#9EEBF4FF'; CdValue = '#F8FBFF'; Track = '#52FFFFFF'; Marker = '#FFFFFF' }
    ClockWeight = 'SemiBold'
    PillPad = '9,5,9,5'; PillRadius = 13
    StatusDotSize = 8
    MarkerWidth = 3; MarkerGlow = $true
    Art = 'a1'; Decor = @('sheen')
}

Add-Scheme @{
    Key = 'a3'; Num = 'A3'; Name = 'A3 · 灵动极简胶囊'
    Hint = '横向胶囊 500×120，左侧状态光球呼吸，最省桌面空间'
    Layout = 'banner'; Width = 516; Height = 140
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#E61A2233'; To = '#F00B1018' }
    Border = '#38FFFFFF'; BorderWidth = 1; Radius = 42; Margin = 10
    BodyPad = '28,0,28,0'
    ClockSize = 34; ClockSecSize = 13; ClockSecSame = $false
    StatusDotSize = 10; OrbSize = 10; OrbAura = 120; OrbRing = 28
    PlainRate = $true
    Timeline = $false
    Shadow = @{ Blur = 30; Depth = 8; Opacity = 0.55; Color = '#000000' }
    Text = @{ Status = '#FFFFFF'; Date = '#8AFFFFFF'; Week = '#8AFFFFFF'; CdLabel = '#8AFFFFFF'; CdValue = '#FFFFFF' }
    Art = 'a3'; Decor = @('bannerpulse', 'sheen')
}

Add-Scheme @{
    Key = 'a5'; Num = 'A5'; Name = 'A5 · 霜白明澈玻璃'
    Hint = '浅色壁纸首选：霜白玻璃 + 深色字，像控制中心'
    Layout = 'card'; Width = 316
    Tone = 'light'; Palette = 'glass-light'
    Surface = @{ Type = 'gradient'; From = '#F2FFFFFF'; To = '#E6E8EEF6' }
    Border = '#EBFFFFFF'; BorderWidth = 1; Radius = 24; Margin = 10
    BodyPad = '18,16,18,16'
    ClockSize = 34; ClockSecSize = 13; StatusSize = 12; CountdownSize = 10.5
    DateFontSize = 11; WeekFontSize = 10
    RatePad = '8,4,8,4'; RateRadius = 9
    Shadow = @{ Blur = 24; Depth = 6; Opacity = 0.22; Color = '#1E293B' }
    # 浅色底上原来的 12% 深色轨道太淡，加到 25% 才看得清
    Text = @{ Status = '#0B1424'; PillBg = '#CCFFFFFF'; StatusPillBorder = '#FFFFFFFF'; RateBorder = '#E6FFFFFF'; Date = '#5A6B85'; Week = '#0B1424'; Hint = '#8A9AAE'; CdLabel = '#990B1424'; CdValue = '#0B1424'; Track = '#400F172A' }
    ClockWeight = 'SemiBold'
    PillPad = '9,5,9,5'; PillRadius = 13
    StatusDotSize = 8
    MarkerWidth = 3
    Art = 'a5'; Decor = @('sheen')
}

Add-Scheme @{
    Key = 'a6'; Num = 'A6'; Name = 'A6 · 24h 环形轨道玻璃'
    Hint = '圆形表盘 Ø300，外圈 24 小时轨道，当前时刻一根指针'
    Layout = 'orbitA6'; Width = 326; Height = 326
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#F0182233'; To = '#F00B1018' }
    Radius = 153; Margin = 10; BodyPad = '0'
    ClockSize = 41; ClockSecSize = 15; ClockWeight = 'SemiBold'
    Timeline = $false
    Text = @{ Status = '#F2F8FF'; Date = '#8AFFFFFF'; Week = '#8AFFFFFF'; CdLabel = '#A0FFFFFF'; CdValue = '#E8EDF6' }
    Art = 'a6'; Decor = @('orbitglow', 'sheen')
}

# ---------- B · v2 玻璃材质深化 ----------
Add-Scheme @{
    Key = 'b1'; Num = 'B1'; Name = 'B1 · 深空琥珀'
    Hint = '深色厚玻璃，状态光晕从右上角渗出'
    Layout = 'card'; Width = 344; Height = 208
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'radial'; From = '#24F59E0B'; To = '#F00A0D14'; Center = '0.92,0.06' }
    Radius = 20; Margin = 14
    BodyPad = '16,13,16,13'
    ClockSize = 40; ClockSecSize = 40; ClockSecSame = $true
    ClockWeight = 'Light'
    StatusSize = 14; RateSize = 16; CountdownSize = 12
    DateInline = $true; PlainRate = $true; InlineCountdown = $true
    Text = @{ Date = '#A9B6C9'; Hint = '#7C8AA5'; Track = '#402DD4A7'; CdLabel = '#8B94A5'; CdValue = '#F8FBFF' }
    Art = 'b1'; Decor = @('glowcorner', 'sheen')
}

Add-Scheme @{
    Key = 'b3'; Num = 'B3'; Name = 'B3 · 流光胶囊'
    Hint = '横向胶囊 500×120，左侧光球呼吸 + 右侧信息横排，像桌面小宠物'
    Layout = 'banner'; Width = 500; Height = 130
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#F0141A24'; To = '#F0080A0F' }
    Border = '#38FFFFFF'; BorderWidth = 1; Radius = 42; Margin = 10
    BodyPad = '24,0,24,0'
    ClockSize = 40; ClockSecSize = 40; ClockSecSame = $true
    ClockWeight = 'SemiBold'
    StatusDotSize = 54; OrbSize = 54; OrbAura = 150; OrbRing = 92
    PlainRate = $true
    Timeline = $true
    Shadow = @{ Blur = 30; Depth = 8; Opacity = 0.55; Color = '#000000' }
    Text = @{ Date = '#A9B6C9'; Week = '#A9B6C9'; CdLabel = '#8B94A5'; CdValue = '#F8FBFF'; Track = '#402DD4A7' }
    Art = 'b3'; Decor = @('bannerpulse', 'sheen')
}

Add-Scheme @{
    Key = 'b4'; Num = 'B4'; Name = 'B4 · 石英表盘'
    Hint = '24 小时压成一圈，两段高峰弧 + 当前时刻指针'
    Layout = 'orbitB4'; Width = 320; Height = 320
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#F0161C26'; To = '#F006080C' }
    Radius = 150; Margin = 10; BodyPad = '0'
    ClockSize = 40; ClockSecSize = 40; ClockSecSame = $true; ClockWeight = 'Light'
    RateSize = 28; PlainRate = $true
    Timeline = $false
    Text = @{ Rate = '#F59E0B'; CdLabel = '#7C8AA5'; CdValue = '#8B94A5' }
    Art = 'b4'; Decor = @('quartzring', 'sheen')
}

Add-Scheme @{
    Key = 'b5'; Num = 'B5'; Name = 'B5 · 熔岩边缘'
    Hint = '去掉流光颗粒，只留左侧 3px 状态光柱，最安静'
    Layout = 'card'; Width = 344; Height = 208
    Tone = 'dark'; Palette = 'glass-dark'
    Surface = @{ Type = 'gradient'; From = '#1E2028'; To = '#090A0E' }
    Border = '#1AFFFFFF'; Radius = 20; Margin = 14
    BodyPad = '16,13,16,13'
    ClockSize = 40; ClockSecSize = 40; ClockSecSame = $true
    ClockWeight = 'Light'
    StatusSize = 14; RateSize = 16; CountdownSize = 12
    DateInline = $true; PlainRate = $true; InlineCountdown = $true
    Text = @{ Date = '#A9B6C9'; Hint = '#7C8AA5'; Track = '#402DD4A7'; CdLabel = '#8B94A5'; CdValue = '#F8FBFF' }
    StatusDot = $false; AccentBar = $true; Art = 'b5'; Decor = @('sheen')
    Shadow = @{ Blur = 24; Depth = 6; Opacity = 0.55; Color = '#000000' }
}

# ---------- C · v3 仪器方向 ----------
Add-Scheme @{
    Key = 'c1'; Num = 'C1'; Name = 'C1 · 仪表盘'
    Hint = '实色仪器面板 + 等宽数字 + 底部刻度尺'
    Layout = 'card'; Width = 344; Height = 208
    Tone = 'mono'; Palette = 'panel'
    ClockFont = 'Consolas, Cascadia Mono, Microsoft YaHei UI'
    ClockSize = 38
    ClockWeight = 'Normal'
    Surface = @{ Type = 'solid'; From = '#15171D'; To = '#15171D' }
    Border = '#2C313D'; Radius = 6; Margin = 14
    Shadow = @{ Blur = 16; Depth = 4; Opacity = 0.4; Color = '#000000' }
    BodyPad = '15,13,15,26'
    Timeline = $false
    StatusDotSize = 4; PillPad = '8,4,8,4'; PillRadius = 4
    Art = 'c1'; Decor = @('ticks')
}

Add-Scheme @{
    Key = 'c2'; Num = 'C2'; Name = 'C2 · 报表'
    Hint = '米白纸感 + 衬线数字，左侧 4px 竖色条是唯一状态信号'
    Layout = 'card'; Width = 344; Height = 208
    Tone = 'paper'; Palette = 'paper'
    ClockFont = 'Cambria, Georgia, Microsoft YaHei UI'
    ClockSize = 34
    ClockWeight = 'Normal'
    Surface = @{ Type = 'solid'; From = '#F7F3EA'; To = '#F7F3EA' }
    Border = '#E2D9C8'; Radius = 4; Margin = 14
    Shadow = @{ Blur = 14; Depth = 3; Opacity = 0.18; Color = '#57534E' }
    BodyPad = '15,30,15,13'
    AccentBar = $true
    ClockSecSame = $true; ClockSecSize = 34
    InlineCountdown = $true
    StatusSquare = $true
    Timeline = $false; TickDark = $true
    Decor = @('c2header', 'ticks')
}

Add-Scheme @{
    Key = 'c3'; Num = 'C3'; Name = 'C3 · 刻度带'
    Hint = '520×120 横向窄条，整条刻度尺贯穿底部'
    Layout = 'tape'; Width = 480; Height = 132
    Tone = 'mono'; Palette = 'panel'
    ClockFont = 'Consolas, Cascadia Mono, Microsoft YaHei UI'
    ClockSize = 38; ClockWeight = 'Normal'
    ClockSecSize = 38; ClockSecSame = $true
    Surface = @{ Type = 'solid'; From = '#12141A'; To = '#12141A' }
    Border = '#232C38'; Radius = 8; Margin = 10
    BodyPad = '16,12,16,12'
    StatusDotSize = 4; StatusSize = 10.5; RateSize = 16
    PlainRate = $true
    Timeline = $false
    Art = 'c3'; Decor = @('ticks')
}

Add-Scheme @{
    Key = 'c4'; Num = 'C4'; Name = 'C4 · 圆表'
    Hint = '真仪表盘 Ø300：外圈刻度 + 内环高峰弧 + 白色游标'
    Layout = 'gauge'; Width = 320; Height = 320
    Tone = 'mono'; Palette = 'gauge'
    ClockFont = 'Cascadia Mono, Consolas, Microsoft YaHei UI'
    ClockSize = 34
    Surface = @{ Type = 'solid'; From = '#14161C'; To = '#14161C' }
    Border = '#2C313D'; BorderWidth = 1
    Radius = 150; Margin = 10; BodyPad = '0'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 22; Depth = 5; Opacity = 0.5; Color = '#000000' }
    Decor = @('gauge')
}

Add-Scheme @{
    Key = 'c6'; Num = 'C6'; Name = 'C6 · 色块'
    Hint = '整块底色就是状态：高峰满版琥珀、空闲满版青绿'
    Layout = 'solid'; Width = 304; Height = 184
    Tone = 'light'; Palette = 'block'
    ClockFont = 'Cascadia Mono, Consolas, Microsoft YaHei UI'
    ClockSize = 38
    Surface = @{ Type = 'solid'; From = '#E8A33A'; To = '#E8A33A' }
    Border = '#D08F28'; BorderWidth = 1; Radius = 8; Margin = 12
    StatusDot = $false; Timeline = $false
    BodyPad = '15,13,15,12'
    SurfaceByState = $true
    Shadow = @{ Blur = 18; Depth = 4; Opacity = 0.45; Color = '#000000' }
    Decor = @('scalebar')
}

# ---------- D · v4 波峰波谷 ----------
Add-Scheme @{
    Key = 'd1'; Num = 'D1'; Name = 'D1 · 示波器'
    Hint = '一整天画成一条连续波形：两个平台是峰，中间凹陷是谷'
    Layout = 'card'; Width = 344; Height = 208
    Tone = 'dark'; Palette = 'scope'
    ClockFont = 'Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI'
    ClockSize = 36; ClockSecSize = 36; ClockSecSame = $true
    ClockWeight = 'Light'
    Surface = @{ Type = 'solid'; From = '#111318'; To = '#111318' }
    Border = '#1E2836'; Radius = 12; Margin = 14
    BodyPad = '15,13,15,10'
    Timeline = $false
    InlineCountdown = $true
    Art = 'd1'; Decor = @('wave')
}

Add-Scheme @{
    Key = 'd3'; Num = 'D3'; Name = 'D3 · K 线'
    Hint = '24 根蜡烛，越高越贵；高峰橙红粗柱、空闲暗绿矮块'
    Layout = 'candle'; Width = 340; Height = 204
    Tone = 'dark'; Palette = 'kline'
    ClockFont = 'Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI'
    ClockSize = 34
    Surface = @{ Type = 'solid'; From = '#14161C'; To = '#14161C' }
    Border = '#00000000'; BorderWidth = 0; Radius = 10; Margin = 12
    BodyPad = '15,13,15,11'
    Timeline = $false; StatusDot = $false
    Decor = @('kline')
}

Add-Scheme @{
    Key = 'd6'; Num = 'D6'; Name = 'D6 · 半谷'
    Hint = '整块斜切成两半，红是峰、绿是谷，面积比就是时长比'
    Layout = 'half'; Width = 324; Height = 194
    Tone = 'dark'; Palette = 'half'
    ClockSize = 38
    Surface = @{ Type = 'solid'; From = '#E4552E'; To = '#E4552E' }
    Border = '#00000000'; BorderWidth = 0; Radius = 16; Margin = 12
    BodyPad = '17,15,17,13'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 20; Depth = 5; Opacity = 0.4; Color = '#000000' }
}

# ---------- E · 全新风格 ----------
Add-Scheme @{
    Key = 'e2'; Num = 'E2'; Name = 'E2 · 工业级仪表 HUD'
    Hint = '顶部琥珀条 + 描边框 + 8 段发光进度，随当前窗口实时推进'
    Layout = 'hud'; Width = 314; Height = 189
    Tone = 'mono'; Palette = 'hud'
    ClockFont = 'Cascadia Code, Consolas, Microsoft YaHei UI'
    ClockSize = 28
    Surface = @{ Type = 'solid'; From = '#0A0E14'; To = '#0A0E14' }
    Border = '#1E293B'; BorderWidth = 1; Radius = 4; Margin = 12
    BodyPad = '14,12,14,11'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 18; Depth = 4; Opacity = 0.45; Color = '#000000' }
    Decor = @('hudprogress')
}

Add-Scheme @{
    Key = 'e2b'; Num = 'E2B'; Name = 'E2B · 中文余量 HUD'
    Hint = '全中文工业 HUD；剩余时间从满格递减，时间更大更粗，进度条更厚'
    Layout = 'hud'; Width = 334; Height = 202
    Tone = 'mono'; Palette = 'hud'
    ClockFont = 'Cascadia Code, Consolas, Microsoft YaHei UI'
    ClockSize = 40
    Surface = @{ Type = 'solid'; From = '#0A0E14'; To = '#0A0E14' }
    Border = '#1E293B'; BorderWidth = 1; Radius = 4; Margin = 12
    BodyPad = '14,12,14,12'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 18; Depth = 4; Opacity = 0.45; Color = '#000000' }
    HudDrain = $true; HudBarHeight = 9; HudTopBar = $false
    Decor = @('hudprogress')
}

Add-Scheme @{
    Key = 'e3'; Num = 'E3'; Name = 'E3 · 新野兽派'
    Hint = '白底 + 2px 黑边 + 零模糊硬投影，高对比年轻化'
    Layout = 'brutal'; Width = 314; Height = 189
    Tone = 'light'; Palette = 'brutal'
    ClockFont = 'Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI'
    Surface = @{ Type = 'solid'; From = '#FFFFFF'; To = '#FFFFFF' }
    Border = '#111111'; BorderWidth = 2; Radius = 0; Margin = 12
    BodyPad = '12'
    ClockSize = 34
    StatusDot = $false; Timeline = $false
    Shadow = @{ Blur = 0; Depth = 4; Opacity = 1; Color = '#000000'; Direction = 315 }
}

Add-Scheme @{
    Key = 'e4'; Num = 'E4'; Name = 'E4 · 双色瑞士分屏'
    Hint = '左侧实色状态铭牌（高峰/PEAK/1.0×/工作日）+ 右侧黑曜石大字'
    Layout = 'split'; Width = 330; Height = 175
    Tone = 'dark'; Palette = 'swiss'
    ClockFont = 'Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI'
    Surface = @{ Type = 'solid'; From = '#18181B'; To = '#18181B' }
    Border = '#27272A'; BorderWidth = 1; Radius = 10; Margin = 10
    ClockSize = 32
    StatusDot = $false; HideStatus = $true; Timeline = $false
    BodyPad = '16,14,16,14'
    Shadow = @{ Blur = 18; Depth = 4; Opacity = 0.45; Color = '#000000' }
}

Add-Scheme @{
    Key = 'e5'; Num = 'E5'; Name = 'E5 · 点阵液晶'
    Hint = '暖棕黑底 + 琥珀液晶数字，屏槽框 + 双虚线分隔'
    Layout = 'lcd'; Width = 315; Height = 180
    Tone = 'amber'; Palette = 'amber-crt'
    ClockFont = 'Courier New, Consolas, Microsoft YaHei UI'
    ClockSize = 34
    Surface = @{ Type = 'solid'; From = '#262016'; To = '#262016' }
    Border = '#453721'; BorderWidth = 2; Radius = 6; Margin = 10
    BodyPad = '14,12,14,12'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 20; Depth = 5; Opacity = 0.5; Color = '#000000' }
    Decor = @('lcdvig')
}

# ---------- F · 梗图向 ----------
Add-Scheme @{
    Key = 'f1'; Num = 'F1'; Name = 'F1 · 峰谷示波器'
    Hint = '琥珀描边波形框：两个圆峰 + 峰顶 PEAK 标记 + 当前时刻竖虚线'
    Layout = 'scope'; Width = 304; Height = 226
    Tone = 'dark'; Palette = 'amber-scope'
    ClockFont = 'Cascadia Code, Consolas, Microsoft YaHei UI'
    ClockSize = 26
    Surface = @{ Type = 'solid'; From = '#111827'; To = '#111827' }
    Border = '#1F2937'; BorderWidth = 1; Radius = 14; Margin = 12
    BodyPad = '14'
    Timeline = $false; StatusDot = $false
    Shadow = @{ Blur = 20; Depth = 5; Opacity = 0.5; Color = '#000000' }
    Decor = @('scope')
}

# ============================ 网页稿对齐补丁 ============================
# 逐个方案把「网页稿里到底怎么排的」补进来，全是排版开关，不动配色。
# 判断依据是 design/ 下 7 份原稿 + live-v1-states.html 的实际截图，
# 网页原稿卡片对照图留在本地 design/_states/web（不入库）。
$script:SchemeTweaks = @{
    # 默认界面：价格是药丸，倒计时整句「距空闲时段还有」
    'default' = @{ ClockSecSize = 34; ClockSecSame = $true; InlineCountdown = $true; WeekFirst = $true; DateFontSize = 11; WeekFontSize = 13; RateSize = 11; CdIdle = '距空闲时段还有'; CdPeak = '距高峰时段还有' }
    # A1 / A5：状态和价格都是药丸（带底色和细描边）
    'a1'      = @{ StatusSize = 13.5; StatusPillStyle = $true; RateSize = 11; ClockSecSize = 16; CdIdle = '距空闲时段还有'; CdPeak = '距高峰时段还有' }
    'a5'      = @{ StatusSize = 13.5; StatusPillStyle = $true; RateSize = 11; ClockSecSize = 16; CdIdle = '距空闲时段还有'; CdPeak = '距高峰时段还有' }
    # B 组：价格是裸文字「1.0×」，字号明显大于小标签
    'b1'      = @{ StatusSize = 14; DateInline = $true; PlainRate = $true; RateSize = 16; ClockSecSize = 40; ClockSecSame = $true; InlineCountdown = $true; DateFontSize = 12; WeekFontSize = 12; CdIdle = '距空闲'; CdPeak = '距高峰' }
    'b5'      = @{ StatusSize = 14; DateInline = $true; PlainRate = $true; RateSize = 16; ClockSecSize = 40; ClockSecSame = $true; InlineCountdown = $true; DateFontSize = 12; WeekFontSize = 12; CdIdle = '距空闲'; CdPeak = '距高峰' }
    # C 组：仪表类，时钟全同号（等宽），价格裸文字
    'c1'      = @{ StatusSize = 10.5; DateInline = $true; PlainRate = $true; RateSize = 14; StatusPillStyle = $true; StatusPillSolid = $true; ClockSecSize = 38; ClockSecSame = $true; InlineCountdown = $true; DateFontSize = 11; WeekFontSize = 11; CdIdle = '距空闲'; CdPeak = '距高峰' }
    'c2'      = @{ StatusSize = 14; DateInline = $true; PlainRate = $true; RateSize = 14; ClockSecSize = 34; ClockSecSame = $true; InlineCountdown = $true; DateFontSize = 11; WeekFontSize = 11; CdIdle = '距空闲'; CdPeak = '距高峰' }
    'c6'      = @{ StatusSize = 12; DateInline = $true; PlainRate = $true; RateSize = 16; StatusSquare = $true; ClockSecSize = 38; CdIdle = '距空闲'; CdPeak = '距高峰' }
    # D 组：梗图向，倒计时写成「距梁文谷 / 距梁文峰」
    'd1'      = @{ StatusSize = 15; DateInline = $true; PlainRate = $true; RateSize = 16; ClockSecSize = 36; ClockSecSame = $true; InlineCountdown = $true; DateFontSize = 11.5; WeekFontSize = 11.5; CdIdle = '距梁文谷'; CdPeak = '距梁文峰' }
    'd3'      = @{ StatusSize = 12.5; DateInline = $true; PlainRate = $true; RateSize = 16; ClockSecSize = 34; CdIdle = '距梁文谷'; CdPeak = '距梁文峰' }
    'd6'      = @{ StatusSize = 12.5; DateInline = $true; PlainRate = $true; RateSize = 16; ClockSecSize = 38; CdIdle = '距梁文谷'; CdPeak = '距梁文峰' }
    # E 组：工业 HUD / 液晶，全英文等宽标签
    'e2'      = @{ StatusSize = 11; DateInline = $true; PlainRate = $true; RateSize = 10; StatusPillStyle = $true; ClockSecSize = 28; CdIdle = 'NEXT IDLE IN:'; CdPeak = 'NEXT PEAK IN:' }
    'e2b'     = @{ StatusSize = 13; DateInline = $true; RateSize = 13; StatusPillStyle = $true; CdIdle = '距空闲还有'; CdPeak = '距高峰还有' }
    'e3'      = @{ StatusSize = 11; DateInline = $true; PlainRate = $true; RateSize = 11; ClockSecSize = 34; CdIdle = '距空闲倒计时'; CdPeak = '距高峰倒计时'; Timeline = $false }
    'e4'      = @{ StatusSize = 15; DateInline = $true; PlainRate = $true; RateSize = 20; ClockSecSize = 32; CdIdle = '距空闲'; CdPeak = '距高峰'; Timeline = $false }
    'e5'      = @{ StatusSize = 11; DateInline = $true; PlainRate = $true; RateSize = 11; StatusPillStyle = $true; ClockSecSize = 34; CdIdle = 'NEXT IDLE:'; CdPeak = 'NEXT PEAK:' }
    # F1：倒计时带价格后缀
    'f1'      = @{ StatusSize = 12; DateInline = $true; PlainRate = $true; RateSize = 11; ClockSecSize = 26; CdIdle = '距入谷 (0.5×)'; CdPeak = '距登峰 (1.0×)' }
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
    # 个别方案（F1 示波器）周末/法定节假日有独立的青蓝配色
    if ($Status.IsWeekend -and $palette.ContainsKey('Weekend')) { $state = $palette.Weekend }
    if ($Status.IsHoliday -and $palette.ContainsKey('Holiday')) { $state = $palette.Holiday }
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
    # 配色状态里额外定义的色键（Chip / CdLabel / CdValue / Surface / Rule …）
    # 原样带出去，模板和装饰器按需取用；基础键保持上面的默认值。
    $baseKeys = @('Accent', 'AccentSoft', 'BadgeBg', 'Track', 'Segment', 'Glow', 'OnAccent')
    foreach ($name in $state.Keys) {
        if ($baseKeys -contains [string]$name) { continue }
        $colors[[string]$name] = $state[$name]
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
        <RowDefinition Height="*" />
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
      <Grid Grid.Row="3" Margin="0,10,0,0" Height="10">
        <Canvas x:Name="TimelineCanvas" Height="10" ClipToBounds="True" HorizontalAlignment="Stretch">
          <Rectangle x:Name="TimelineTrack" Canvas.Left="0" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#332A3A4D" />
          <Rectangle x:Name="PeakSegment1" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="PeakSegment2" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="TimeMarker" Canvas.Top="0" Width="2" Height="10" RadiusX="1" RadiusY="1" Fill="#F8FAFC" />
        </Canvas>
      </Grid>
      <Grid x:Name="FootGrid" Grid.Row="4" Margin="0,8,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <StackPanel x:Name="FootStack" Orientation="Horizontal" VerticalAlignment="Center">
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

# 14 个「结构本身就不一样」的方案走 13 套专属模板（A3/B3 胶囊、A6/B4 圆盘、C3 刻度带、
# 峰谷示波器 / 点阵液晶 / 瑞士分屏 / 新野兽派 / 半谷 / K 线 / 色块 / HUD / 圆表），
# 通用卡片和胶囊方案则靠「彩色玻璃底片 + 网络 + 排版开关」对齐网页稿。
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
    param([double]$Blur, [double]$Depth, [double]$Opacity, [double]$Direction = 270)
    $effect = New-Object System.Windows.Media.Effects.DropShadowEffect
    $effect.BlurRadius = $Blur
    $effect.ShadowDepth = $Depth
    $effect.Direction = $Direction
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

# D6 半谷的 104° 斜切双色：用线性渐变做硬分界，比例跟着当天峰谷时长走
function New-SplitBrush {
    param([double]$W, [double]$H, [double]$Ratio)
    if ($W -le 1) { $W = 300.0 }
    if ($H -le 1) { $H = 170.0 }
    if ($Ratio -lt 0.02) { $Ratio = 0.02 }
    if ($Ratio -gt 0.98) { $Ratio = 0.98 }

    $angle = 104.0 * [Math]::PI / 180.0
    $dx = [Math]::Sin($angle)
    $dy = -[Math]::Cos($angle)
    $length = [Math]::Abs($W * $dx) + [Math]::Abs($H * $dy)
    if ($length -le 1) { $length = 1.0 }
    $offsetX = ($dx * $length / 2.0) / $W
    $offsetY = ($dy * $length / 2.0) / $H

    $brush = New-Object System.Windows.Media.LinearGradientBrush
    $brush.StartPoint = New-Object System.Windows.Point -ArgumentList (0.5 - $offsetX), (0.5 - $offsetY)
    $brush.EndPoint = New-Object System.Windows.Point -ArgumentList (0.5 + $offsetX), (0.5 + $offsetY)
    $red = [System.Windows.Media.ColorConverter]::ConvertFromString('#E85D3D')
    $green = [System.Windows.Media.ColorConverter]::ConvertFromString('#2FB89A')
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $red, 0.0))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $red, $Ratio))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $green, $Ratio))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $green, 1.0))
    return $brush
}

# 状态图标：高峰是两座峰，谷时是两个谷（D3 / D6 网页稿用的小折线）
function Get-StateIconGeometry {
    param([bool]$IsPeak)
    $data = 'M1,10 L4.2,3 L7,10 M6,10 L8.6,5 L11,10'
    if (-not $IsPeak) { $data = 'M1,3 L4.2,9 L7,3 M6,3 L8.6,7.5 L11,3' }
    return [System.Windows.Media.Geometry]::Parse($data)
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

# 把网页稿的彩色玻璃底片画进卡片：底色 + 光斑 + 状态光 + 白玻璃层 + 细网格
function Add-DecorArt {
    param($Layer, [double]$W, [double]$H, $Spec, $Colors)
    if ([string]::IsNullOrWhiteSpace([string]$Spec.Art)) { return }
    $style = $script:ArtStyles[[string]$Spec.Art]
    if ($null -eq $style) { return }

    # 底：斜向双色渐变
    $baseRect = New-Object System.Windows.Shapes.Rectangle
    $baseRect.Width = $W
    $baseRect.Height = $H
    $baseBrush = New-Object System.Windows.Media.LinearGradientBrush
    $baseBrush.StartPoint = New-Object System.Windows.Point -ArgumentList 0, 0
    $baseBrush.EndPoint = New-Object System.Windows.Point -ArgumentList 1, 1
    $c1 = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$style.Base1)
    $c2 = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$style.Base2)
    [void]$baseBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $c1, 0.0))
    [void]$baseBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $c2, 1.0))
    $baseRect.Fill = $baseBrush
    [void]$Layer.Children.Add($baseRect)

    # 彩色光斑：径向渐变从中心色淡出到透明
    foreach ($blob in @($style.Blobs)) {
        $diam = [Math]::Sqrt($W * $H) * [double]$blob.R
        if ($diam -lt 4) { continue }
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$blob.C)
        $alpha = [int]$blob.A
        $ellipse = New-Object System.Windows.Shapes.Ellipse
        $ellipse.Width = $diam
        $ellipse.Height = $diam
        $brush = New-Object System.Windows.Media.RadialGradientBrush
        $brush.Center = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
        $brush.GradientOrigin = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
        $brush.RadiusX = 0.5
        $brush.RadiusY = 0.5
        [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb($alpha, $color.R, $color.G, $color.B)), 0.0))
        [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb([int]($alpha * 0.55), $color.R, $color.G, $color.B)), 0.55))
        [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0, $color.R, $color.G, $color.B)), 1.0))
        $ellipse.Fill = $brush
        [System.Windows.Controls.Canvas]::SetLeft($ellipse, (([double]$blob.X * $W) - $diam / 2.0))
        [System.Windows.Controls.Canvas]::SetTop($ellipse, (([double]$blob.Y * $H) - $diam / 2.0))
        [void]$Layer.Children.Add($ellipse)
    }

    # 状态光：右下角一圈状态色微光，对应网页稿的 --soft
    if ([bool]$style.Glow) {
        $accent = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$Colors.Accent)
        $glowDiam = [Math]::Sqrt($W * $H) * 1.15
        $glow = New-Object System.Windows.Shapes.Ellipse
        $glow.Width = $glowDiam
        $glow.Height = $glowDiam
        $glowBrush = New-Object System.Windows.Media.RadialGradientBrush
        $glowBrush.Center = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
        $glowBrush.GradientOrigin = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
        $glowBrush.RadiusX = 0.5
        $glowBrush.RadiusY = 0.5
        [void]$glowBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(55, $accent.R, $accent.G, $accent.B)), 0.0))
        [void]$glowBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0, $accent.R, $accent.G, $accent.B)), 1.0))
        $glow.Fill = $glowBrush
        [System.Windows.Controls.Canvas]::SetLeft($glow, ($W * 0.92 - $glowDiam / 2.0))
        [System.Windows.Controls.Canvas]::SetTop($glow, ($H * 1.06 - $glowDiam / 2.0))
        [void]$Layer.Children.Add($glow)
    }

    # 白玻璃层：左上亮、中心薄、右下再亮一点
    $glass = New-Object System.Windows.Shapes.Rectangle
    $glass.Width = $W
    $glass.Height = $H
    $glassBrush = New-Object System.Windows.Media.LinearGradientBrush
    $glassBrush.StartPoint = New-Object System.Windows.Point -ArgumentList 0, 0
    $glassBrush.EndPoint = New-Object System.Windows.Point -ArgumentList 1, 1
    [void]$glassBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb([int]$style.Glass, 255, 255, 255)), 0.0))
    [void]$glassBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb([int]$style.GlassMid, 255, 255, 255)), 0.45))
    [void]$glassBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb([int]$style.Glass2, 255, 255, 255)), 1.0))
    $glass.Fill = $glassBrush
    [void]$Layer.Children.Add($glass)

    # 细网格：B 组 / C 组 / D1 的仪器网格
    $spacing = [double]$style.Grid
    if ($spacing -gt 1) {
        $gridColor = '#0BFFFFFF'
        $x = 0.0
        while ($x -lt $W) {
            $line = New-LineShape -X1 $x -Y1 0 -X2 $x -Y2 $H -Color $gridColor -Thickness 0.7
            [void]$Layer.Children.Add($line)
            $x += $spacing
        }
        $y = 0.0
        while ($y -lt $H) {
            $line = New-LineShape -X1 0 -Y1 $y -X2 $W -Y2 $y -Color $gridColor -Thickness 0.7
            [void]$Layer.Children.Add($line)
            $y += $spacing
        }
    }
}

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
    $padX = 15.0
    # 波形区夹在日期行和底部倒计时之间（D1 的卡片布局给这里留了一段空档）
    $top = $H * 0.5
    $bottom = $H - 34.0
    try {
        if ($null -ne $script:DateBox) {
            $dateBox = Get-ElementBox -Element $script:DateBox -FallbackW ($W - 30) -FallbackH 16
            $top = [double]$dateBox[1] + [double]$dateBox[3] + 8.0
        }
        if ($null -ne $script:FootGrid) {
            $footBox = Get-ElementBox -Element $script:FootGrid -FallbackW ($W - 30) -FallbackH 18
            $bottom = [double]$footBox[1] - 6.0
        }
    } catch { }
    if (($bottom - $top) -lt 28.0) { $bottom = $top + 28.0 }
    $baseY = ($top + $bottom) / 2.0
    $amplitude = ($bottom - $top) / 2.0 - 1.0
    if ($amplitude -lt 8.0) { $amplitude = 8.0 }

    $steps = 160
    $points = New-Object System.Windows.Media.PointCollection
    for ($i = 0; $i -le $steps; $i++) {
        $fraction = $i / [double]$steps
        $rate = Get-DayRate -Fraction $fraction -Windows $Status.PeakWindows -Soft 0.045
        $x = $padX + $fraction * ($W - $padX * 2)
        $y = $baseY - ($rate - 0.5) * 2.0 * $amplitude
        [void]$points.Add((New-Object System.Windows.Point -ArgumentList $x, $y))
    }

    # 曲线下方的暗色填充
    $fillFigure = New-Object System.Windows.Media.PathFigure
    $fillFigure.IsClosed = $true
    $fillFigure.StartPoint = $points[0]
    for ($i = 1; $i -lt $points.Count; $i++) {
        [void]$fillFigure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList $points[$i], $true))
    }
    [void]$fillFigure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList (New-Object System.Windows.Point -ArgumentList ($W - $padX), ($bottom + 2)), $true))
    [void]$fillFigure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList (New-Object System.Windows.Point -ArgumentList $padX, ($bottom + 2)), $true))
    $fillGeometry = New-Object System.Windows.Media.PathGeometry
    [void]$fillGeometry.Figures.Add($fillFigure)
    $fill = New-Object System.Windows.Shapes.Path
    $fill.Data = $fillGeometry
    $fill.Fill = New-BrushSafe ([string]$Colors.Accent) 0.10
    [void]$Layer.Children.Add($fill)

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
    $path.Stroke = New-BrushSafe ([string]$Colors.Accent) 0.85
    $path.StrokeThickness = 1.6
    $path.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
    [void]$Layer.Children.Add($path)

    # 当前时刻：白色圆点 + 向下延伸的竖虚线
    $nowX = $padX + [double]$Status.DayFraction * ($W - $padX * 2)
    $nowRate = Get-DayRate -Fraction ([double]$Status.DayFraction) -Windows $Status.PeakWindows -Soft 0.045
    $nowY = $baseY - ($nowRate - 0.5) * 2.0 * $amplitude
    $nowLine = New-LineShape -X1 $nowX -Y1 ($nowY + 4) -X2 $nowX -Y2 ($bottom + 2) -Color '#55FFFFFF' -Thickness 1
    $nowLine.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection
    [void]$nowLine.StrokeDashArray.Add(2.0)
    [void]$nowLine.StrokeDashArray.Add(2.0)
    [void]$Layer.Children.Add($nowLine)

    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 6; $dot.Height = 6
    $dot.Fill = New-BrushSafe '#FFFFFF'
    $dot.Opacity = 0.95
    [System.Windows.Controls.Canvas]::SetLeft($dot, ($nowX - 3))
    [System.Windows.Controls.Canvas]::SetTop($dot, ($nowY - 3))
    [void]$Layer.Children.Add($dot)

    $script:DecorRefs['WaveBaseY'] = $baseY
    $script:DecorRefs['WaveAmplitude'] = $amplitude
    $script:DecorRefs['WaveDot'] = $dot
    $script:DecorRefs['WaveNowLine'] = $nowLine
    $script:DecorRefs['WaveBottomY'] = $bottom
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
    param($Layer, [double]$W, [double]$H, $Colors, $Status, $Spec)
    $padX = 15.0
    $span = $W - $padX * 2
    $baseY = $H - 14.0
    # 卡片布局的刻度尺坐在底部倒计时上方；胶囊布局（C3）则贴底
    try {
        if ($null -ne $script:FootGrid) {
            $footBox = Get-ElementBox -Element $script:FootGrid -FallbackW $span -FallbackH 18
            $baseY = [double]$footBox[1] - 8.0
        }
    } catch { }

    $tickWeak = '#40FFFFFF'
    $tickStrong = '#8AFFFFFF'
    $marker = '#F8FAFC'
    if ([bool]$Spec.TickDark) {
        $tickWeak = '#331C1917'
        $tickStrong = '#661C1917'
        $marker = '#0B1420'
    }

    $baseline = New-LineShape -X1 $padX -Y1 $baseY -X2 ($padX + $span) -Y2 $baseY -Color $tickWeak -Thickness 1
    [void]$Layer.Children.Add($baseline)

    $bandColor = [string]$Colors.Accent
    if ($Colors.ContainsKey('Band')) { $bandColor = [string]$Colors.Band }
    foreach ($window in $Status.PeakWindows) {
        $startX = $padX + [double]$window.Start * $span
        $endX = $padX + [double]$window.End * $span
        $band = New-RectShape -X $startX -Y ($baseY - 6) -W ($endX - $startX) -H 6 -Color $bandColor
        $band.Opacity = 0.8
        [void]$Layer.Children.Add($band)
    }
    for ($hour = 0; $hour -le 24; $hour++) {
        $x = $padX + $hour / 24.0 * $span
        $length = 4.0
        $opacity = $tickWeak
        if (($hour % 6) -eq 0) { $length = 8.0; $opacity = $tickStrong }
        $line = New-LineShape -X1 $x -Y1 ($baseY - $length) -X2 $x -Y2 $baseY -Color $opacity -Thickness 1
        [void]$Layer.Children.Add($line)
    }

    # 当前时刻：竖线 + 顶端小圆点
    $nowX = $padX + [double]$Status.DayFraction * $span
    $stem = New-LineShape -X1 $nowX -Y1 ($baseY - 13) -X2 $nowX -Y2 ($baseY + 2) -Color $marker -Thickness 2
    [void]$Layer.Children.Add($stem)
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 5; $dot.Height = 5
    $dot.Fill = New-BrushSafe $marker
    [System.Windows.Controls.Canvas]::SetLeft($dot, ($nowX - 2.5))
    [System.Windows.Controls.Canvas]::SetTop($dot, ($baseY - 15))
    [void]$Layer.Children.Add($dot)
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
    # 装饰层跟着卡片圆角裁一圈，彩色底片和流光不会盖住卡片外的透明区域
    $clipRadius = [double]$Spec.Radius
    if ($clipRadius -lt 0) { $clipRadius = 0 }
    try {
        $clipRect = New-Object System.Windows.Rect -ArgumentList 0, 0, $w, $h
        $clipGeo = New-Object System.Windows.Media.RectangleGeometry -ArgumentList $clipRect, $clipRadius, $clipRadius
        $canvas.Clip = $clipGeo
    } catch { }
    [void]$hostLayer.Children.Add($canvas)

    # 玻璃方案的彩色底片先画，后面的装饰和内容都压在上面
    if (-not [string]::IsNullOrWhiteSpace([string]$Spec.Art)) {
        Add-DecorArt -Layer $canvas -W $w -H $h -Spec $Spec -Colors $Colors
    }

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
            'ticks'      { Add-DecorTicks -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status -Spec $Spec }
            'split'      { Add-DecorSplit -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'plate'      { Add-DecorPlate -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'lcd'        { Add-DecorLcd -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'scanlines'  { Add-DecorScanlines -Layer $canvas -W $w -H $h }
            'orb'        { Add-DecorOrb -Layer $canvas -W $w -H $h -Colors $Colors }
            # ---- SchemesPro.ps1 里的专属装饰 ----
            'scope'      { Add-DecorScope -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'kline'      { Add-DecorKline -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status }
            'bannerpulse' { Add-DecorBannerPulse -Layer $canvas -W $w -H $h -Colors $Colors -Spec $Spec -Status $Status }
            'orbitglow'  { Add-DecorOrbitRing -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status -Style 'glow' }
            'quartzring' { Add-DecorOrbitRing -Layer $canvas -W $w -H $h -Colors $Colors -Status $Status -Style 'quartz' }
            'tape'       { }
            'c2header'   { Add-DecorPaperHeader -Layer $canvas -W $w -H $h -Colors $Colors }
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
        $rate = Get-DayRate -Fraction $fraction -Windows $windows -Soft 0.045
        $y = $baseY - ($rate - 0.5) * 2.0 * $amplitude
        [System.Windows.Controls.Canvas]::SetLeft($dot, ($x - 3.5))
        [System.Windows.Controls.Canvas]::SetTop($dot, ($y - 3.5))
        $nowLine = $script:DecorRefs['WaveNowLine']
        if ($null -ne $nowLine) {
            $nowLine.X1 = $x
            $nowLine.X2 = $x
            $nowLine.Y1 = $y + 4
            $nowLine.Y2 = [double]$script:DecorRefs['WaveBottomY'] + 2
        }
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

    # HUD 顶部状态色横线：E2 保留，E2B 关闭
    if ($null -ne $script:HudTopBar) {
        $script:HudTopBar.Visibility = [System.Windows.Visibility]::Visible
        if (-not [bool]$Spec.HudTopBar) {
            $script:HudTopBar.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }

    $shadow = $Spec.Shadow
    $direction = 270.0
    if ($shadow.ContainsKey('Direction')) { $direction = [double]$shadow.Direction }
    $effect = New-CardShadow -Blur ([double]$shadow.Blur) -Depth ([double]$shadow.Depth) -Opacity ([double]$shadow.Opacity) -Direction $direction
    try { $effect.Color = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$shadow.Color) } catch { }
    $script:Card.Effect = $effect

    $script:Body.Margin = ConvertTo-Thickness ([string]$Spec.BodyPad)
    $script:ClockText.FontFamily = Resolve-FontFamily ([string]$Spec.ClockFont)
    $script:ClockText.FontSize = [double]$Spec.ClockSize
    $clockWeight = [System.Windows.FontWeights]::Bold
    switch ([string]$Spec.ClockWeight) {
        'Light'    { $clockWeight = [System.Windows.FontWeights]::Light }
        'Normal'   { $clockWeight = [System.Windows.FontWeights]::Normal }
        'Medium'   { $clockWeight = [System.Windows.FontWeights]::Medium }
        'SemiBold' { $clockWeight = [System.Windows.FontWeights]::SemiBold }
        'Black'    { $clockWeight = [System.Windows.FontWeights]::Black }
    }
    if (-not $isCustom) {
        $script:ClockText.FontWeight = $clockWeight
    }
    if (-not $isCustom) {
        # 专属模板的字号写在自己的 XAML 里（每个方案的信息密度差很多），
        # 通用补丁表里的 StatusSize / CountdownSize 不往它们身上套。
        $script:StatusText.FontSize = [double]$Spec.StatusSize
        $script:DateText.FontSize = [double]$Spec.DateFontSize
        $script:WeekText.FontSize = [double]$Spec.WeekFontSize
        $script:CountdownText.FontSize = [double]$Spec.CountdownSize
    }

    # ---- 网页稿的通用排版开关 ----
    # 时钟后面的「:24」：网页稿里是小号灰字，只有仪表类方案才全同号
    if ($null -ne $script:ClockSec) {
        $script:ClockSec.FontFamily = $script:ClockText.FontFamily
        if ([bool]$Spec.ClockSecSame) {
            # 整串同号：秒数和时钟一样大、一样粗、贴着基线
            $script:ClockSec.FontSize = [double]$Spec.ClockSize
            if (-not $isCustom) { $script:ClockSec.FontWeight = $clockWeight }
            $script:ClockSec.Margin = New-Object System.Windows.Thickness -ArgumentList 0
            $script:ClockSec.VerticalAlignment = [System.Windows.VerticalAlignment]::Bottom
        } else {
            $script:ClockSec.FontSize = [double]$Spec.ClockSecSize
            if (-not $isCustom) {
                $script:ClockSec.FontWeight = [System.Windows.FontWeights]::Normal
                $script:ClockSec.Margin = New-Object System.Windows.Thickness -ArgumentList 1, 0, 0, 6
            }
        }
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
        $script:RateBadge.Padding = ConvertTo-Thickness ([string]$Spec.RatePad)
        $script:RateBadge.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList ([double]$Spec.RateRadius)
    }
    # 状态：药丸底（A1 / A5 那种）还是裸排
    if (($null -ne $script:StatusPill) -and (-not $isCustom)) {
        if ([bool]$Spec.StatusPillStyle) {
            $script:StatusPill.Padding = ConvertTo-Thickness ([string]$Spec.PillPad)
            $script:StatusPill.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList ([double]$Spec.PillRadius)
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
            $script:WeekText.Margin = New-Object System.Windows.Thickness -ArgumentList 6, 0, 0, 0
            $script:DateText.Margin = New-Object System.Windows.Thickness -ArgumentList 0
            $script:DateText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
            $script:WeekText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
        } else {
            [System.Windows.Controls.Grid]::SetRow($script:DateBox, 0)
            [System.Windows.Controls.Grid]::SetColumn($script:DateBox, 1)
            [System.Windows.Controls.Grid]::SetColumnSpan($script:DateBox, 1)
            $script:DateBox.Orientation = [System.Windows.Controls.Orientation]::Vertical
            $script:DateBox.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
            $script:DateBox.Margin = New-Object System.Windows.Thickness -ArgumentList 12, 0, 0, 0
            $script:DateText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
            $script:WeekText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
            $script:DateText.Margin = New-Object System.Windows.Thickness -ArgumentList 0
            $script:WeekText.Margin = New-Object System.Windows.Thickness -ArgumentList 0, 3, 0, 0
            if ([bool]$Spec.WeekFirst) {
                $script:DateText.Margin = New-Object System.Windows.Thickness -ArgumentList 0, 3, 0, 0
                $script:WeekText.Margin = New-Object System.Windows.Thickness -ArgumentList 0
            }
        }
        # 默认界面是「周几在上、日期在下」，A1 / A5 是「日期在上、周几在下」
        try {
            $first = $script:DateBox.Children[0]
            if ([bool]$Spec.WeekFirst -and ($first -ne $script:WeekText)) {
                $script:DateBox.Children.Clear()
                [void]$script:DateBox.Children.Add($script:WeekText)
                [void]$script:DateBox.Children.Add($script:DateText)
            } elseif ((-not [bool]$Spec.WeekFirst) -and ($first -ne $script:DateText)) {
                $script:DateBox.Children.Clear()
                [void]$script:DateBox.Children.Add($script:DateText)
                [void]$script:DateBox.Children.Add($script:WeekText)
            }
        } catch { }
    }

    # 卡片布局里日期列被大号时钟挤在右边，宽度只够放下「10月28日」这一行；
    # 胶囊 / 表盘布局横向有余量。节日名放哪儿由这个标记决定（见 Update-Widget）。
    $script:CompactDate = ([string]$Spec.Layout -eq 'card')

    # 状态点：胶囊布局要放大成光球，由 orb 装饰接管
    $script:StatusDot.Width = [double]$Spec.StatusDotSize
    $script:StatusDot.Height = [double]$Spec.StatusDotSize
    if (($null -ne $script:OrbHost) -and ([double]$Spec.OrbSize -gt 0)) {
        $script:OrbHost.Width = [double]$Spec.OrbSize
        $script:OrbHost.Height = [double]$Spec.OrbSize
        $glow = $script:StatusDot.Effect
        if ($null -ne $glow) {
            if ([double]$Spec.OrbSize -ge 30) { $glow.BlurRadius = 34 } else { $glow.BlurRadius = 16 }
        }
    }
    if ([bool]$Spec.HideStatus) {
        $script:StatusDot.Visibility = [System.Windows.Visibility]::Collapsed
        if ($null -ne $script:StatusSquare) { $script:StatusSquare.Visibility = [System.Windows.Visibility]::Collapsed }
        $script:StatusText.Visibility = [System.Windows.Visibility]::Collapsed
    } else {
        $script:StatusText.Visibility = [System.Windows.Visibility]::Visible
        if (($null -ne $script:StatusSquare) -and [bool]$Spec.StatusSquare) {
            # C6 / E3 那种实心方块
            $script:StatusSquare.Visibility = [System.Windows.Visibility]::Visible
            $size = 9.0
            if ([string]$Spec.Layout -eq 'solid') { $size = 7.0 }
            $script:StatusSquare.Width = $size
            $script:StatusSquare.Height = $size
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
        $script:AccentBar.Effect = $null
        $barColor = '#FFB020'
        if ($Spec.Text.ContainsKey('AccentBar')) { $barColor = [string]$Spec.Text['AccentBar'] }
        $script:AccentBar.Fill = ConvertTo-Brush $barColor
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
    # E2B 的窗口标签（开始/胶囊/结束）需要跟状态色联动，只在 HUD 布局上处理
    if ([string]$Spec.Layout -eq 'hud') {
        try { Set-HudLabelStyle -Spec $Spec -Colors $colors -Status $Status } catch { }
    }
    # 专属模板的价格 / 状态块长什么样由各自 XAML 定，这里只换文字色
    $isCustom = -not (@('card', 'capsule', 'dial') -contains [string]$Spec.Layout)

    $script:StatusText.Foreground = ConvertTo-Brush ([string]$colors.Status)
    $script:ClockText.Foreground = ConvertTo-Brush ([string]$colors.Clock)
    $script:WeekText.Foreground = ConvertTo-Brush ([string]$colors.Week)
    $script:DateText.Foreground = ConvertTo-Brush ([string]$colors.Date)
    if ($null -ne $script:TzText) { $script:TzText.Foreground = ConvertTo-Brush ([string]$colors.Date) }
    # 网页稿里倒计时的标签和数值经常是两种灰（K 线 / 半谷 / 色块），
    # 配色状态里给了 CdLabel / CdValue 就优先用它们。
    $cdLabelColor = [string]$colors.AccentSoft
    if ($colors.ContainsKey('CdLabel')) { $cdLabelColor = [string]$colors.CdLabel }
    $cdValueColor = [string]$colors.AccentSoft
    if ($colors.ContainsKey('CdValue')) { $cdValueColor = [string]$colors.CdValue }
    $script:CountdownText.Foreground = ConvertTo-Brush $cdLabelColor
    $script:HintText.Foreground = ConvertTo-Brush ([string]$colors.Hint)

    # 可选元素（只有卡片布局有）
    if ($null -ne $script:ClockSec) {
        $secColor = ''
        if ([bool]$Spec.ClockSecSame) {
            $secColor = [string]$colors.Clock
        } elseif ($colors.ContainsKey('ClockSec')) {
            $secColor = [string]$colors.ClockSec
        }
        if ([string]::IsNullOrWhiteSpace($secColor)) { $secColor = [string]$colors.Week }
        $script:ClockSec.Foreground = ConvertTo-Brush $secColor
    }
    if ($null -ne $script:CountdownValue) {
        $script:CountdownValue.Foreground = ConvertTo-Brush $cdValueColor
    }
    # 有的方案（B1 / B5 / C1 / C2 / D1）倒计时是「距空闲 01:29:36」连在一起，
    # 有的（A1 / A5）是左右分列。切换方案时把同一个 TextBlock 在两个容器之间挪。
    if (($null -ne $script:FootGrid) -and ($null -ne $script:FootStack) -and ($null -ne $script:CountdownValue)) {
        if ([bool]$Spec.InlineCountdown) {
            $parent = $script:CountdownValue.Parent
            if ($parent -ne $script:FootStack) {
                if (($null -ne $parent) -and ($parent -is [System.Windows.Controls.Panel])) {
                    [void]$parent.Children.Remove($script:CountdownValue)
                }
                $script:FootStack.Children.Insert(1, $script:CountdownValue)
            }
            $script:CountdownValue.Margin = New-Object System.Windows.Thickness -ArgumentList 6, 0, 0, 0
            $script:CountdownValue.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
            [System.Windows.Controls.Grid]::SetColumn($script:CountdownValue, 0)
        } else {
            $parent = $script:CountdownValue.Parent
            if ($parent -ne $script:FootGrid) {
                if (($null -ne $parent) -and ($parent -is [System.Windows.Controls.Panel])) {
                    [void]$parent.Children.Remove($script:CountdownValue)
                }
                [void]$script:FootGrid.Children.Add($script:CountdownValue)
            }
            $script:CountdownValue.Margin = New-Object System.Windows.Thickness -ArgumentList 10, 0, 0, 0
            $script:CountdownValue.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
            [System.Windows.Controls.Grid]::SetColumn($script:CountdownValue, 1)
        }
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
            $pillBg = [string]$colors.BadgeBg
            if ($Spec.Text.ContainsKey('PillBg')) { $pillBg = [string]$Spec.Text['PillBg'] }
            $script:StatusPill.Background = ConvertTo-Brush $pillBg
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
        if ($colors.ContainsKey('CardBorder')) {
            $script:Card.BorderBrush = ConvertTo-Brush ([string]$colors.CardBorder)
        }
    }

    $script:AccentBar.Fill = ConvertTo-Brush ([string]$colors.Accent)
    $script:PeakSegment1.Fill = ConvertTo-Brush ([string]$colors.Segment)
    $script:PeakSegment2.Fill = ConvertTo-Brush ([string]$colors.Segment)
    $script:TimelineTrack.Fill = ConvertTo-Brush ([string]$colors.Track)
    $script:TimeMarker.Fill = ConvertTo-Brush ([string]$colors.Marker)
    # 游标（刻度线）宽度与辉光：网页稿里它是压在高峰段上的一条亮线，太细会被玻璃底吃掉
    $markerWidth = 2.0
    if ([double]$Spec.MarkerWidth -gt 0) { $markerWidth = [double]$Spec.MarkerWidth }
    $script:TimeMarker.Width = $markerWidth
    $markerGlow = $null
    if ([bool]$Spec.MarkerGlow) {
        $markerGlow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $markerGlow.BlurRadius = 8
        $markerGlow.ShadowDepth = 0
        $markerGlow.Opacity = 0.9
        $markerGlow.Color = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$colors.Marker)
    }
    $script:TimeMarker.Effect = $markerGlow

    if ($isCustom) {
        # 专属模板：价格 / 徽章形状由模板自己定，这里只换文字和描边色
        $rateColor = [string]$colors.Accent
        if ($colors.ContainsKey('Rate')) { $rateColor = [string]$colors.Rate }
        elseif ([bool]$Spec.PlainRate) { $rateColor = [string]$colors.AccentSoft }
        $script:RateText.Foreground = ConvertTo-Brush $rateColor
        if (($null -ne $script:RateBadge) -and ([string]$Spec.Layout -eq 'hud')) {
            # 网页稿的 RATE 标签是一圈状态色描边
            $script:RateBadge.BorderBrush = ConvertTo-Brush $rateColor
        }
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

    # 玻璃方案的价签有一圈细白边（A1 / A5）
    if (($null -ne $script:RateBadge) -and (-not $isCustom) -and $Spec.Text.ContainsKey('RateBorder')) {
        $script:RateBadge.BorderBrush = ConvertTo-Brush ([string]$Spec.Text['RateBorder'])
        $script:RateBadge.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 1
    }

    # ---- 专属模板里需要跟状态走的部件 ----
    if ([string]$Spec.Layout -eq 'lcd') {
        # E5：整屏底色和屏框都跟状态走（暖棕 / 墨绿）
        if ($colors.ContainsKey('Surface')) { $script:Card.Background = ConvertTo-Brush ([string]$colors.Surface) }
        if ($colors.ContainsKey('Border')) { $script:Card.BorderBrush = ConvertTo-Brush ([string]$colors.Border) }
        if ($null -ne $script:StatusPill) {
            $script:StatusPill.BorderBrush = ConvertTo-Brush ([string]$colors.Accent)
        }
    }
    if ([string]$Spec.Layout -eq 'tape') {
        # C3：琥珀芯片 + 深色字，跟 C1 一样是实底
        if ($null -ne $script:StatusPill) {
            $script:StatusPill.Background = ConvertTo-Brush ([string]$colors.Accent)
            $script:StatusPill.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 0
        }
        if ($null -ne $script:StatusText) { $script:StatusText.Foreground = ConvertTo-Brush '#0B0F14' }
        if ($null -ne $script:StatusDot) { $script:StatusDot.Fill = ConvertTo-Brush '#0B0F14' }
    }
    if (([string]$Spec.Layout -eq 'banner') -and ([double]$Spec.OrbSize -ge 30) -and ($null -ne $script:StatusDot)) {
        # B3 的大光球：中心亮、边缘深，像一颗被灯照亮的玻璃珠
        $softColor = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$colors.AccentSoft)
        $accentColor = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$colors.Accent)
        $orbBrush = New-Object System.Windows.Media.RadialGradientBrush
        $orbBrush.Center = New-Object System.Windows.Point -ArgumentList 0.38, 0.32
        $orbBrush.GradientOrigin = New-Object System.Windows.Point -ArgumentList 0.38, 0.32
        $orbBrush.RadiusX = 0.65
        $orbBrush.RadiusY = 0.65
        [void]$orbBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $softColor, 0.0))
        [void]$orbBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $accentColor, 0.75))
        $script:StatusDot.Fill = $orbBrush
    }
    if ([string]$Spec.Layout -eq 'half') {
        # D6：104° 斜切双色，峰 64% / 空闲 36% / 周末全天只留 12% 的红
        $ratio = 0.64
        if (-not $Status.IsPeakDay) { $ratio = 0.12 }
        elseif (-not $Status.IsPeak) { $ratio = 0.36 }
        $script:Card.Background = New-SplitBrush -W ([double]$script:Card.ActualWidth) -H ([double]$script:Card.ActualHeight) -Ratio $ratio
    }
    if ($null -ne $script:StatusPill) {
        # C4 的实底 chip / E2 的描边框 / E3 的实色徽章都跟着状态色
        if ([string]$Spec.Layout -eq 'gauge') {
            $chip = [string]$colors.Accent
            if ($colors.ContainsKey('Chip')) { $chip = [string]$colors.Chip }
            $script:StatusPill.Background = ConvertTo-Brush $chip
            $ink = [string]$colors.Status
            if ($colors.ContainsKey('ChipInk')) { $ink = [string]$colors.ChipInk }
            $script:StatusText.Foreground = ConvertTo-Brush $ink
            if ($null -ne $script:ChipDot) { $script:ChipDot.Fill = ConvertTo-Brush $ink }
        } elseif ([string]$Spec.Layout -eq 'hud') {
            $script:StatusPill.Background = ConvertTo-Brush '#00000000'
        } elseif ([string]$Spec.Layout -eq 'brutal') {
            $script:StatusPill.Background = ConvertTo-Brush ([string]$colors.Accent)
        } elseif ([string]$Spec.Layout -eq 'scope') {
            $script:StatusPill.Background = ConvertTo-Brush ([string]$colors.BadgeBg)
            $border = [string]$colors.Accent
            if ($colors.ContainsKey('BadgeBorder')) { $border = [string]$colors.BadgeBorder }
            $script:StatusPill.BorderBrush = ConvertTo-Brush $border
        }
    }
    if ($null -ne $script:PlateBox) {
        # E4 左栏铭牌整块换成当前状态色
        $script:PlateBox.Background = ConvertTo-Brush ([string]$colors.Accent)
        if ($null -ne $script:PlateStatus) { $script:PlateStatus.Foreground = ConvertTo-Brush '#FFFFFF' }
        if ($null -ne $script:PlateStatusEn) { $script:PlateStatusEn.Foreground = ConvertTo-Brush '#D9FFFFFF' }
        if ($null -ne $script:PlateRate) { $script:PlateRate.Foreground = ConvertTo-Brush '#FFFFFF' }
        if ($null -ne $script:PlateDay) { $script:PlateDay.Foreground = ConvertTo-Brush '#BFFFFFFF' }
    }
    if ($null -ne $script:HudTopBar) {
        $script:HudTopBar.Fill = ConvertTo-Brush ([string]$colors.Accent)
    }
    if ([string]$Spec.Key -eq 'b5') {
        # B5 的左侧光柱是渐变 + 外发光，不是一根实线
        $accent = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$colors.Accent)
        $barBrush = New-Object System.Windows.Media.LinearGradientBrush
        $barBrush.StartPoint = New-Object System.Windows.Point -ArgumentList 0, 0
        $barBrush.EndPoint = New-Object System.Windows.Point -ArgumentList 0, 1
        [void]$barBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0, $accent.R, $accent.G, $accent.B)), 0.0))
        [void]$barBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(220, $accent.R, $accent.G, $accent.B)), 0.35))
        [void]$barBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(220, $accent.R, $accent.G, $accent.B)), 0.65))
        [void]$barBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0, $accent.R, $accent.G, $accent.B)), 1.0))
        $script:AccentBar.Width = 6
        $script:AccentBar.Fill = $barBrush
        try {
            $glow = New-Object System.Windows.Media.Effects.DropShadowEffect
            $glow.BlurRadius = 18
            $glow.ShadowDepth = 0
            $glow.Opacity = 0.65
            $glow.Color = $accent
            $script:AccentBar.Effect = $glow
        } catch { }
    }

    if ($null -ne $script:StatusIconPath) {
        $iconColor = [string]$colors.Accent
        if ($colors.ContainsKey('StatusIcon')) { $iconColor = [string]$colors.StatusIcon }
        $script:StatusIconPath.Stroke = ConvertTo-Brush $iconColor
        # K 线 / 半谷的小图标会跟着峰谷翻面；示波器峰时用趋势线、谷时用月牙
        if (@('candle', 'half') -contains [string]$Spec.Layout) {
            $script:StatusIconPath.Data = Get-StateIconGeometry -IsPeak ([bool]$Status.IsPeak)
        } elseif ([string]$Spec.Layout -eq 'scope') {
            if ([bool]$Status.IsPeak) {
                $script:StatusIconPath.Data = [System.Windows.Media.Geometry]::Parse('M1,11 L5.5,3.5 L9,8 L13,1.5 M9,1.5 L13,1.5 L13,5.5')
                $script:StatusIconPath.StrokeThickness = 2.0
            } else {
                $script:StatusIconPath.Data = [System.Windows.Media.Geometry]::Parse('M12.25,7.46 A5.25,5.25 0 1 1 6.54,1.75 A4.08,4.08 0 0 0 12.25,7.46 Z')
                $script:StatusIconPath.StrokeThickness = 1.6
            }
        }
    }
    if ($null -ne $script:StatusIcon) {
        # HUD / 示波器的文字图标跟着状态色（▲ 峰 / ■ 谷）
        $script:StatusIcon.Foreground = ConvertTo-Brush ([string]$colors.Accent)
        if (([string]$Spec.Layout -eq 'hud') -and (-not [bool]$Status.IsPeak)) {
            $script:StatusIcon.Text = '■'
        } elseif ([string]$Spec.Layout -eq 'hud') {
            $script:StatusIcon.Text = '▲'
        }
    }
    if ($null -ne $script:ScopeBox) {
        # F1 波形框：描边跟着状态（琥珀 / 翠绿 / 青蓝）；
        # 框内底色由装饰器先画，边框本身保持透明，别把波形盖住。
        $scopeBorder = [string]$colors.Accent
        if ($colors.ContainsKey('ScopeBorder')) { $scopeBorder = [string]$colors.ScopeBorder }
        $script:ScopeBox.BorderBrush = ConvertTo-Brush $scopeBorder
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
    $script:ChipDot = Find-LayoutElement 'ChipDot'
    $script:StatusIconPath = Find-LayoutElement 'StatusIconPath'
    $script:DateBox = Find-LayoutElement 'DateBox'
    $script:OrbHost = Find-LayoutElement 'OrbHost'
    $script:FootGrid = Find-LayoutElement 'FootGrid'
    $script:FootStack = Find-LayoutElement 'FootStack'
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
    $script:WinLeft = Find-LayoutElement 'WinLeft'
    $script:WinMid = Find-LayoutElement 'WinMid'
    $script:WinRight = Find-LayoutElement 'WinRight'
    $script:WinLeftTag = Find-LayoutElement 'WinLeftTag'
    $script:WinMidBox = Find-LayoutElement 'WinMidBox'
    $script:WinEndTag = Find-LayoutElement 'WinEndTag'
    $script:CdBox = Find-LayoutElement 'CdBox'
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

