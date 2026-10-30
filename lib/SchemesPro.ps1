#Requires -Version 5.1
<#
  lib/SchemesPro.ps1 —— 逐方案精修层（对齐 design/ 下的网页原稿）

  为什么单独一个文件
  ------------------
  Schemes.ps1 里的三套通用布局（card / capsule / dial）是「同一套骨架换皮」，
  能覆盖大部分方案，但网页原稿里有 14 个方案的**结构本身**就不一样：
  A3/B3 是左侧光球胶囊、A6/B4 是 24h 圆盘、C3 是横向刻度带、
  峰谷示波器有独立波形框、点阵液晶是屏槽 + 双虚线、瑞士分屏是左右两栏、
  新野兽派是黑框块、半谷是斜切双色、K 线是蜡烛区、色块是满版 + 刻度尺、
  HUD 是顶条 + 分段进度、圆表是内环仪表。

  这些用「换皮」做不出来，只能各给一套专属 XAML。本文件就是这 13 套模板
  + 它们各自的装饰器 + 专属文案填充。

  约定
  ----
  1. 每个模板都保留 Schemes.ps1 里那套必需元素名（StatusText / ClockText /
     DateText / WeekText / RateText / CountdownText / TimelineCanvas …），
     这样 Apply-SchemeSurface / Apply-SchemeState 不用为模板写分支。
  2. 模板专属元素一律用 Find-LayoutElement 软查找，缺了不报错。
  3. 专属文案在 Update-SchemeCustomText 里统一填，DeepSeekClock.ps1 只调一次。
#>

# ============================ 专属布局模板 ============================

# ---------- C3 刻度带：460×112 横向窄条，芯片 + 大钟 + 右侧倒计时 + 底部刻度 ----------
$script:LayoutTape = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="8" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#12141A" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#232C38" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#FFB020" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="16,12,16,12">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
      </Grid.RowDefinitions>
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Border x:Name="StatusPill" Background="#FFB020" BorderThickness="0" CornerRadius="4" Padding="8,3,8,3" HorizontalAlignment="Left">
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
              <Ellipse x:Name="StatusDot" Width="4" Height="4" Fill="#0B0F14" Margin="0,0,5,0" VerticalAlignment="Center" />
              <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#0B0F14" Visibility="Collapsed" />
              <TextBlock x:Name="StatusText" Text="高峰" FontSize="10.5" FontWeight="Bold" Foreground="#0B0F14" />
            </StackPanel>
          </Border>
          <Border x:Name="RateBadge" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0" Margin="10,0,0,0" VerticalAlignment="Center">
            <TextBlock x:Name="RateText" Text="1.0×" FontSize="16" FontWeight="Bold" Foreground="#FFB020" FontFamily="Consolas, Cascadia Mono" />
          </Border>
        </StackPanel>
        <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Center">
          <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="10" Foreground="#5A6272" HorizontalAlignment="Right" />
          <TextBlock x:Name="CountdownValue" Text="01:29:36" FontSize="12.5" FontWeight="SemiBold" Foreground="#E9ECF2" Margin="0,3,0,0" HorizontalAlignment="Right" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#4E5665" Visibility="Collapsed" />
        </StackPanel>
      </Grid>
      <Grid Grid.Row="1" Margin="0,4,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Bottom">
          <TextBlock x:Name="ClockText" Text="10:30" FontSize="38" FontWeight="Normal" Foreground="#E9ECF2" FontFamily="Consolas, Cascadia Mono" />
          <TextBlock x:Name="ClockSec" Text=":24" FontSize="38" FontWeight="Normal" Foreground="#E9ECF2" FontFamily="Consolas, Cascadia Mono" Margin="0" VerticalAlignment="Bottom" />
        </StackPanel>
        <StackPanel x:Name="DateBox" Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Bottom" HorizontalAlignment="Left" Margin="16,0,0,6">
          <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" Foreground="#8A93A4" />
          <TextBlock x:Name="WeekText" Text="周三" FontSize="11" Foreground="#8A93A4" Margin="6,0,0,0" />
        </StackPanel>
      </Grid>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#FFB020" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#FFB020" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- A6 24h 轨道玻璃：306 圆盘 + 轨道环 + 中心状态/时钟/倒计时/日期 ----------
$script:LayoutOrbitA6 = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="153" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#0C1224" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#38FFFFFF" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#F59E0B" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" VerticalAlignment="Center" HorizontalAlignment="Center">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Center">
        <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#F59E0B" VerticalAlignment="Center">
          <Ellipse.Effect><DropShadowEffect BlurRadius="12" ShadowDepth="0" Opacity="0.95" Color="#F59E0B" /></Ellipse.Effect>
        </Ellipse>
        <TextBlock x:Name="StatusText" Text="高峰时段" FontSize="12" FontWeight="SemiBold" Foreground="#F2F8FF" Margin="7,0,0,0" VerticalAlignment="Center" />
        <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#F59E0B" Visibility="Collapsed" />
      </StackPanel>
      <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,8,0,0" VerticalAlignment="Bottom">
        <TextBlock x:Name="ClockText" Text="10:30" FontSize="41" FontWeight="SemiBold" Foreground="#FFFFFF" />
        <TextBlock x:Name="ClockSec" Text=":24" FontSize="15" Foreground="#8AFFFFFF" Margin="2,0,0,3" VerticalAlignment="Bottom" />
      </StackPanel>
      <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,12,0,0">
        <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="10" Foreground="#A0FFFFFF" />
        <TextBlock x:Name="CountdownValue" Text="01:29:36" FontSize="11.5" FontWeight="SemiBold" Foreground="#E8EDF6" Margin="6,0,0,0" />
        <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#5B6B82" Visibility="Collapsed" />
      </StackPanel>
      <StackPanel x:Name="DateBox" Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,8,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="10" Foreground="#8AFFFFFF" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="10" Foreground="#8AFFFFFF" Margin="6,0,0,0" />
      </StackPanel>
      <Border x:Name="RateBadge" Background="#00000000" BorderThickness="0" Padding="0" Visibility="Collapsed">
        <TextBlock x:Name="RateText" Text="1.0×" FontSize="11" Foreground="#F59E0B" />
      </Border>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#F59E0B" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#F59E0B" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- B4 石英表盘：300 圆盘 + 细环 + 状态/大钟/倍率/日期/倒计时 ----------
$script:LayoutOrbitB4 = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="150" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#101A2E" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#38FFFFFF" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
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
        <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#F59E0B" VerticalAlignment="Center">
          <Ellipse.Effect><DropShadowEffect BlurRadius="12" ShadowDepth="0" Opacity="0.95" Color="#F59E0B" /></Ellipse.Effect>
        </Ellipse>
        <TextBlock x:Name="StatusText" Text="高峰时段" FontSize="13" FontWeight="SemiBold" Foreground="#F59E0B" Margin="7,0,0,0" VerticalAlignment="Center" />
        <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#F59E0B" Visibility="Collapsed" />
      </StackPanel>
      <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,0" VerticalAlignment="Bottom">
        <TextBlock x:Name="ClockText" Text="10:30" FontSize="40" FontWeight="Light" Foreground="#F8FAFC" />
        <TextBlock x:Name="ClockSec" Text=":24" FontSize="40" FontWeight="Light" Foreground="#F8FAFC" Margin="0" VerticalAlignment="Bottom" />
      </StackPanel>
      <Border x:Name="RateBadge" Grid.Row="2" Background="#00000000" BorderThickness="0" Padding="0" HorizontalAlignment="Center" Margin="0,4,0,0">
        <StackPanel Orientation="Horizontal">
          <TextBlock x:Name="RateText" Text="1.0" FontSize="28" FontWeight="Bold" Foreground="#F59E0B" />
          <TextBlock x:Name="RateTail" Text="×" FontSize="14" Foreground="#F59E0B" Opacity="0.65" VerticalAlignment="Bottom" Margin="1,0,0,4" />
        </StackPanel>
      </Border>
      <StackPanel x:Name="DateBox" Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,12,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" Foreground="#8B94A5" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="11" Foreground="#8B94A5" Margin="6,0,0,0" />
      </StackPanel>
      <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,6,0,0">
        <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="10" Foreground="#7C8AA5" />
        <TextBlock x:Name="CountdownValue" Text="01:29:36" FontSize="11.5" FontWeight="SemiBold" Foreground="#8B94A5" Margin="6,0,0,0" />
        <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#5B6B82" Visibility="Collapsed" />
      </StackPanel>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#F59E0B" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#F59E0B" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- A3 / B3 灵动胶囊：左侧光球 + 状态/价格 + 分隔线 + 大钟 + 右侧倒计时 ----------
# 对齐 design-options.html 方案 03 与 v2 B3：胶囊高 120 / 110，圆角 42；
# A3 用 10px 脉冲点，B3 用 54px 呼吸光球；B3 底部还有一条全天进度条。
$script:LayoutBanner = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="42" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#141A2E" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#38FFFFFF" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#F59E0B" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="28,0,28,0">
      <Grid.RowDefinitions>
        <RowDefinition Height="*" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <Grid Grid.Row="0" VerticalAlignment="Center">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
          <Grid x:Name="OrbHost" Width="54" Height="54" Margin="0,0,14,0" VerticalAlignment="Center">
            <Ellipse x:Name="StatusDot" Width="54" Height="54" Fill="#F59E0B" HorizontalAlignment="Center" VerticalAlignment="Center">
              <Ellipse.Effect><DropShadowEffect BlurRadius="18" ShadowDepth="0" Opacity="0.85" Color="#F59E0B" /></Ellipse.Effect>
            </Ellipse>
            <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#F59E0B" Visibility="Collapsed" />
          </Grid>
          <StackPanel VerticalAlignment="Center">
            <TextBlock x:Name="StatusText" Text="高峰时段" FontSize="15.5" FontWeight="SemiBold" Foreground="#FFFFFF" />
            <Border x:Name="RateBadge" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0" Margin="0,3,0,0" HorizontalAlignment="Left">
              <TextBlock x:Name="RateText" Text="1.0×" FontSize="11" FontWeight="SemiBold" Foreground="#FCD34D" />
            </Border>
          </StackPanel>
        </StackPanel>
        <Rectangle Grid.Column="1" Width="1" Height="46" Fill="#33FFFFFF" Margin="22,0,22,0" VerticalAlignment="Center" />
        <StackPanel Grid.Column="2" VerticalAlignment="Center">
          <StackPanel Orientation="Horizontal" VerticalAlignment="Bottom">
            <TextBlock x:Name="ClockText" Text="10:30" FontSize="34" FontWeight="SemiBold" Foreground="#FFFFFF" />
            <TextBlock x:Name="ClockSec" Text=":24" FontSize="13" Foreground="#8AFFFFFF" Margin="1,0,0,4" VerticalAlignment="Bottom" />
          </StackPanel>
          <StackPanel x:Name="DateBox" Orientation="Horizontal" Margin="0,4,0,0">
            <TextBlock x:Name="WeekText" Text="周三" FontSize="10.5" Foreground="#8AFFFFFF" />
            <TextBlock x:Name="DateText" Text="10月28日" FontSize="10.5" Foreground="#8AFFFFFF" Margin="8,0,0,0" />
          </StackPanel>
        </StackPanel>
        <StackPanel Grid.Column="3" HorizontalAlignment="Right" VerticalAlignment="Center">
          <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="10" Foreground="#7C8AA5" HorizontalAlignment="Right" />
          <TextBlock x:Name="CountdownValue" Text="01:29:36" FontSize="15.5" FontWeight="SemiBold" Foreground="#FFFFFF" Margin="0,4,0,0" HorizontalAlignment="Right" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#5B6B82" Visibility="Collapsed" />
        </StackPanel>
      </Grid>
      <Grid x:Name="TrackHost" Grid.Row="1" Height="8" Margin="0,0,0,10" Visibility="Collapsed">
        <Canvas x:Name="TimelineCanvas" Height="6" ClipToBounds="True" HorizontalAlignment="Stretch" VerticalAlignment="Center">
          <Rectangle x:Name="TimelineTrack" Canvas.Top="0" Height="6" RadiusX="3" RadiusY="3" Fill="#332A3A4D" />
          <Rectangle x:Name="PeakSegment1" Canvas.Top="0" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="PeakSegment2" Canvas.Top="0" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="TimeMarker" Canvas.Top="0" Width="2" Height="6" RadiusX="1" RadiusY="1" Fill="#F8FAFC" />
        </Canvas>
      </Grid>
    </Grid>
  </Grid>
</Border>
'@

# ---------- F1 峰谷示波器：药丸标题 + 独立波形框 + 大钟 + 倒计时条 ----------
# 对齐 code03.html：卡 280×202，内边距 14；波形框高 52，圆角 8，带状态色描边；
# 标题是带折线图标的药丸，价格「1.0× 标准」等宽小字；底部是半透明倒计时条。
$script:LayoutScope = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="14" Margin="12" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#111827" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#1F2937" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#F59E0B" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="14">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <Border x:Name="StatusPill" Background="#26F59E0B" BorderBrush="#4DF59E0B" BorderThickness="1" CornerRadius="6" Padding="8,3" HorizontalAlignment="Left">
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Path x:Name="StatusIconPath" Width="14" Height="14" Margin="0,0,6,0" VerticalAlignment="Center"
                  Stroke="#F59E0B" StrokeThickness="2" Stretch="None"
                  Data="M1,11 L5.5,3.5 L9,8 L13,1.5 M9,1.5 L13,1.5 L13,5.5" />
            <TextBlock x:Name="StatusText" Text="梁文峰时段" FontSize="12" FontWeight="Bold" Foreground="#FBBF24" />
          </StackPanel>
        </Border>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="1.0×" FontSize="11" FontWeight="Bold" Foreground="#F59E0B" FontFamily="Cascadia Mono, Consolas" VerticalAlignment="Center" />
          <TextBlock x:Name="RateTail" Text="标准" FontSize="11" Foreground="#F59E0B" Opacity="0.85" Margin="5,0,0,0" VerticalAlignment="Center" />
          <Border x:Name="RateBadge" Width="0" Height="0" Background="#00000000" BorderThickness="0" Visibility="Collapsed" />
          <Ellipse x:Name="StatusDot" Width="0" Height="0" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#F59E0B" Visibility="Collapsed" />
        </StackPanel>
      </Grid>
      <Border x:Name="ScopeBox" Grid.Row="1" Height="52" Margin="0,8,0,0" CornerRadius="8" BorderThickness="1"
              BorderBrush="#40F59E0B" Background="#00000000" />
      <Grid Grid.Row="2" Margin="0,10,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="ClockText" Text="10:30:24" FontSize="26" FontWeight="ExtraBold" Foreground="#F8FAFC" FontFamily="Cascadia Mono, Consolas" />
        <StackPanel x:Name="DateBox" Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="8,0,0,4">
          <TextBlock x:Name="DateIcon" Text="▦" FontSize="10" Foreground="#94A3B8" Margin="0,1,4,0" />
          <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" Foreground="#94A3B8" />
          <TextBlock x:Name="WeekText" Text="周三" FontSize="11" Foreground="#94A3B8" Margin="5,0,0,0" />
        </StackPanel>
      </Grid>
      <Border Grid.Row="4" Margin="0,6,0,0" CornerRadius="6" Background="#40000000" BorderBrush="#08FFFFFF" BorderThickness="1" Padding="8,6">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock x:Name="CdIcon" Text="◷" FontSize="10" Foreground="#64748B" Margin="0,0,5,0" />
            <TextBlock x:Name="CountdownText" Text="距入谷 (0.5×)" FontSize="11" Foreground="#64748B" />
            <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#475569" Margin="8,0,0,0" Visibility="Collapsed" />
          </StackPanel>
          <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="11" FontWeight="Bold" Foreground="#F59E0B" FontFamily="Cascadia Mono, Consolas" VerticalAlignment="Center" />
        </Grid>
      </Border>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#F59E0B" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#F59E0B" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- E5 点阵液晶：屏槽 + 状态戳 + 大号 LCD 数字 + 虚线倒计时 ----------
# 对齐 code02.html 方案 05：卡 295×160，圆角 6，2px 屏框；
# 顶部一枚方框状态戳记 + 右侧 RATE；中间大钟；日期行；底部一条虚线切分的倒计时。
$script:LayoutLcd = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="6" Margin="10" BorderThickness="2">
  <Border.Background><SolidColorBrush Color="#262016" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#453721" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#EAB366" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="14,12,14,12">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <Border Grid.Row="0" BorderBrush="#14FFFFFF" BorderThickness="0,0,0,1" Padding="0,0,0,4">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <Border x:Name="StatusPill" Background="#00000000" BorderBrush="#EAB366" BorderThickness="1" CornerRadius="2" Padding="4,1" HorizontalAlignment="Left">
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
              <Ellipse x:Name="StatusDot" Width="0" Height="0" Fill="#EAB366" Visibility="Collapsed" />
              <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#EAB366" Visibility="Collapsed" />
              <TextBlock x:Name="StatusText" Text="[ PEAK MODE ]" FontSize="11" FontWeight="Bold" Foreground="#EAB366" FontFamily="Courier New, Consolas, Microsoft YaHei UI" />
            </StackPanel>
          </Border>
          <Border x:Name="RateBadge" Grid.Column="1" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0" VerticalAlignment="Center">
            <TextBlock x:Name="RateText" Text="RATE: 1.0X" FontSize="11" FontWeight="Bold" Foreground="#EAB366" FontFamily="Courier New, Consolas, Microsoft YaHei UI" />
          </Border>
        </Grid>
      </Border>
      <TextBlock x:Name="ClockText" Grid.Row="2" Text="10:30:24" FontSize="34" FontWeight="Bold" Foreground="#FDE68A" FontFamily="Courier New, Consolas, Microsoft YaHei UI" Margin="0,6,0,6" HorizontalAlignment="Center" />
      <Grid Grid.Row="3">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="DateText" Text="10-28 WED" FontSize="11" Foreground="#EAB366" FontFamily="Courier New, Consolas, Microsoft YaHei UI" />
        <TextBlock x:Name="WeekText" Text="" FontSize="11" Foreground="#EAB366" Visibility="Collapsed" />
        <TextBlock x:Name="TzText" Grid.Column="1" Text="BJT UTC+8" FontSize="11" Foreground="#EAB366" FontFamily="Courier New, Consolas, Microsoft YaHei UI" HorizontalAlignment="Right" />
      </Grid>
      <StackPanel Grid.Row="5" Margin="0,0,0,0">
        <Canvas Height="1" ClipToBounds="True">
          <Line X1="0" Y1="0" X2="900" Y2="0" Stroke="#1AFFFFFF" StrokeThickness="1" StrokeDashArray="2 2" />
        </Canvas>
        <Grid Margin="0,6,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock x:Name="CountdownText" Text="NEXT IDLE:" FontSize="11" Foreground="#EAB366" FontFamily="Courier New, Consolas, Microsoft YaHei UI" />
            <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#8A6A2E" Margin="8,0,0,0" Visibility="Collapsed" />
          </StackPanel>
          <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="11" FontWeight="Bold" Foreground="#FDE68A" FontFamily="Courier New, Consolas, Microsoft YaHei UI" VerticalAlignment="Center" />
        </Grid>
      </StackPanel>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#EAB366" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#EAB366" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FDE68A" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- E4 双色瑞士分屏：左侧 86px 实色铭牌 + 右侧黑曜石大字 ----------
# 对齐 code02.html 方案 04：卡 310×155，圆角 10，1px 描边；
# 左栏三段（状态/倍率/日期属性）垂直均分，右栏日期、时钟、倒计时凹槽。
$script:LayoutSplit = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="10" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#18181B" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#27272A" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#B45309" /></Rectangle.Fill>
    </Rectangle>
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="86" />
        <ColumnDefinition Width="*" />
      </Grid.ColumnDefinitions>
      <Border x:Name="PlateBox" Grid.Column="0" Background="#B45309" CornerRadius="9,0,0,9">
        <Grid Margin="10,12,10,12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
          </Grid.RowDefinitions>
          <StackPanel Grid.Row="0" HorizontalAlignment="Center">
            <TextBlock x:Name="PlateStatus" Text="高峰" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" />
            <TextBlock x:Name="PlateStatusEn" Text="PEAK" FontSize="10" Foreground="#D9FFFFFF" HorizontalAlignment="Center" Margin="0,2,0,0" />
          </StackPanel>
          <TextBlock x:Name="PlateRate" Grid.Row="1" Text="1.0×" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center" />
          <TextBlock x:Name="PlateDay" Grid.Row="2" Text="工作日" FontSize="10" Foreground="#BFFFFFFF" HorizontalAlignment="Center" />
        </Grid>
      </Border>
      <Border Grid.Column="1" Background="#121215" CornerRadius="0,9,9,0">
      <Grid x:Name="Body" Grid.Column="1" Margin="16,14,16,14">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto" />
          <RowDefinition Height="*" />
          <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Orientation="Horizontal">
          <Ellipse x:Name="StatusDot" Width="0" Height="0" Fill="#B45309" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#B45309" Visibility="Collapsed" />
          <TextBlock x:Name="StatusText" Text="" FontSize="11" Foreground="#9CA3AF" Visibility="Collapsed" />
          <TextBlock x:Name="WeekText" Text="周三" FontSize="11" Foreground="#9CA3AF" Visibility="Collapsed" />
          <TextBlock x:Name="DateText" Text="10月28日 周三 · 北京时间" FontSize="11" Foreground="#A1A1AA" />
        </StackPanel>
        <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="32" FontWeight="Bold" Foreground="#FAFAFA" VerticalAlignment="Center" />
        <Border x:Name="CdBox" Grid.Row="2" CornerRadius="6" Background="#27272A" Padding="8,4">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*" />
              <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
              <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="11" Foreground="#71717A" />
              <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#6B7280" Margin="8,0,0,0" Visibility="Collapsed" />
            </StackPanel>
            <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="11" FontWeight="SemiBold" Foreground="#FBBF24" VerticalAlignment="Center" />
          </Grid>
        </Border>
        <Border x:Name="RateBadge" Grid.Row="2" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0" Visibility="Collapsed">
          <TextBlock x:Name="RateText" Text="1.0×" FontSize="20" Foreground="#FBBF24" />
        </Border>
      </Grid>
      </Border>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#FBBF24" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#FBBF24" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- E3 新野兽派：直角白底 + 2px 黑框 + 黑底白字块 + 底部方框条 ----------
# 对齐 code02.html 方案 03：卡 290×165；徽章 / 价格 / 日期 / 倒计时全部硬描边，
# 日期行直接压一条 2px 黑线，真正的「黑框白底」排版。
$script:LayoutBrutal = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="0" Margin="12" BorderThickness="2">
  <Border.Background><SolidColorBrush Color="#FFFFFF" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#111111" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#111111" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="12">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <Border x:Name="StatusPill" Background="#F59E0B" BorderBrush="#111111" BorderThickness="1.5" CornerRadius="0" Padding="6,2" HorizontalAlignment="Left">
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Ellipse x:Name="StatusDot" Width="0" Height="0" Fill="#111111" Visibility="Collapsed" />
            <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#111111" Visibility="Collapsed" />
            <TextBlock x:Name="StatusText" Text="高峰时段 PEAK" FontSize="11" FontWeight="Bold" Foreground="#000000" />
          </StackPanel>
        </Border>
        <Border x:Name="RateBadge" Grid.Column="1" Background="#E2E8F0" BorderBrush="#111111" BorderThickness="1.5" CornerRadius="0" Padding="5,2" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="1.0×" FontSize="11" FontWeight="Bold" Foreground="#111111" />
        </Border>
      </Grid>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="34" FontWeight="Black" Foreground="#111111" Margin="0,4,0,4" />
      <Border Grid.Row="2" BorderBrush="#111111" BorderThickness="0,0,0,2" Padding="0,0,0,4">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal">
            <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" FontWeight="Bold" Foreground="#111111" />
            <TextBlock x:Name="WeekText" Text="周三" FontSize="11" FontWeight="Bold" Foreground="#111111" Margin="6,0,0,0" />
          </StackPanel>
          <TextBlock x:Name="TzText" Grid.Column="1" Text="北京时间" FontSize="11" FontWeight="Bold" Foreground="#111111" HorizontalAlignment="Right" />
        </Grid>
      </Border>
      <Border x:Name="CdBox" Grid.Row="4" BorderBrush="#111111" BorderThickness="1.5" Background="#F1F5F9" Padding="8,4">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock x:Name="CountdownText" Text="距空闲倒计时" FontSize="11" FontWeight="Bold" Foreground="#111111" />
            <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#52525B" Margin="8,0,0,0" Visibility="Collapsed" />
          </StackPanel>
          <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="11" FontWeight="Bold" Foreground="#B45309" VerticalAlignment="Center" />
        </Grid>
      </Border>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33111111" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#111111" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#111111" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#111111" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- D6 半谷：104° 斜切双色 + 细体大钟 + 今日峰谷时长 ----------
# 对齐 design-options-v4.html 方案 06：卡 300×170，圆角 16；
# 斜切比例跟着峰谷走（64% / 36% / 全天 12%），由 Apply-SchemeState 填渐变。
$script:LayoutHalf = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="16" Margin="12" BorderThickness="0">
  <Border.Background><SolidColorBrush Color="#E85D3D" /></Border.Background>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#FFFFFF" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="17,15,17,13">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
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
        <StackPanel Orientation="Horizontal">
          <Ellipse x:Name="StatusDot" Width="0" Height="0" Fill="#FFFFFF" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#FFFFFF" Visibility="Collapsed" />
          <Path x:Name="StatusIconPath" Width="12" Height="12" Margin="0,0,6,0" VerticalAlignment="Center"
                Stroke="#FFD9C9" StrokeThickness="1.6" Stretch="None"
                Data="M1,10 L4.2,3 L7,10 M6,10 L8.6,5 L11,10" />
          <TextBlock x:Name="StatusText" Text="梁文峰时段" FontSize="12.5" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center" />
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="1.0" FontSize="16" FontWeight="Bold" Foreground="#FFFFFF" />
          <TextBlock x:Name="RateTail" Text="×" FontSize="11" Foreground="#FFFFFF" Opacity="0.65" VerticalAlignment="Bottom" Margin="1,0,0,2" />
          <Border x:Name="RateBadge" Width="0" Height="0" Background="#00000000" BorderThickness="0" Visibility="Collapsed" />
        </StackPanel>
      </Grid>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="38" FontWeight="Light" Foreground="#FFFFFF" Margin="0,10,0,0" />
      <StackPanel x:Name="DateBox" Grid.Row="2" Orientation="Horizontal" Margin="0,4,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="11.5" Foreground="#B8FFFFFF" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="11.5" Foreground="#B8FFFFFF" Margin="6,0,0,0" />
      </StackPanel>
      <Grid Grid.Row="4">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="CountdownText" Text="距梁文谷" FontSize="11" Foreground="#8AFFFFFF" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#70FFFFFF" Margin="8,0,0,0" Visibility="Collapsed" />
        </StackPanel>
        <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="12.5" FontWeight="SemiBold" Foreground="#B8FFFFFF" Margin="6,0,0,0" VerticalAlignment="Center" />
      </Grid>
      <StackPanel Grid.Row="5" Orientation="Horizontal" Margin="0,7,0,0">
        <Rectangle x:Name="HalfRule" Width="16" Height="2" Fill="#80FFFFFF" VerticalAlignment="Center" />
        <TextBlock x:Name="HalfFootText" Text="今日 峰 7h · 谷 17h" FontSize="10" Foreground="#9EFFFFFF" Margin="10,0,0,0" />
      </StackPanel>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#FFFFFF" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#FFFFFF" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- D3 K 线：细体大钟 + 24 根蜡烛 + 底部倒计时 ----------
# 对齐 design-options-v4.html 方案 03：卡 316×180，圆角 10，无描边；
# 蜡烛区高 44，高峰柱满高、空闲柱半高，当前小时白描边。
$script:LayoutCandle = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="10" Margin="12" BorderThickness="0">
  <Border.Background><SolidColorBrush Color="#14161C" /></Border.Background>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#E85D3D" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="15,13,15,11">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
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
        <StackPanel Orientation="Horizontal">
          <Ellipse x:Name="StatusDot" Width="0" Height="0" Fill="#E85D3D" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#E85D3D" Visibility="Collapsed" />
          <Path x:Name="StatusIconPath" Width="12" Height="12" Margin="0,0,6,0" VerticalAlignment="Center"
                Stroke="#E85D3D" StrokeThickness="1.6" Stretch="None"
                Data="M1,10 L4.2,3 L7,10 M6,10 L8.6,5 L11,10" />
          <TextBlock x:Name="StatusText" Text="梁文峰时段" FontSize="12.5" FontWeight="SemiBold" Foreground="#E85D3D" VerticalAlignment="Center" />
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="1.0" FontSize="16" FontWeight="Bold" Foreground="#E85D3D" />
          <TextBlock x:Name="RateTail" Text="×" FontSize="11" Foreground="#E85D3D" Opacity="0.65" VerticalAlignment="Bottom" Margin="1,0,0,2" />
          <Border x:Name="RateBadge" Width="0" Height="0" Background="#00000000" BorderThickness="0" Visibility="Collapsed" />
        </StackPanel>
      </Grid>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="34" FontWeight="Light" Foreground="#E9EDF3" Margin="0,6,0,0" />
      <StackPanel x:Name="DateBox" Grid.Row="2" Orientation="Horizontal" Margin="0,3,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="11.5" Foreground="#8B94A5" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="11.5" Foreground="#8B94A5" Margin="6,0,0,0" />
      </StackPanel>
      <Border x:Name="CandleBox" Grid.Row="4" Height="44" Margin="0,4,0,0" Background="#00000000" />
      <Grid Grid.Row="5" Margin="0,7,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="CountdownText" Text="距梁文谷" FontSize="11" Foreground="#5A6272" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#4E5665" Margin="8,0,0,0" Visibility="Collapsed" />
        </StackPanel>
        <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="12.5" FontWeight="SemiBold" Foreground="#8B94A5" Margin="6,0,0,0" VerticalAlignment="Center" />
      </Grid>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#E85D3D" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#E85D3D" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- C6 色块：满版琥珀 + 方块标记 + 刻度尺 ----------
# 对齐 design-options-v3.html 方案 06：卡 280×160，圆角 8，1px 描边；
# 刻度尺高 14，每小时一根刻线，高峰段压深色带，当前时刻黑圆点 + 竖线。
$script:LayoutSolid = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="8" Margin="12" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#E8A33A" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#D08F28" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#111111" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="15,13,15,12">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
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
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="StatusDot" Width="0" Height="0" Fill="#1A1206" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="7" Height="7" Fill="#1A1206" VerticalAlignment="Center" />
          <TextBlock x:Name="StatusText" Text="高峰时段" FontSize="12" FontWeight="Bold" Foreground="#1A1206" Margin="6,0,0,0" />
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <Border x:Name="RateBadge" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0">
            <TextBlock x:Name="RateText" Text="1.0" FontSize="16" FontWeight="Bold" Foreground="#1A1206" FontFamily="Cascadia Mono, Consolas" />
          </Border>
          <TextBlock x:Name="RateTail" Text="×" FontSize="11" Foreground="#1A1206" Opacity="0.6" Margin="1,0,0,2" VerticalAlignment="Bottom" />
        </StackPanel>
      </Grid>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="38" FontWeight="Medium" Foreground="#1A1206" FontFamily="Cascadia Mono, Consolas" Margin="0,12,0,0" />
      <StackPanel x:Name="DateBox" Grid.Row="2" Orientation="Horizontal" Margin="0,7,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="11.5" Foreground="#9E1A1206" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="11.5" Foreground="#9E1A1206" Margin="6,0,0,0" />
      </StackPanel>
      <Border x:Name="ScaleBox" Grid.Row="4" Height="14" Margin="0,0,0,0" Background="#00000000" />
      <Grid Grid.Row="5" Margin="0,7,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="11" Foreground="#701A1206" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#8A5E1E" Margin="8,0,0,0" Visibility="Collapsed" />
        </StackPanel>
        <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="12.5" FontWeight="Bold" Foreground="#1A1206" FontFamily="Cascadia Mono, Consolas" VerticalAlignment="Center" />
      </Grid>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33111111" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#111111" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#111111" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#111111" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- E2 工业级 HUD：顶部琥珀条 + 虚线分隔 + 8 段发光进度 ----------
# 对齐 code02.html 方案 02：卡 290×165，圆角 4，碳黑底；顶条 2px；
# 头部虚线切分，时钟 28px 等宽，8 段进度块（5px 高）每秒随窗口推进。
$script:LayoutHud = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="4" Margin="12" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#0A0E14" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#1E293B" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="HudTopBar" Height="2" VerticalAlignment="Top" Fill="#F59E0B" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#F59E0B" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="14,12,14,11">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="StatusDot" Width="0" Height="0" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#F59E0B" Visibility="Collapsed" />
          <TextBlock x:Name="StatusIcon" Text="▲" FontSize="9" Foreground="#F59E0B" Margin="0,1,6,0" />
          <TextBlock x:Name="StatusText" Text="PEAK ACTIVE" FontSize="11" FontWeight="Bold" Foreground="#F59E0B" FontFamily="Cascadia Mono, Consolas" />
        </StackPanel>
        <Border x:Name="RateBadge" Grid.Column="1" Background="#00000000" BorderBrush="#F59E0B" BorderThickness="1" CornerRadius="2" Padding="4,1" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="RATE 1.0X" FontSize="10" Foreground="#F59E0B" FontFamily="Cascadia Mono, Consolas" />
        </Border>
      </Grid>
      <Canvas Grid.Row="1" Height="1" Margin="0,7,0,0" ClipToBounds="True">
        <Line X1="0" Y1="0" X2="900" Y2="0" Stroke="#1AFFFFFF" StrokeThickness="1" StrokeDashArray="2 2" />
      </Canvas>
      <Grid Grid.Row="3" Margin="0,8,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="ClockText" Text="10:30:24" FontSize="28" FontWeight="Bold" Foreground="#E2E8F0" FontFamily="Cascadia Mono, Consolas" VerticalAlignment="Center" />
        <StackPanel Grid.Column="1" VerticalAlignment="Center">
          <TextBlock x:Name="DateText" Text="OCT.28 WED" FontSize="10" Foreground="#64748B" FontFamily="Cascadia Mono, Consolas" HorizontalAlignment="Right" />
          <TextBlock x:Name="WeekText" Text="" FontSize="10" Foreground="#64748B" Visibility="Collapsed" />
          <TextBlock x:Name="TzText" Text="UTC+8 BJT" FontSize="10" Foreground="#64748B" FontFamily="Cascadia Mono, Consolas" HorizontalAlignment="Right" />
        </StackPanel>
      </Grid>
      <StackPanel Grid.Row="5" Margin="0,0,0,0">
        <Grid Margin="0,0,0,3">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="*" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock x:Name="WinLeftTag" Text="开始" FontSize="8" Foreground="#4B5563" FontFamily="Microsoft YaHei UI" Visibility="Collapsed" Margin="0,0,4,0" VerticalAlignment="Center" />
            <TextBlock x:Name="WinLeft" Text="09:00" FontSize="9" Foreground="#475569" FontFamily="Cascadia Mono, Consolas" VerticalAlignment="Center" />
          </StackPanel>
          <Border x:Name="WinMidBox" Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center" Background="Transparent" BorderThickness="0" CornerRadius="3" Padding="0">
            <TextBlock x:Name="WinMid" Text="PEAK WINDOW 1/2" FontSize="9" Foreground="#475569" FontFamily="Cascadia Mono, Consolas" HorizontalAlignment="Center" />
          </Border>
          <StackPanel Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
            <TextBlock x:Name="WinRight" Text="12:00" FontSize="9" Foreground="#475569" FontFamily="Cascadia Mono, Consolas" VerticalAlignment="Center" />
            <TextBlock x:Name="WinEndTag" Text="结束" FontSize="8" Foreground="#4B5563" FontFamily="Microsoft YaHei UI" Visibility="Collapsed" Margin="4,0,0,0" VerticalAlignment="Center" />
          </StackPanel>
        </Grid>
        <Canvas x:Name="HudProgress" Height="5" ClipToBounds="True" />
      </StackPanel>
      <Border x:Name="CdBox" Grid.Row="7" BorderBrush="#0DFFFFFF" BorderThickness="1" CornerRadius="2" Background="#05FFFFFF" Padding="6,4">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock x:Name="CountdownText" Text="NEXT IDLE IN:" FontSize="10" Foreground="#64748B" FontFamily="Cascadia Mono, Consolas" />
            <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#4B5563" Margin="8,0,0,0" Visibility="Collapsed" />
          </StackPanel>
          <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="10" FontWeight="Bold" Foreground="#F59E0B" FontFamily="Cascadia Mono, Consolas" VerticalAlignment="Center" />
        </Grid>
      </Border>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#FFB020" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#FFB020" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- C4 圆表：外圈刻度 + 内环仪表 + 中心堆叠 ----------
# 对齐 design-options-v3.html 方案 04：Ø300 圆卡，环带 R90–R112；
# 中心从上到下：琥珀 chip、34px 时钟、22px 倍率、日期、倒计时。
$script:LayoutGauge = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="150" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#14161C" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#2C313D" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#E8A33A" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" VerticalAlignment="Center" HorizontalAlignment="Center">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <Border x:Name="StatusPill" Grid.Row="0" Background="#E8A33A" BorderThickness="0" CornerRadius="2" Padding="6,4" HorizontalAlignment="Center">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="ChipDot" Width="4" Height="4" Fill="#1A1206" Opacity="0.65" Margin="0,0,5,0" VerticalAlignment="Center" />
          <TextBlock x:Name="StatusText" Text="高峰" FontSize="10" FontWeight="Bold" Foreground="#1A1206" />
        </StackPanel>
      </Border>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="34" FontWeight="Medium" Foreground="#E9ECF2" FontFamily="Cascadia Mono, Consolas" HorizontalAlignment="Center" Margin="0,14,0,0" />
      <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,8,0,0" VerticalAlignment="Center">
        <Border x:Name="RateBadge" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0">
          <TextBlock x:Name="RateText" Text="1.0" FontSize="22" FontWeight="Bold" Foreground="#E8A33A" FontFamily="Cascadia Mono, Consolas" />
        </Border>
        <TextBlock x:Name="RateTail" Text="×" FontSize="13" Foreground="#E8A33A" Opacity="0.7" VerticalAlignment="Bottom" Margin="1,0,0,3" />
      </StackPanel>
      <StackPanel x:Name="DateBox" Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,14,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" Foreground="#8A93A4" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="11" Foreground="#8A93A4" Margin="5,0,0,0" />
      </StackPanel>
      <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,6,0,0">
        <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="10" Foreground="#5A6272" />
        <TextBlock x:Name="CountdownValue" Text="01:29:36" FontSize="11.5" FontWeight="SemiBold" Foreground="#8A93A4" Margin="6,0,0,0" />
        <TextBlock x:Name="HintText" Text="" FontSize="9" Foreground="#4B5563" Visibility="Collapsed" />
      </StackPanel>
      <Ellipse x:Name="StatusDot" Width="0" Height="0" Fill="#E8A33A" Visibility="Collapsed" />
      <Rectangle x:Name="StatusSquare" Width="0" Height="0" Fill="#E8A33A" Visibility="Collapsed" />
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#E8A33A" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#E8A33A" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

$script:LayoutXaml['banner'] = $script:LayoutBanner
$script:LayoutXaml['orbitA6'] = $script:LayoutOrbitA6
$script:LayoutXaml['orbitB4'] = $script:LayoutOrbitB4
$script:LayoutXaml['tape'] = $script:LayoutTape
$script:LayoutXaml['scope'] = $script:LayoutScope
$script:LayoutXaml['lcd'] = $script:LayoutLcd
$script:LayoutXaml['split'] = $script:LayoutSplit
$script:LayoutXaml['brutal'] = $script:LayoutBrutal
$script:LayoutXaml['half'] = $script:LayoutHalf
$script:LayoutXaml['candle'] = $script:LayoutCandle
$script:LayoutXaml['solid'] = $script:LayoutSolid
$script:LayoutXaml['hud'] = $script:LayoutHud
$script:LayoutXaml['gauge'] = $script:LayoutGauge

# ============================ 坐标换算 ============================
# 专属模板里波形区 / 蜡烛区 / 刻度尺都是 Body 里的普通元素，
# 装饰却画在整卡 Canvas 上，所以要先量出「这个元素在卡片里的位置」。
function Get-ElementBox {
    param($Element, [double]$FallbackW, [double]$FallbackH)
    if ($null -eq $Element) { return @(0.0, 0.0, $FallbackW, $FallbackH) }
    try {
        if ($null -eq $script:Card) { return @(0.0, 0.0, $FallbackW, $FallbackH) }
        $origin = $Element.TransformToAncestor($script:Card).Transform((New-Object System.Windows.Point -ArgumentList 0, 0))
        $w = [double]$Element.ActualWidth
        $h = [double]$Element.ActualHeight
        if ($w -le 1) { $w = $FallbackW }
        if ($h -le 1) { $h = $FallbackH }
        return @([double]$origin.X, [double]$origin.Y, $w, $h)
    } catch {
        return @(0.0, 0.0, $FallbackW, $FallbackH)
    }
}

# 一天里所有高峰窗口的中心 / 宽度，波形与圆表都用它定位
function Get-PeakShape {
    param($Status)
    $list = @()
    foreach ($window in $Status.PeakWindows) {
        $a = [double]$window.Start
        $b = [double]$window.End
        $list += [pscustomobject]@{ Start = $a; End = $b; Center = (($a + $b) / 2.0); Half = (($b - $a) / 2.0) }
    }
    return $list
}

# ============================ F1 峰谷示波器 ============================
# 对齐 code03.html：波形框里有横竖虚线网格；峰值态是两个圆峰，
# 谷时态是倒挂的两个谷，周末/节假日压成一条平线；
# 标记点用十字准星 + 白心圆点 + 深色小标签（PEAK / VALLEY / 全天空闲）。
function Add-DecorScope {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $box = Get-ElementBox -Element $script:ScopeBox -FallbackW ($W - 28) -FallbackH 52
    $bx = [double]$box[0]; $by = [double]$box[1]
    $bw = [double]$box[2]; $bh = [double]$box[3]
    if ($bw -lt 20) { return }

    $accent = [string]$Colors.Accent
    $allDay = -not [bool]$Status.IsPeakDay
    $isPeak = [bool]$Status.IsPeak

    # 波形框内底色：径向渐变从状态色微光过渡到深色（网页稿的 ellipse at 50% 30%）
    $bg1 = '#161F30'
    $bg2 = '#080C14'
    if ($Colors.ContainsKey('ScopeBg1')) { $bg1 = [string]$Colors.ScopeBg1 }
    if ($Colors.ContainsKey('ScopeBg2')) { $bg2 = [string]$Colors.ScopeBg2 }
    $bg = New-Object System.Windows.Shapes.Rectangle
    $bg.Width = $bw
    $bg.Height = $bh
    $bg.RadiusX = 8
    $bg.RadiusY = 8
    $bg.Stroke = New-BrushSafe '#00000000'
    $radial = New-Object System.Windows.Media.RadialGradientBrush
    $radial.Center = New-Object System.Windows.Point -ArgumentList 0.5, 0.3
    $radial.GradientOrigin = New-Object System.Windows.Point -ArgumentList 0.5, 0.3
    $radial.RadiusX = 0.85
    $radial.RadiusY = 1.0
    $c1 = [System.Windows.Media.ColorConverter]::ConvertFromString($bg1)
    $c2 = [System.Windows.Media.ColorConverter]::ConvertFromString($bg2)
    [void]$radial.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $c1, 0.0))
    [void]$radial.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList $c2, 1.0))
    $bg.Fill = $radial
    [System.Windows.Controls.Canvas]::SetLeft($bg, $bx)
    [System.Windows.Controls.Canvas]::SetTop($bg, $by)
    [void]$Layer.Children.Add($bg)

    # 横竖虚线网格：中间那根压状态色，其余白色 5%
    foreach ($ratio in @(0.25, 0.5, 0.75)) {
        $isMid = ([Math]::Abs($ratio - 0.5) -lt 0.01)
        $gy = $by + $bh * $ratio
        $grid = New-LineShape -X1 ($bx + 2) -Y1 $gy -X2 ($bx + $bw - 2) -Y2 $gy -Color '#0DFFFFFF' -Thickness 0.8
        if ($isMid) { $grid.Stroke = New-BrushSafe $accent 0.15 }
        $grid.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection
        [void]$grid.StrokeDashArray.Add(2.0)
        [void]$grid.StrokeDashArray.Add(2.0)
        [void]$Layer.Children.Add($grid)

        $gx = $bx + $bw * $ratio
        $vgrid = New-LineShape -X1 $gx -Y1 ($by + 2) -X2 $gx -Y2 ($by + $bh - 2) -Color '#0DFFFFFF' -Thickness 0.8
        if ($isMid) { $vgrid.Stroke = New-BrushSafe $accent 0.18 }
        $vgrid.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection
        [void]$vgrid.StrokeDashArray.Add(2.0)
        [void]$vgrid.StrokeDashArray.Add(2.0)
        [void]$Layer.Children.Add($vgrid)
    }

    # 波形采样：sin²(2πt) 在 25% / 75% 形成两个圆峰，中间是午间谷
    $baseY = $by + $bh - 10.0
    $topY = $by + 10.0
    $amp = $baseY - $topY
    if ($amp -lt 4) { $amp = 4 }
    $steps = 96
    $curve = @()
    for ($i = 0; $i -le $steps; $i++) {
        $f = $i / [double]$steps
        $wave = [Math]::Sin(2.0 * [Math]::PI * $f)
        $value = $wave * $wave
        $x = $bx + $f * $bw
        if ($allDay) {
            $y = $by + $bh * 0.5
        } elseif ($isPeak) {
            $y = $baseY - $value * $amp
        } else {
            # 谷时态：曲线倒挂，谷底在 25% / 75%
            $y = $topY + $value * $amp
        }
        $curve += , @($x, $y)
    }

    # 曲线下方填充（全天空闲时中线下方的浅色区）
    $fillFigure = New-Object System.Windows.Media.PathFigure
    $fillFigure.IsClosed = $true
    $fillFigure.StartPoint = New-Object System.Windows.Point -ArgumentList $curve[0][0], $curve[0][1]
    for ($i = 1; $i -lt $curve.Count; $i++) {
        [void]$fillFigure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList (New-Object System.Windows.Point -ArgumentList $curve[$i][0], $curve[$i][1]), $true))
    }
    [void]$fillFigure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList (New-Object System.Windows.Point -ArgumentList ($bx + $bw), ($by + $bh)), $true))
    [void]$fillFigure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList (New-Object System.Windows.Point -ArgumentList $bx, ($by + $bh)), $true))
    $fillGeometry = New-Object System.Windows.Media.PathGeometry
    [void]$fillGeometry.Figures.Add($fillFigure)
    $fill = New-Object System.Windows.Shapes.Path
    $fill.Data = $fillGeometry
    $fill.Fill = New-BrushSafe $accent 0.14
    [void]$Layer.Children.Add($fill)

    # 主波形 + 外发光
    $figure = New-Object System.Windows.Media.PathFigure
    $figure.StartPoint = New-Object System.Windows.Point -ArgumentList $curve[0][0], $curve[0][1]
    $figure.IsClosed = $false
    for ($i = 1; $i -lt $curve.Count; $i++) {
        [void]$figure.Segments.Add((New-Object System.Windows.Media.LineSegment -ArgumentList (New-Object System.Windows.Point -ArgumentList $curve[$i][0], $curve[$i][1]), $true))
    }
    $geometry = New-Object System.Windows.Media.PathGeometry
    [void]$geometry.Figures.Add($figure)

    $glow = New-Object System.Windows.Shapes.Path
    $glow.Data = $geometry
    $glow.Stroke = New-BrushSafe $accent 0.22
    $glow.StrokeThickness = 7
    $glow.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
    [void]$Layer.Children.Add($glow)

    $path = New-Object System.Windows.Shapes.Path
    $path.Data = $geometry
    $path.Stroke = New-BrushSafe $accent 0.95
    $path.StrokeThickness = 1.8
    $path.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
    [void]$Layer.Children.Add($path)

    # 标记点：峰顶标右峰（75%），谷底标左谷（25%），全天标平线 30%
    if ($allDay) {
        $mx = $bx + $bw * 0.30
        $my = $by + $bh * 0.5
        $tagLabel = '全天空闲'
        $tagW = 54.0
        $tagY = $my + 11.0
        $tagX = $mx - $tagW / 2.0
    } elseif ($isPeak) {
        $mx = $bx + $bw * 0.75
        $my = $topY
        $tagLabel = 'PEAK 1.0×'
        $tagW = 40.0
        $tagY = $my + 11.0
        $tagX = $mx - $tagW / 2.0
    } else {
        $mx = $bx + $bw * 0.25
        $my = $by + $bh - 10.0
        $tagLabel = 'VALLEY'
        $tagW = 40.0
        $tagY = $my - 24.0
        $tagX = $mx - $tagW / 2.0
    }
    if ($tagX -lt ($bx + 2)) { $tagX = $bx + 2 }
    if (($tagX + $tagW) -gt ($bx + $bw - 2)) { $tagX = $bx + $bw - 2 - $tagW }
    if ($tagY -lt ($by + 2)) { $tagY = $by + 2 }
    if (($tagY + 12.0) -gt ($by + $bh - 2)) { $tagY = $my - 24.0 }

    $crossV = New-LineShape -X1 $mx -Y1 ($my - 6.0) -X2 $mx -Y2 ($my + 8.0) -Color $accent -Thickness 1
    $crossV.Opacity = 0.8
    [void]$Layer.Children.Add($crossV)
    $crossH = New-LineShape -X1 ($mx - 8.0) -Y1 $my -X2 ($mx + 8.0) -Y2 $my -Color $accent -Thickness 1
    $crossH.Opacity = 0.8
    [void]$Layer.Children.Add($crossH)

    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 6; $dot.Height = 6
    $dot.Fill = New-BrushSafe '#FFFFFF'
    $dot.Stroke = New-BrushSafe $accent
    $dot.StrokeThickness = 2
    [System.Windows.Controls.Canvas]::SetLeft($dot, ($mx - 3))
    [System.Windows.Controls.Canvas]::SetTop($dot, ($my - 3))
    [void]$Layer.Children.Add($dot)

    $tag = New-Object System.Windows.Controls.Border
    $tag.Width = $tagW
    $tag.Height = 12
    $tag.Background = New-BrushSafe '#B3000000'
    $tag.BorderBrush = New-BrushSafe $accent 0.5
    $tag.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 0.8
    $tag.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 2
    $tagText = New-Object System.Windows.Controls.TextBlock
    $tagText.Text = $tagLabel
    $tagText.FontSize = 7.5
    $tagText.FontWeight = [System.Windows.FontWeights]::Bold
    $tagText.Foreground = New-BrushSafe $accent
    $tagText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $tagText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $tag.Child = $tagText
    [System.Windows.Controls.Canvas]::SetLeft($tag, $tagX)
    [System.Windows.Controls.Canvas]::SetTop($tag, $tagY)
    [void]$Layer.Children.Add($tag)
}

# ============================ D3 K 线 ============================
# 对齐 design-options-v4.html：24 根等宽蜡烛（间隙 2），高峰满高橙红、空闲半高青绿，
# 底部一条 1px 基线；当前那一根描 1.5px 白边。
function Add-DecorKline {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $box = Get-ElementBox -Element $script:CandleBox -FallbackW ($W - 30) -FallbackH 44
    $bx = [double]$box[0]; $by = [double]$box[1]
    $bw = [double]$box[2]; $bh = [double]$box[3]
    if ($bw -lt 20) { return }

    $baseY = $by + $bh
    $baseline = New-LineShape -X1 $bx -Y1 ($baseY - 0.5) -X2 ($bx + $bw) -Y2 ($baseY - 0.5) -Color '#24FFFFFF' -Thickness 1
    [void]$Layer.Children.Add($baseline)

    $gap = 2.0
    $barW = ($bw - $gap * 23.0) / 24.0
    if ($barW -lt 2) { $barW = 2 }
    $peakColor = '#E85D3D'
    $idleColor = '#732FB89A'
    $currentHour = [int][Math]::Floor([double]$Status.DayFraction * 24.0)
    if ($currentHour -gt 23) { $currentHour = 23 }
    if ($currentHour -lt 0) { $currentHour = 0 }

    for ($h = 0; $h -lt 24; $h++) {
        $rate = Get-DayRate -Fraction (($h + 0.5) / 24.0) -Windows $Status.PeakWindows -Soft 0.0001
        $isPeak = ($rate -gt 0.5)
        $x = $bx + $h * ($barW + $gap)
        if ($isPeak) {
            $barH = $bh
            $color = $peakColor
        } else {
            $barH = $bh * 0.5
            $color = $idleColor
        }
        $bar = New-RectShape -X $x -Y ($baseY - $barH) -W $barW -H $barH -Color $color -Radius 1
        if ($h -eq $currentHour) {
            $bar.Stroke = New-BrushSafe '#FFFFFF'
            $bar.StrokeThickness = 1.5
            try {
                $glow = New-Object System.Windows.Media.Effects.DropShadowEffect
                $glow.BlurRadius = 8
                $glow.ShadowDepth = 0
                $glow.Opacity = 0.5
                $glow.Color = [System.Windows.Media.ColorConverter]::ConvertFromString('#FFFFFF')
                $bar.Effect = $glow
            } catch { }
        }
        [void]$Layer.Children.Add($bar)
    }
}

# ============================ C2 报表页眉 ============================
# 网页稿的纸感卡片左上角有一行小字「STATUS」，下面压一条细黑线。
function Add-DecorPaperHeader {
    param($Layer, [double]$W, [double]$H, $Colors)
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = 'S T A T U S'
    $label.FontSize = 9
    $label.Foreground = New-BrushSafe '#9A8B76'
    [System.Windows.Controls.Canvas]::SetLeft($label, 15)
    [System.Windows.Controls.Canvas]::SetTop($label, 11)
    [void]$Layer.Children.Add($label)

    $y = 52.0
    if ($null -ne $script:StatusText) {
        try {
            $box = Get-ElementBox -Element $script:StatusText -FallbackW 100 -FallbackH 18
            $y = [double]$box[1] + [double]$box[3] + 5
        } catch { }
    }
    $rule = New-LineShape -X1 15 -Y1 $y -X2 ($W - 15) -Y2 $y -Color '#551C1917' -Thickness 1
    [void]$Layer.Children.Add($rule)
}

# ============================ A6 / B4 轨道环 ============================
# A6：厚环带 + 圆头琥珀弧 + 起点白点；B4：细石英环 + 当前时刻白点。
function Add-DecorOrbitRing {
    param($Layer, [double]$W, [double]$H, $Colors, $Status, [string]$Style)
    $size = [Math]::Min($W, $H)
    if ($size -lt 1) { return }
    $cx = $W / 2.0
    $cy = $H / 2.0
    $accent = [string]$Colors.Accent
    $thick = 18.0
    $outer = $size / 2.0 - 26.0
    $trackColor = '#12FFFFFF'
    if ([string]$Style -eq 'quartz') {
        $thick = 4.0
        $outer = $size / 2.0 - 30.0
        $trackColor = '#1AFFFFFF'
    }

    $track = New-Object System.Windows.Shapes.Ellipse
    $track.Width = $outer * 2
    $track.Height = $outer * 2
    $track.Stroke = New-BrushSafe $trackColor
    $track.StrokeThickness = $thick
    $track.Fill = New-BrushSafe '#00000000'
    [System.Windows.Controls.Canvas]::SetLeft($track, ($cx - $outer))
    [System.Windows.Controls.Canvas]::SetTop($track, ($cy - $outer))
    [void]$Layer.Children.Add($track)

    $windows = @($Status.PeakWindows)
    # A6 的网页稿把 00:00 放在圆盘底部（整体旋转 180°），B4 仍是 00:00 在顶部
    $angleOffset = 0.0
    if ([string]$Style -eq 'glow') { $angleOffset = 180.0 }
    if ($windows.Count -gt 0) {
        foreach ($window in $windows) {
            $startAngle = [double]$window.Start * 360.0 + $angleOffset
            $endAngle = [double]$window.End * 360.0 + $angleOffset
            $arc = New-Object System.Windows.Shapes.Path
            $arc.Data = New-ArcGeometry -Cx $cx -Cy $cy -Radius $outer -StartAngle $startAngle -EndAngle $endAngle
            $arc.Stroke = New-BrushSafe $accent
            $arc.StrokeThickness = $thick
            $arc.StrokeStartLineCap = [System.Windows.Media.PenLineCap]::Round
            $arc.StrokeEndLineCap = [System.Windows.Media.PenLineCap]::Round
            [void]$Layer.Children.Add($arc)
        }
    } else {
        # 周末 / 节假日：没有高峰窗口，整圈压成一条展示状态的细环
        $full = New-Object System.Windows.Shapes.Ellipse
        $full.Width = $outer * 2
        $full.Height = $outer * 2
        $full.Stroke = New-BrushSafe $accent 0.38
        $full.StrokeThickness = $thick
        $full.Fill = New-BrushSafe '#00000000'
        [System.Windows.Controls.Canvas]::SetLeft($full, ($cx - $outer))
        [System.Windows.Controls.Canvas]::SetTop($full, ($cy - $outer))
        [void]$Layer.Children.Add($full)
    }

    # 白点：A6 放在第一段高峰弧的起点；B4 放在当前时刻
    $angle = 0.0
    if ([string]$Style -eq 'glow') {
        if ($windows.Count -gt 0) { $angle = [double]$windows[0].Start * 360.0 + $angleOffset } else { $angle = 0.0 }
    } else {
        $angle = [double]$Status.DayFraction * 360.0
    }
    $rad = ($angle - 90.0) * [Math]::PI / 180.0
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 8; $dot.Height = 8
    $dot.Fill = New-BrushSafe '#FFFFFF'
    [System.Windows.Controls.Canvas]::SetLeft($dot, ($cx + $outer * [Math]::Cos($rad) - 4))
    [System.Windows.Controls.Canvas]::SetTop($dot, ($cy + $outer * [Math]::Sin($rad) - 4))
    [void]$Layer.Children.Add($dot)
}

# ============================ A3 / B3 光球脉冲 ============================
# 网页稿的光球外有一圈呼吸光环；位置跟着模板里的 StatusDot 走。
function Add-DecorBannerPulse {
    param($Layer, [double]$W, [double]$H, $Colors, $Spec, $Status)
    if ($null -eq $script:StatusDot) { return }
    $box = Get-ElementBox -Element $script:StatusDot -FallbackW 10 -FallbackH 10
    $cx = [double]$box[0] + [double]$box[2] / 2.0
    $cy = [double]$box[1] + [double]$box[3] / 2.0
    $accent = [System.Windows.Media.ColorConverter]::ConvertFromString([string]$Colors.Accent)

    # 柔和外光
    $auraSize = [double]$Spec.OrbAura
    if ($auraSize -gt 4) {
        $aura = New-Object System.Windows.Shapes.Ellipse
        $aura.Width = $auraSize
        $aura.Height = $auraSize
        $brush = New-Object System.Windows.Media.RadialGradientBrush
        $brush.Center = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
        $brush.GradientOrigin = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
        $brush.RadiusX = 0.5
        $brush.RadiusY = 0.5
        [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(58, $accent.R, $accent.G, $accent.B)), 0.0))
        [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.Color]::FromArgb(0, $accent.R, $accent.G, $accent.B)), 1.0))
        $aura.Fill = $brush
        [System.Windows.Controls.Canvas]::SetLeft($aura, ($cx - $auraSize / 2.0))
        [System.Windows.Controls.Canvas]::SetTop($aura, ($cy - $auraSize / 2.0))
        [void]$Layer.Children.Add($aura)
    }

    # 呼吸光环：缩放 + 淡出，循环 2.8 秒
    $ringSize = [double]$Spec.OrbRing
    if ($ringSize -gt 4) {
        $ring = New-Object System.Windows.Shapes.Ellipse
        $ring.Width = $ringSize
        $ring.Height = $ringSize
        $ring.Fill = New-BrushSafe '#00000000'
        $ring.Stroke = New-BrushSafe ([string]$Colors.Accent)
        $ring.StrokeThickness = 1.4
        $ring.Opacity = 0.55
        $scale = New-Object System.Windows.Media.ScaleTransform -ArgumentList 0.6, 0.6
        $ring.RenderTransformOrigin = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
        $ring.RenderTransform = $scale
        [System.Windows.Controls.Canvas]::SetLeft($ring, ($cx - $ringSize / 2.0))
        [System.Windows.Controls.Canvas]::SetTop($ring, ($cy - $ringSize / 2.0))
        [void]$Layer.Children.Add($ring)

        $scaleAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $scaleAnim.From = 0.6
        $scaleAnim.To = 1.35
        $scaleAnim.Duration = [TimeSpan]::FromSeconds(2.8)
        $scaleAnim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $scale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $scaleAnim)
        $scale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $scaleAnim)

        $fadeAnim = New-Object System.Windows.Media.Animation.DoubleAnimation
        $fadeAnim.From = 0.55
        $fadeAnim.To = 0.0
        $fadeAnim.Duration = [TimeSpan]::FromSeconds(2.8)
        $fadeAnim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $ring.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeAnim)
    }

    # B3 的大光球本身也慢慢呼吸
    if ([double]$Spec.OrbSize -ge 30) {
        $breath = New-Object System.Windows.Media.Animation.DoubleAnimation
        $breath.From = 1.0
        $breath.To = 0.72
        $breath.Duration = [TimeSpan]::FromSeconds(2.4)
        $breath.AutoReverse = $true
        $breath.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $script:StatusDot.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $breath)
    }
}

# ============================ E5 内凹屏槽 ============================
# 网页稿的 box-shadow 是 inset 0 0 10px rgba(0,0,0,.8)：
# 四边压暗、中间保持屏色，看起来像一块真的内凹玻璃。
function Add-DecorLcdVignette {
    param($Layer, [double]$W, [double]$H, $Colors)
    $vig = New-Object System.Windows.Shapes.Rectangle
    $vig.Width = $W
    $vig.Height = $H
    $vig.RadiusX = 4
    $vig.RadiusY = 4
    $brush = New-Object System.Windows.Media.RadialGradientBrush
    $brush.Center = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
    $brush.GradientOrigin = New-Object System.Windows.Point -ArgumentList 0.5, 0.5
    $brush.RadiusX = 0.72
    $brush.RadiusY = 0.78
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#00000000')), 0.0))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#00000000')), 0.62))
    [void]$brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop -ArgumentList ([System.Windows.Media.ColorConverter]::ConvertFromString('#8C000000')), 1.0))
    $vig.Fill = $brush
    [void]$Layer.Children.Add($vig)
}

# ============================ C6 色块 ============================
# 网页稿：日期下面一条 14px 刻度尺（1 小时一格），高峰段压深色带，
# 当前时刻一根 2px 竖线 + 顶端小圆点。
function Add-DecorScaleBar {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $box = Get-ElementBox -Element $script:ScaleBox -FallbackW ($W - 30) -FallbackH 14
    $bx = [double]$box[0]; $by = [double]$box[1]
    $bw = [double]$box[2]; $bh = [double]$box[3]
    if ($bw -lt 20) { return }

    $ruleColor = '#3D1A1206'
    $tickColor = '#521A1206'
    $bandColor = '#8C1A1206'
    $nowColor = '#1A1206'
    $freeColor = '#2E04140F'
    if ($Colors.ContainsKey('Rule')) { $ruleColor = [string]$Colors.Rule }
    if ($Colors.ContainsKey('Tick')) { $tickColor = [string]$Colors.Tick }
    if ($Colors.ContainsKey('Band')) { $bandColor = [string]$Colors.Band }
    if ($Colors.ContainsKey('Now')) { $nowColor = [string]$Colors.Now }
    if ($Colors.ContainsKey('FreeBand')) { $freeColor = [string]$Colors.FreeBand }

    $topY = $by
    $bottomY = $by + $bh - 1.0
    $topRule = New-LineShape -X1 $bx -Y1 $topY -X2 ($bx + $bw) -Y2 $topY -Color $ruleColor -Thickness 1
    [void]$Layer.Children.Add($topRule)
    $bottomRule = New-LineShape -X1 $bx -Y1 $bottomY -X2 ($bx + $bw) -Y2 $bottomY -Color $ruleColor -Thickness 1
    [void]$Layer.Children.Add($bottomRule)

    if (-not [bool]$Status.IsPeakDay) {
        $band = New-RectShape -X $bx -Y $topY -W $bw -H ($bottomY - $topY) -Color $freeColor
        [void]$Layer.Children.Add($band)
    } else {
        foreach ($window in $Status.PeakWindows) {
            $sx = $bx + [double]$window.Start * $bw
            $ex = $bx + [double]$window.End * $bw
            $band = New-RectShape -X $sx -Y $topY -W ($ex - $sx) -H ($bottomY - $topY) -Color $bandColor
            [void]$Layer.Children.Add($band)
        }
    }

    # 每小时一根 5px 短刻线，从尺子顶部往下挂
    for ($h = 0; $h -le 24; $h++) {
        $tx = $bx + $h / 24.0 * $bw
        $tick = New-LineShape -X1 $tx -Y1 $topY -X2 $tx -Y2 ($topY + 5) -Color $tickColor -Thickness 1
        [void]$Layer.Children.Add($tick)
    }

    $nowX = $bx + [double]$Status.DayFraction * $bw
    $stem = New-LineShape -X1 $nowX -Y1 ($topY - 4) -X2 $nowX -Y2 ($bottomY + 4) -Color $nowColor -Thickness 2
    [void]$Layer.Children.Add($stem)
    $knob = New-Object System.Windows.Shapes.Ellipse
    $knob.Width = 5; $knob.Height = 5
    $knob.Fill = New-BrushSafe $nowColor
    [System.Windows.Controls.Canvas]::SetLeft($knob, ($nowX - 2.5))
    [System.Windows.Controls.Canvas]::SetTop($knob, ($topY - 6))
    [void]$Layer.Children.Add($knob)
}

# ============================ C4 圆表 ============================
# 对齐 design-options-v3.html：环带内径 90 / 外径 112（按 300 卡缩放）；
# 24 根小时刻度（每 6 小时加长）、琥珀高峰弧、白色游标线。
function Add-DecorGauge {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $size = [Math]::Min($W, $H)
    if ($size -lt 1) { $size = 300.0 }
    $scale = $size / 300.0
    $cx = $W / 2.0
    $cy = $H / 2.0
    $rIn = 90.0 * $scale
    $rOut = 112.0 * $scale
    $trackR = ($rIn + $rOut) / 2.0
    $trackW = $rOut - $rIn
    $accent = [string]$Colors.Accent
    if ($Colors.ContainsKey('Arc')) { $accent = [string]$Colors.Arc }
    $free = '#422FAE93'
    if ($Colors.ContainsKey('Free')) { $free = [string]$Colors.Free }
    $tickColor = '#29FFFFFF'
    if ($Colors.ContainsKey('Tick')) { $tickColor = [string]$Colors.Tick }

    # 环带轨道
    $track = New-Object System.Windows.Shapes.Ellipse
    $track.Width = $trackR * 2
    $track.Height = $trackR * 2
    $track.Stroke = New-BrushSafe '#1AFFFFFF'
    $track.StrokeThickness = $trackW
    $track.Fill = New-BrushSafe '#00000000'
    [System.Windows.Controls.Canvas]::SetLeft($track, ($cx - $trackR))
    [System.Windows.Controls.Canvas]::SetTop($track, ($cy - $trackR))
    [void]$Layer.Children.Add($track)

    if (-not [bool]$Status.IsPeakDay) {
        # 周末 / 节假日：整圈一条青绿细环
        $ring = New-Object System.Windows.Shapes.Ellipse
        $ring.Width = $trackR * 2
        $ring.Height = $trackR * 2
        $ring.Stroke = New-BrushSafe $free
        $ring.StrokeThickness = $trackW
        $ring.Fill = New-BrushSafe '#00000000'
        [System.Windows.Controls.Canvas]::SetLeft($ring, ($cx - $trackR))
        [System.Windows.Controls.Canvas]::SetTop($ring, ($cy - $trackR))
        [void]$Layer.Children.Add($ring)
    } else {
        foreach ($window in $Status.PeakWindows) {
            $startAngle = [double]$window.Start * 360.0
            $endAngle = [double]$window.End * 360.0
            $arc = New-Object System.Windows.Shapes.Path
            $arc.Data = New-ArcGeometry -Cx $cx -Cy $cy -Radius $trackR -StartAngle $startAngle -EndAngle $endAngle
            $arc.Stroke = New-BrushSafe $accent
            $arc.StrokeThickness = $trackW
            [void]$Layer.Children.Add($arc)
        }
    }

    # 24 根刻度：每 15° 一根，6 小时处加长
    for ($i = 0; $i -lt 24; $i++) {
        $angle = $i * 15.0
        $rad = ($angle - 90.0) * [Math]::PI / 180.0
        $isLong = (($i % 6) -eq 0)
        $r1 = (128.0 * $scale)
        $r2 = (144.0 * $scale)
        if (-not $isLong) { $r1 = 134.0 * $scale }
        $thickness = 1.0
        if ($isLong) { $thickness = 1.8 * $scale; if ($thickness -lt 1.0) { $thickness = 1.0 } }
        $line = New-LineShape -X1 ($cx + $r1 * [Math]::Cos($rad)) -Y1 ($cy + $r1 * [Math]::Sin($rad)) `
            -X2 ($cx + $r2 * [Math]::Cos($rad)) -Y2 ($cy + $r2 * [Math]::Sin($rad)) -Color $tickColor -Thickness $thickness
        [void]$Layer.Children.Add($line)
    }

    # 当前时刻游标：从环内侧穿到环外侧
    $needle = New-LineShape -X1 $cx -Y1 ($cy - 120.0 * $scale) -X2 $cx -Y2 ($cy - 147.0 * $scale) -Color '#FFFFFF' -Thickness (2.5 * $scale)
    [void]$Layer.Children.Add($needle)

    $script:DecorRefs['GaugeNeedle'] = $needle
    $script:DecorRefs['GaugeCx'] = $cx
    $script:DecorRefs['GaugeCy'] = $cy
    $script:DecorRefs['GaugeRInner'] = 120.0 * $scale
    $script:DecorRefs['GaugeROuter'] = 147.0 * $scale
}

# ============================ E2 HUD 分段进度 ============================
# 网页稿是 8 段发光块。这里做成「完全点亮的段 + 正在填充的那一段」，
# 每秒重算，进度会连续往前爬，而不是十分钟才跳一格。
function Add-DecorHudProgress {
    param($Layer, [double]$W, [double]$H, $Colors, $Status, $Spec)
    $canvas = $script:HudProgress
    if ($null -eq $canvas) { return }

    $width = [double]$canvas.ActualWidth
    if ($width -lt 20) { $width = $W - 28 }
    if ($width -lt 20) { return }
    $count = 8
    if ([int]$Spec.HudSegments -gt 0) { $count = [int]$Spec.HudSegments }
    $gap = 2.0
    $segW = ($width - $gap * ($count - 1)) / $count
    if ($segW -lt 3) { return }
    $height = 5.0
    if ([double]$Spec.HudBarHeight -gt 0) { $height = [double]$Spec.HudBarHeight }
    $canvas.Height = $height
    $accent = [string]$Colors.Accent
    # 原版 E2 保持 1px 圆角 + 4px 辉光；厚版 E2B 才用 2px 圆角 + 6px 辉光
    $barRadius = 1.0
    $glowBlur = 4.0
    if ($height -ge 8) {
        $barRadius = 2.0
        $glowBlur = 6.0
    }

    if (-not [bool]$Status.IsPeakDay) {
        $lit = [double]$count
    } else {
        $progress = Get-PhaseProgress -Fraction ([double]$Status.DayFraction) -Status $Status
        if ($progress -lt 0) { $progress = 0 }
        if ($progress -gt 1) { $progress = 1 }
        if ([bool]$Spec.HudDrain) {
            # 剩余量：窗口开始时满格，结束时排空
            $lit = (1.0 - $progress) * $count
        } else {
            # 原版 E2：已过时间越多，点亮的段越多
            $lit = $progress * $count
        }
    }

    # 只在宽度/高度变化时重建矩形；之后每秒只改「点亮部分」的宽度和颜色
    $needBuild = $true
    if ([int]$script:DecorRefs['HudSegmentCount'] -eq $count) {
        if ([Math]::Abs([double]$script:DecorRefs['HudWidth'] - $width) -lt 0.5 -and
            [Math]::Abs([double]$script:DecorRefs['HudHeight'] - $height) -lt 0.5) { $needBuild = $false }
    }
    if ($needBuild) {
        $canvas.Children.Clear()
        $script:DecorRefs['HudBase'] = @()
        $script:DecorRefs['HudLit'] = @()
        for ($i = 0; $i -lt $count; $i++) {
            $x = $i * ($segW + $gap)
            $base = New-RectShape -X $x -Y 0 -W $segW -H $height -Color '#1E293B' -Radius $barRadius
            $litRect = New-RectShape -X $x -Y 0 -W 0 -H $height -Color $accent -Radius $barRadius
            $litRect.Fill = New-BrushSafe $accent
            try { $litRect.Effect = New-CardShadow -Blur $glowBlur -Depth 0 -Opacity 0.4 } catch { }
            [void]$canvas.Children.Add($base)
            [void]$canvas.Children.Add($litRect)
            $script:DecorRefs['HudBase'] += , $base
            $script:DecorRefs['HudLit'] += , $litRect
        }
        $script:DecorRefs['HudSegmentCount'] = $count
        $script:DecorRefs['HudWidth'] = $width
        $script:DecorRefs['HudSegW'] = $segW
        $script:DecorRefs['HudGap'] = $gap
        $script:DecorRefs['HudHeight'] = $height
    }

    $segW = [double]$script:DecorRefs['HudSegW']
    $gap = [double]$script:DecorRefs['HudGap']
    $litRects = @($script:DecorRefs['HudLit'])
    $drain = [bool]$Spec.HudDrain
    for ($i = 0; $i -lt $litRects.Count; $i++) {
        if ($drain) {
            # 剩余量靠右：亮的段是「还没走完的未来」，紧贴结束时间
            $remain = $lit - ($count - 1 - $i)
        } else {
            $remain = $lit - $i
        }
        if ($remain -lt 0) { $remain = 0 }
        if ($remain -gt 1) { $remain = 1 }
        $rect = $litRects[$i]
        $rect.Width = $segW * $remain
        if ($remain -gt 0) {
            $baseX = $i * ($segW + $gap)
            $leftX = $baseX
            if ($drain) { $leftX = $baseX + $segW * (1.0 - $remain) }
            [System.Windows.Controls.Canvas]::SetLeft($rect, $leftX)
            $rect.Visibility = [System.Windows.Visibility]::Visible
            if (-not [string]::Equals([string]$script:DecorRefs['HudAccent'], $accent)) {
                $rect.Fill = New-BrushSafe $accent
                try { $rect.Effect = New-CardShadow -Blur $glowBlur -Depth 0 -Opacity 0.4 } catch { }
            }
        } else {
            $rect.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
    $script:DecorRefs['HudAccent'] = $accent
}

# 当前这一段（高峰窗口 或 空闲间隔）已经走了多少
function Get-PhaseProgress {
    param([double]$Fraction, $Status)
    $windows = @($Status.PeakWindows)
    if ($windows.Count -eq 0) { return ($Fraction % (1.0 / 24.0)) * 24.0 }

    $prevEnd = 0.0
    $nextStart = 1.0
    foreach ($window in $windows) {
        $a = [double]$window.Start
        $b = [double]$window.End
        if (($Fraction -ge $a) -and ($Fraction -le $b)) {
            $span = $b - $a
            if ($span -le 0) { return 0.0 }
            return (($Fraction - $a) / $span)
        }
        if ($b -lt $Fraction) { $prevEnd = $b }
        if (($a -gt $Fraction) -and ($a -lt $nextStart)) { $nextStart = $a }
    }
    $span2 = $nextStart - $prevEnd
    if ($span2 -le 0) { return 0.0 }
    return (($Fraction - $prevEnd) / $span2)
}

# ============================ 专属文案 ============================
# 网页稿里每个方案的文案都不一样（梁文峰时段 / [ PEAK MODE ] / PEAK ACTIVE …），
# 统一在这里填，Update-Widget 只调这一个函数。
function Format-HourLabel {
    param([double]$Fraction)
    $total = [int][Math]::Round($Fraction * 24.0 * 60.0)
    $h = [int][Math]::Floor($total / 60)
    $m = $total % 60
    return ('{0:00}:{1:00}' -f $h, $m)
}

function Update-SchemeCustomText {
    param([object]$Spec, [object]$Status)
    if (($null -eq $Spec) -or ($null -eq $Status)) { return }
    $key = [string]$Spec.Key
    $isPeak = [bool]$Status.IsPeak
    $now = $Status.Now

    # 英文星期 / 月份缩写
    $enWeek = @{ 'Monday' = 'MON'; 'Tuesday' = 'TUE'; 'Wednesday' = 'WED'; 'Thursday' = 'THU'; 'Friday' = 'FRI'; 'Saturday' = 'SAT'; 'Sunday' = 'SUN' }
    $enMonth = @{ 1 = 'JAN'; 2 = 'FEB'; 3 = 'MAR'; 4 = 'APR'; 5 = 'MAY'; 6 = 'JUN'; 7 = 'JUL'; 8 = 'AUG'; 9 = 'SEP'; 10 = 'OCT'; 11 = 'NOV'; 12 = 'DEC' }
    $weekEn = [string]$enWeek[[string]$now.DayOfWeek]
    $monthEn = [string]$enMonth[[int]$now.Month]
    $dayText = ('{0}-{1:00}' -f $now.Month, $now.Day)

    # 今日峰 / 谷时长
    $peakHours = 0.0
    foreach ($window in $Status.PeakWindows) {
        $peakHours += ([double]$window.End - [double]$window.Start) * 24.0
    }
    $peakHours = [Math]::Round($peakHours, 0)
    $idleHours = 24 - $peakHours

    switch ($key) {
        'f1' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '梁文谷时段'
                if ($isPeak) { $script:StatusText.Text = '梁文峰时段' }
                if ($Status.IsWeekend) { $script:StatusText.Text = '梁文谷 · 周末' }
                if ($Status.IsHoliday) { $script:StatusText.Text = '梁文谷 · ' + [string]$Status.HolidayName }
            }
            if ($null -ne $script:RateTail) {
                $script:RateTail.Text = '优惠'
                if ($isPeak) { $script:RateTail.Text = '标准' }
                if ($Status.IsWeekend) { $script:RateTail.Text = '全天' }
                if ($Status.IsHoliday) { $script:RateTail.Text = '假日' }
            }
            if ($null -ne $script:CountdownText) {
                if ($Status.IsWeekend) { $script:CountdownText.Text = '距周一高峰' }
                if ($Status.IsHoliday) { $script:CountdownText.Text = '距收假高峰' }
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        'e5' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '[ IDLE MODE ]'
                if ($isPeak) { $script:StatusText.Text = '[ PEAK MODE ]' }
                if ($Status.IsWeekend) { $script:StatusText.Text = '[ WEEKEND ]' }
                if ($Status.IsHoliday) {
                    $name = [string]$Status.HolidayName
                    if ([string]::IsNullOrWhiteSpace($name)) { $name = '节假日' }
                    $script:StatusText.Text = '[ HOLIDAY:' + $name + ' ]'
                }
            }
            if ($null -ne $script:RateText) {
                $rate = '0.5X'
                if ($isPeak) { $rate = '1.0X' }
                $script:RateText.Text = 'RATE: ' + $rate
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = $dayText + ' ' + $weekEn }
            if ($null -ne $script:TzText) {
                $script:TzText.Text = 'BJT UTC+8'
                if ($Status.IsWeekend) { $script:TzText.Text = 'ALL-DAY IDLE' }
                if ($Status.IsHoliday) { $script:TzText.Text = 'UPDATE PENDING' }
            }
            if ($null -ne $script:CountdownValue) {
                $cdText = [string]$script:CountdownValue.Text
                if ($cdText -match '^(\d+)天\s+(.+)$') {
                    $script:CountdownValue.Text = $matches[1] + 'D ' + $matches[2]
                }
            }
        }
        'e4' {
            if ($null -ne $script:PlateStatus) {
                $script:PlateStatus.Text = '空闲'
                if ($isPeak) { $script:PlateStatus.Text = '高峰' }
                if ($Status.IsWeekend) { $script:PlateStatus.Text = '周末' }
                if ($Status.IsHoliday) {
                    $name = [string]$Status.HolidayName
                    if ([string]::IsNullOrWhiteSpace($name)) { $name = '节假日' }
                    $script:PlateStatus.Text = $name
                }
            }
            if ($null -ne $script:PlateStatusEn) {
                $script:PlateStatusEn.Text = 'IDLE'
                if ($isPeak) { $script:PlateStatusEn.Text = 'PEAK' }
                if ($Status.IsWeekend) { $script:PlateStatusEn.Text = 'WEEKEND' }
                if ($Status.IsHoliday) { $script:PlateStatusEn.Text = 'HOLIDAY' }
            }
            if ($null -ne $script:PlateRate) {
                $script:PlateRate.Text = '0.5×'
                if ($isPeak) { $script:PlateRate.Text = '1.0×' }
            }
            if ($null -ne $script:PlateDay) {
                $script:PlateDay.Text = '工作日'
                if ($Status.IsWeekend) { $script:PlateDay.Text = '全天可用' }
                if ($Status.IsHoliday) { $script:PlateDay.Text = '放假全天' }
            }
            if ($null -ne $script:DateText) {
                $line = [string]$Status.DateText + ' ' + [string]$Status.WeekText
                if ($Status.IsWeekend) { $line = $line + ' · 全天空闲' }
                elseif ($Status.IsHoliday) { $line = $line + ' · 节假日' }
                else { $line = $line + ' · 北京时间' }
                $script:DateText.Text = $line
            }
        }
        'e3' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '空闲时段 IDLE'
                if ($isPeak) { $script:StatusText.Text = '高峰时段 PEAK' }
                if ($Status.IsWeekend) { $script:StatusText.Text = '周末 · 全天空闲' }
                if ($Status.IsHoliday) { $script:StatusText.Text = '节假日 · 放假中' }
                if ($Status.IsHoliday -and -not [string]::IsNullOrWhiteSpace([string]$Status.HolidayName)) {
                    $script:StatusText.Text = [string]$Status.HolidayName + ' · 放假中'
                }
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
            if ($null -ne $script:TzText) {
                $script:TzText.Text = '北京时间'
                if ($Status.IsWeekend) { $script:TzText.Text = '全天 0.5×' }
                if ($Status.IsHoliday) {
                    if ([bool]$Status.YearCovered) { $script:TzText.Text = '全天 0.5×' }
                    else { $script:TzText.Text = '数据待更新' }
                }
            }
        }
        'd6' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '梁文谷时段'
                if ($isPeak) { $script:StatusText.Text = '梁文峰时段' }
            }
            if ($null -ne $script:RateText) { $script:RateText.Text = '0.5'; if ($isPeak) { $script:RateText.Text = '1.0' } }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
            if ($null -ne $script:HalfFootText) {
                $script:HalfFootText.Text = ('今日 峰 {0}h · 谷 {1}h' -f $peakHours, $idleHours)
            }
        }
        'd3' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '梁文谷时段'
                if ($isPeak) { $script:StatusText.Text = '梁文峰时段' }
            }
            if ($null -ne $script:RateText) { $script:RateText.Text = '0.5'; if ($isPeak) { $script:RateText.Text = '1.0' } }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        'd1' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '梁文谷时段'
                if ($isPeak) { $script:StatusText.Text = '梁文峰时段' }
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        'c1' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '空闲'
                if ($isPeak) { $script:StatusText.Text = '高峰' }
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        'c3' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '空闲'
                if ($isPeak) { $script:StatusText.Text = '高峰' }
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        'c2' {
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = '· ' + [string]$Status.WeekText }
        }
        'b4' {
            if ($null -ne $script:RateText) {
                $script:RateText.Text = '0.5'
                if ($isPeak) { $script:RateText.Text = '1.0' }
            }
        }
        'c6' {
            if ($null -ne $script:RateText) { $script:RateText.Text = '0.5'; if ($isPeak) { $script:RateText.Text = '1.0' } }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        'e2' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = 'IDLE SAVING'
                if ($isPeak) { $script:StatusText.Text = 'PEAK ACTIVE' }
                if ($Status.IsWeekend) { $script:StatusText.Text = 'WEEKEND ALL-DAY' }
                if ($Status.IsHoliday) {
                    $name = [string]$Status.HolidayName
                    if ([string]::IsNullOrWhiteSpace($name)) { $name = '节假日' }
                    $script:StatusText.Text = 'HOLIDAY · ' + $name
                }
            }
            if ($null -ne $script:RateText) {
                $rate = 'RATE 0.5X'
                if ($isPeak) { $rate = 'RATE 1.0X' }
                if ($Status.IsWeekend -or $Status.IsHoliday) { $rate = '0.5X' }
                $script:RateText.Text = $rate
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = $monthEn + '.' + $now.Day + ' ' + $weekEn }
            if ($null -ne $script:TzText) {
                $script:TzText.Text = 'UTC+8 BJT'
                if ($Status.IsWeekend) { $script:TzText.Text = 'FULL IDLE' }
                if ($Status.IsHoliday) { $script:TzText.Text = 'HOLIDAY LOCK' }
            }
            if (($Status.IsWeekend -or $Status.IsHoliday) -and ($null -ne $script:CountdownText)) {
                $script:CountdownText.Text = 'RESUME PEAK:'
            }
            if ($null -ne $script:CountdownValue) {
                $cdText = [string]$script:CountdownValue.Text
                if ($cdText -match '^(\d+)天\s+(.+)$') {
                    $script:CountdownValue.Text = $matches[1] + 'D ' + $matches[2]
                }
            }
            Update-HudWindowLabels -Status $Status
        }
        'e2b' {
            # 全中文版 HUD：文案全部换成中文，时间更大更粗，进度条按剩余量排空
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '空闲时段'
                if ($isPeak) { $script:StatusText.Text = '高峰时段' }
                if ($Status.IsWeekend) { $script:StatusText.Text = '周末' }
                if ($Status.IsHoliday) {
                    $name = [string]$Status.HolidayName
                    if ([string]::IsNullOrWhiteSpace($name)) { $name = '节假日' }
                    $script:StatusText.Text = '节假日 · ' + $name
                }
                $script:StatusText.FontSize = 13
            }
            if ($null -ne $script:RateText) {
                $rate = '价格 0.5×'
                if ($isPeak) { $rate = '价格 1.0×' }
                if ($Status.IsWeekend -or $Status.IsHoliday) { $rate = '价格 0.5×' }
                $script:RateText.Text = $rate
                $script:RateText.FontSize = 13
            }
            if ($null -ne $script:ClockText) {
                $script:ClockText.FontSize = 40
                $script:ClockText.FontWeight = [System.Windows.FontWeights]::Black
            }
            if ($null -ne $script:DateText) {
                $script:DateText.Text = ([string]$Status.DateText + ' ' + [string]$Status.WeekText).Trim()
                $script:DateText.FontSize = 11
            }
            if ($null -ne $script:TzText) { $script:TzText.Text = '北京时间' }
            if (($Status.IsWeekend -or $Status.IsHoliday) -and ($null -ne $script:CountdownText)) {
                $script:CountdownText.Text = '距周一高峰'
            }
            if ($null -ne $script:CountdownText) { $script:CountdownText.FontSize = 10.5 }
            if ($null -ne $script:CountdownValue) {
                $script:CountdownValue.FontSize = 14
                $script:CountdownValue.FontWeight = [System.Windows.FontWeights]::Bold
            }
            Update-HudWindowLabels -Status $Status -Chinese
            # 夜间 / 周末的左标签不是具体时刻，就不显示「开始 / 结束」小字
            $showTags = [bool]$Status.IsPeakDay -and ([string]$script:WinLeft.Text -match '^\d')
            $tagVis = [System.Windows.Visibility]::Collapsed
            if ($showTags) { $tagVis = [System.Windows.Visibility]::Visible }
            if ($null -ne $script:WinLeftTag) { $script:WinLeftTag.Visibility = $tagVis }
            if ($null -ne $script:WinEndTag) { $script:WinEndTag.Visibility = $tagVis }
        }
        'c4' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '空闲'
                if ($isPeak) { $script:StatusText.Text = '高峰' }
            }
            if ($null -ne $script:RateText) {
                $script:RateText.Text = '0.5'
                if ($isPeak) { $script:RateText.Text = '1.0' }
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        default { }
    }
}

# HUD 的窗口标签：左边起点、中间第几个窗口、右边终点
function Update-HudWindowLabels {
    param($Status, [switch]$Chinese)
    $f = [double]$Status.DayFraction
    $windows = @($Status.PeakWindows)
    $left = '00:00'
    $right = '24:00'
    $mid = 'IDLE WINDOW'
    if ($Chinese) { $mid = '空闲时段' }
    $index = 0

    if (-not [bool]$Status.IsPeakDay) {
        # 周末 / 节假日：整块矩阵常亮，标签改成全天口径
        if ([bool]$Status.IsHoliday) {
            if ($Chinese) {
                $left = '节假日'
                $mid = '全天半价'
                $right = '24 小时'
            } else {
                $left = 'NATIONAL DAY'
                $mid = 'IDLE LOCKED'
                $right = '24H'
            }
        } else {
            if ($Chinese) {
                $left = '周末'
                $mid = '全天半价'
                $right = '24 小时'
            } else {
                $left = 'WEEKEND'
                $mid = 'ALL MATRIX ON'
                $right = '24H IDLE'
            }
        }
        if ($null -ne $script:WinLeft) { $script:WinLeft.Text = $left }
        if ($null -ne $script:WinMid) { $script:WinMid.Text = $mid }
        if ($null -ne $script:WinRight) { $script:WinRight.Text = $right }
        return
    }

    if ($windows.Count -gt 0) {
        foreach ($window in $windows) {
            $a = [double]$window.Start
            $b = [double]$window.End
            if (($f -ge $a) -and ($f -le $b)) {
                $left = Format-HourLabel -Fraction $a
                $right = Format-HourLabel -Fraction $b
                $index = $windows.IndexOf($window) + 1
                if ($Chinese) {
                    $mid = ('高峰窗口 {0}/{1}' -f $index, $windows.Count)
                } else {
                    $mid = ('PEAK WINDOW {0}/{1}' -f $index, $windows.Count)
                }
                break
            }
        }
        if ($mid -eq 'IDLE WINDOW' -or $mid -eq '空闲时段') {
            $prevEnd = 0.0
            $nextStart = 1.0
            foreach ($window in $windows) {
                $a = [double]$window.Start
                $b = [double]$window.End
                if ($b -lt $f) { $prevEnd = $b }
                if (($a -gt $f) -and ($a -lt $nextStart)) { $nextStart = $a }
            }
            if ($prevEnd -le 0.001) {
                $left = '夜间'
                if (-not $Chinese) { $left = 'NIGHT' }
            } else {
                $left = Format-HourLabel -Fraction $prevEnd
            }
            if ($Chinese) {
                $mid = '空闲时段'
                if ($prevEnd -le 0.001) {
                    # 凌晨到第一个高峰之间没有「开始」时刻，保留「下一段」提示
                    $right = '下一段 ' + (Format-HourLabel -Fraction $nextStart)
                } else {
                    # 12:00–14:00 这种空闲间隔：左边是开始，右边直接写结束时刻
                    $right = Format-HourLabel -Fraction $nextStart
                }
            } else {
                $mid = 'OFF-PEAK'
                $right = 'NEXT:' + (Format-HourLabel -Fraction $nextStart)
            }
        }
    }
    if ($null -ne $script:WinLeft) { $script:WinLeft.Text = $left }
    if ($null -ne $script:WinMid) { $script:WinMid.Text = $mid }
    if ($null -ne $script:WinRight) { $script:WinRight.Text = $right }
}

# HUD 上方的「开始 09:00 / 窗口胶囊 / 12:00 结束」视觉：只有 E2B 用新样式，
# E2 切回来时重置成原来的灰色 9px 等宽小字。
function Set-HudLabelStyle {
    param($Spec, $Colors, $Status)
    $isB = [string]$Spec.Key -eq 'e2b'

    if ($null -eq $script:WinLeft -or $null -eq $script:WinRight -or $null -eq $script:WinMid) { return }

    if ($isB) {
        $accent = [string]$Colors.Accent
        $edge = '#59' + $accent.Substring(1)
        $wash = '#14' + $accent.Substring(1)
        foreach ($el in @($script:WinLeft, $script:WinRight)) {
            $el.FontSize = 11
            $el.FontWeight = [System.Windows.FontWeights]::SemiBold
            $el.Foreground = ConvertTo-Brush '#C7D0DA'
        }
        $script:WinMid.FontSize = 9.5
        $script:WinMid.FontWeight = [System.Windows.FontWeights]::SemiBold
        $script:WinMid.Foreground = ConvertTo-Brush $accent
        if ($null -ne $script:WinMidBox) {
            $script:WinMidBox.Background = New-BrushSafe $wash
            $script:WinMidBox.BorderBrush = New-BrushSafe $edge
            $script:WinMidBox.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 1
            $script:WinMidBox.Padding = ConvertTo-Thickness '6,1,6,1'
            $script:WinMidBox.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 3
        }
    } else {
        foreach ($el in @($script:WinLeft, $script:WinRight)) {
            $el.FontSize = 9
            $el.FontWeight = [System.Windows.FontWeights]::Normal
            $el.Foreground = ConvertTo-Brush '#475569'
        }
        $script:WinMid.FontSize = 9
        $script:WinMid.FontWeight = [System.Windows.FontWeights]::Normal
        $script:WinMid.Foreground = ConvertTo-Brush '#475569'
        if ($null -ne $script:WinMidBox) {
            $script:WinMidBox.Background = ConvertTo-Brush '#00000000'
            $script:WinMidBox.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 0
            $script:WinMidBox.Padding = New-Object System.Windows.Thickness -ArgumentList 0
            $script:WinMidBox.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 0
        }
    }

    if ($null -ne $script:WinLeftTag) {
        $script:WinLeftTag.Text = '开始'
        $script:WinLeftTag.FontSize = 8.5
        $script:WinLeftTag.Foreground = ConvertTo-Brush '#7C8798'
    }
    if ($null -ne $script:WinEndTag) {
        $script:WinEndTag.Text = '结束'
        $script:WinEndTag.FontSize = 8.5
        $script:WinEndTag.Foreground = ConvertTo-Brush '#7C8798'
    }
    $showTags = $isB -and [bool]$Status.IsPeakDay
    $tagVis = [System.Windows.Visibility]::Collapsed
    if ($showTags) { $tagVis = [System.Windows.Visibility]::Visible }
    if ($null -ne $script:WinLeftTag) { $script:WinLeftTag.Visibility = $tagVis }
    if ($null -ne $script:WinEndTag) { $script:WinEndTag.Visibility = $tagVis }
}

# ============================ 每秒要动的东西 ============================
function Update-SchemeCustomTick {
    param([object]$Spec, [object]$Status)
    if (($null -eq $Spec) -or ($null -eq $Status)) { return }

    # C4 圆表指针
    $needle = $script:DecorRefs['GaugeNeedle']
    if ($null -ne $needle) {
        $cx = [double]$script:DecorRefs['GaugeCx']
        $cy = [double]$script:DecorRefs['GaugeCy']
        $rIn = [double]$script:DecorRefs['GaugeRInner']
        $rOut = [double]$script:DecorRefs['GaugeROuter']
        $rad = ([double]$Status.DayFraction * 360.0 - 90.0) * [Math]::PI / 180.0
        $needle.X1 = $cx + $rIn * [Math]::Cos($rad)
        $needle.Y1 = $cy + $rIn * [Math]::Sin($rad)
        $needle.X2 = $cx + $rOut * [Math]::Cos($rad)
        $needle.Y2 = $cy + $rOut * [Math]::Sin($rad)
    }

    # E2 / E2B HUD 进度条：每秒重画一次
    if ([string]$Spec.Key -eq 'e2' -or [string]$Spec.Key -eq 'e2b') {
        $canvas = $script:HudProgress
        if ($null -ne $canvas) {
            $colors = Get-SchemeColors -Spec $Spec -Status $Status
            Add-DecorHudProgress -Layer $script:DecorHost -W ([double]$script:Card.ActualWidth) -H ([double]$script:Card.ActualHeight) -Colors $colors -Status $Status -Spec $Spec
            Update-HudWindowLabels -Status $Status -Chinese:([string]$Spec.Key -eq 'e2b')
        }
    }
}

