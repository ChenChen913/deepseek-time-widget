#Requires -Version 5.1
<#
  lib/SchemesPro.ps1 —— 逐方案精修层（对齐 design/ 下的网页原稿）

  为什么单独一个文件
  ------------------
  Schemes.ps1 里的三套通用布局（card / capsule / dial）是「同一套骨架换皮」，
  能覆盖大部分方案，但网页原稿里有 9 个方案的**结构本身**就不一样：
  峰谷示波器有独立波形框、点阵液晶是屏槽 + 双虚线、瑞士分屏是左右两栏、
  新野兽派是黑框块、半谷是斜切双色、K 线是蜡烛区、色块是满版 + 刻度尺、
  HUD 是顶条 + 分段进度、圆表是内环仪表。

  这些用「换皮」做不出来，只能各给一套专属 XAML。本文件就是这 9 套模板
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

# ---------- F1 峰谷示波器：药丸标题 + 独立波形框 + 大钟 + 倒计时条 ----------
$script:LayoutScope = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="14" Margin="12" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#0E1116" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#1E2836" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#F59E0B" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="12,10,12,10">
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
        <Border x:Name="StatusPill" Background="#1AF59E0B" BorderBrush="#5CF59E0B" BorderThickness="1" CornerRadius="7" Padding="9,4" HorizontalAlignment="Left">
          <StackPanel Orientation="Horizontal">
            <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#F59E0B" Visibility="Collapsed" />
            <Rectangle x:Name="StatusSquare" Width="9" Height="9" Fill="#F59E0B" Visibility="Collapsed" />
            <TextBlock x:Name="StatusIcon" Text="↗" FontSize="10" Foreground="#F59E0B" Margin="0,1,5,0" />
            <TextBlock x:Name="StatusText" Text="梁文峰时段" FontSize="12" FontWeight="SemiBold" Foreground="#F59E0B" />
          </StackPanel>
        </Border>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <Border x:Name="RateBadge" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0">
            <TextBlock x:Name="RateText" Text="1.0×" FontSize="15" FontWeight="Bold" Foreground="#F59E0B" />
          </Border>
          <TextBlock x:Name="RateTail" Text="标准" FontSize="10" Foreground="#B45309" Margin="6,2,0,0" VerticalAlignment="Center" />
        </StackPanel>
      </Grid>
      <Border x:Name="ScopeBox" Grid.Row="1" Height="66" Margin="0,8,0,0" CornerRadius="6" Background="#00000000" BorderBrush="#55F59E0B" BorderThickness="1" />
      <Grid Grid.Row="2" Margin="0,8,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="ClockText" Text="10:30:24" FontSize="29" FontWeight="Bold" Foreground="#F8FAFC" />
        <StackPanel x:Name="DateBox" Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="8,0,0,4">
          <TextBlock x:Name="DateIcon" Text="▤" FontSize="10" Foreground="#64748B" Margin="0,1,4,0" />
          <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" Foreground="#94A3B8" />
          <TextBlock x:Name="WeekText" Text="周三" FontSize="11" Foreground="#94A3B8" Margin="5,0,0,0" />
        </StackPanel>
      </Grid>
      <Border Grid.Row="3" Margin="0,8,0,0" CornerRadius="6" Background="#171A20" Padding="9,6">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock x:Name="CdIcon" Text="◷" FontSize="10" Foreground="#64748B" Margin="0,0,5,0" />
            <TextBlock x:Name="CountdownText" Text="距入谷 (0.5×)" FontSize="11" Foreground="#94A3B8" />
            <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#475569" Margin="8,0,0,0" Visibility="Collapsed" />
          </StackPanel>
          <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="12" FontWeight="Bold" Foreground="#F59E0B" VerticalAlignment="Center" />
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

# ---------- E5 点阵液晶：暖棕黑底 + 琥珀字 + 屏槽框 + 双虚线 ----------
$script:LayoutLcd = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="8" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#241A10" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#4A3820" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#FFB020" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="14,12,14,12">
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
        <Border x:Name="StatusPill" Background="#00000000" BorderBrush="#8A6A2E" BorderThickness="1" CornerRadius="0" Padding="8,3" HorizontalAlignment="Left">
          <StackPanel Orientation="Horizontal">
            <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#FFB020" Visibility="Collapsed" />
            <Rectangle x:Name="StatusSquare" Width="9" Height="9" Fill="#FFB020" Visibility="Collapsed" />
            <TextBlock x:Name="StatusText" Text="[ PEAK MODE ]" FontSize="12" Foreground="#E8B961" FontFamily="Consolas, Cascadia Mono" />
          </StackPanel>
        </Border>
        <Border x:Name="RateBadge" Grid.Column="1" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="RATE: 1.0X" FontSize="12" Foreground="#C08A2E" FontFamily="Consolas, Cascadia Mono" />
        </Border>
      </Grid>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="40" FontWeight="Bold" Foreground="#FFD166" FontFamily="Consolas, Cascadia Mono" Margin="0,6,0,0" HorizontalAlignment="Center" />
      <StackPanel Grid.Row="2" Margin="0,4,0,0">
        <Canvas Height="1" ClipToBounds="True">
          <Line X1="0" Y1="0" X2="900" Y2="0" Stroke="#4AFFB020" StrokeThickness="1" StrokeDashArray="1.5 3" />
        </Canvas>
        <Grid Margin="0,6,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <TextBlock x:Name="DateText" Text="10-28 WED" FontSize="12" Foreground="#C08A2E" FontFamily="Consolas, Cascadia Mono" />
          <TextBlock x:Name="WeekText" Text="" FontSize="12" Foreground="#C08A2E" Visibility="Collapsed" />
          <TextBlock x:Name="TzText" Grid.Column="1" Text="BJT UTC+8" FontSize="12" Foreground="#C08A2E" FontFamily="Consolas, Cascadia Mono" HorizontalAlignment="Right" />
        </Grid>
      </StackPanel>
      <StackPanel Grid.Row="3" Margin="0,8,0,0">
        <Canvas Height="1" ClipToBounds="True">
          <Line X1="0" Y1="0" X2="900" Y2="0" Stroke="#4AFFB020" StrokeThickness="1" StrokeDashArray="1.5 3" />
        </Canvas>
        <Grid Margin="0,7,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock x:Name="CountdownText" Text="NEXT IDLE:" FontSize="12" Foreground="#E8B961" FontFamily="Consolas, Cascadia Mono" />
            <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#8A6A2E" Margin="8,0,0,0" Visibility="Collapsed" />
          </StackPanel>
          <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="13" FontWeight="Bold" Foreground="#FFD166" FontFamily="Consolas, Cascadia Mono" VerticalAlignment="Center" />
        </Grid>
      </StackPanel>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#FFB020" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#FFB020" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFD166" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- E4 双色瑞士分屏：左侧实色铭牌（四行）+ 右侧黑曜石 ----------
$script:LayoutSplit = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="0" Margin="10" BorderThickness="0">
  <Border.Background><SolidColorBrush Color="#141414" /></Border.Background>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#F59E0B" /></Rectangle.Fill>
    </Rectangle>
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="96" />
        <ColumnDefinition Width="*" />
      </Grid.ColumnDefinitions>
      <Border x:Name="PlateBox" Grid.Column="0" Background="#C2600A">
        <Grid Margin="0,16,0,14">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
          </Grid.RowDefinitions>
          <StackPanel Grid.Row="0" HorizontalAlignment="Center">
            <TextBlock x:Name="PlateStatus" Text="高峰" FontSize="20" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" />
            <TextBlock x:Name="PlateStatusEn" Text="PEAK" FontSize="10" Foreground="#FFE0BF" HorizontalAlignment="Center" Margin="0,5,0,0" />
          </StackPanel>
          <TextBlock x:Name="PlateRate" Grid.Row="1" Text="1.0×" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center" />
          <TextBlock x:Name="PlateDay" Grid.Row="2" Text="工作日" FontSize="11" Foreground="#FFE0BF" HorizontalAlignment="Center" />
        </Grid>
      </Border>
      <Grid x:Name="Body" Grid.Column="1" Margin="16,14,16,12">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto" />
          <RowDefinition Height="*" />
          <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Orientation="Horizontal">
          <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#F59E0B" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="9" Height="9" Fill="#F59E0B" Visibility="Collapsed" />
          <TextBlock x:Name="StatusText" Text="" FontSize="11" Foreground="#9CA3AF" Visibility="Collapsed" />
          <TextBlock x:Name="WeekText" Text="周三" FontSize="11" Foreground="#9CA3AF" Visibility="Collapsed" />
          <TextBlock x:Name="DateText" Text="10月28日 周三 · 北京时间" FontSize="11" Foreground="#9CA3AF" />
        </StackPanel>
        <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="34" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center" />
        <Border x:Name="CdBox" Grid.Row="2" CornerRadius="6" Background="#262626" Padding="10,7">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*" />
              <ColumnDefinition Width="Auto" />
            </Grid.ColumnDefinitions>
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
              <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="12" Foreground="#9CA3AF" />
              <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#6B7280" Margin="8,0,0,0" Visibility="Collapsed" />
            </StackPanel>
            <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="12" FontWeight="Bold" Foreground="#F5A623" VerticalAlignment="Center" />
          </Grid>
        </Border>
        <Border x:Name="RateBadge" Grid.Row="2" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0" Visibility="Collapsed">
          <TextBlock x:Name="RateText" Text="1.0×" FontSize="10" Foreground="#F5A623" />
        </Border>
      </Grid>
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

# ---------- E3 新野兽派：直角白底 + 2px 黑框 + 黑底白字块 + 底部方框条 ----------
$script:LayoutBrutal = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="0" Margin="12" BorderThickness="2">
  <Border.Background><SolidColorBrush Color="#FFFFFF" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#111111" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#111111" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="14,12,14,12">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
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
        <Border x:Name="StatusPill" Background="#F5A623" BorderThickness="0" CornerRadius="0" Padding="9,4" HorizontalAlignment="Left">
          <StackPanel Orientation="Horizontal">
            <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#FFFFFF" Visibility="Collapsed" />
            <Rectangle x:Name="StatusSquare" Width="9" Height="9" Fill="#FFFFFF" Visibility="Collapsed" />
            <TextBlock x:Name="StatusText" Text="高峰时段 PEAK" FontSize="12" FontWeight="Bold" Foreground="#111111" />
          </StackPanel>
        </Border>
        <Border x:Name="RateBadge" Grid.Column="1" Background="#FFFFFF" BorderBrush="#111111" BorderThickness="1.5" CornerRadius="0" Padding="9,4" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="1.0×" FontSize="12" FontWeight="Bold" Foreground="#111111" />
        </Border>
      </Grid>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="38" FontWeight="Black" Foreground="#111111" Margin="0,6,0,0" />
      <Grid Grid.Row="2" Margin="0,4,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal">
          <TextBlock x:Name="DateText" Text="10月28日" FontSize="13" FontWeight="Bold" Foreground="#111111" />
          <TextBlock x:Name="WeekText" Text="周三" FontSize="13" FontWeight="Bold" Foreground="#111111" Margin="6,0,0,0" />
        </StackPanel>
        <TextBlock x:Name="TzText" Grid.Column="1" Text="北京时间" FontSize="13" FontWeight="Bold" Foreground="#111111" HorizontalAlignment="Right" />
      </Grid>
      <Rectangle x:Name="BrutalRule" Grid.Row="3" Height="2" Fill="#111111" Margin="0,8,0,0" />
      <Border x:Name="CdBox" Grid.Row="4" BorderBrush="#111111" BorderThickness="1.5" Background="#F5F5F5" Padding="9,6" Margin="0,9,0,0">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock x:Name="CountdownText" Text="距空闲倒计时" FontSize="12" FontWeight="SemiBold" Foreground="#111111" />
            <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#52525B" Margin="8,0,0,0" Visibility="Collapsed" />
          </StackPanel>
          <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="12" FontWeight="Bold" Foreground="#C2410C" VerticalAlignment="Center" />
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

# ---------- D6 半谷：整块斜切双色 + 细网格 + 细体大钟 + 今日峰谷时长 ----------
$script:LayoutHalf = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="14" Margin="12" BorderThickness="0">
  <Border.Background><SolidColorBrush Color="#E4552E" /></Border.Background>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#FFFFFF" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="16,14,16,12">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
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
        <StackPanel Orientation="Horizontal">
          <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#FFFFFF" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="9" Height="9" Fill="#FFFFFF" Visibility="Collapsed" />
          <TextBlock x:Name="StatusIcon" Text="∿" FontSize="12" Foreground="#FFFFFF" Margin="0,0,5,0" />
          <TextBlock x:Name="StatusText" Text="梁文峰时段" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" />
        </StackPanel>
        <Border x:Name="RateBadge" Grid.Column="1" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="1.0×" FontSize="14" FontWeight="SemiBold" Foreground="#FFFFFF" />
        </Border>
      </Grid>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="38" FontWeight="Light" Foreground="#FFFFFF" Margin="0,4,0,0" />
      <StackPanel x:Name="DateBox" Grid.Row="2" Orientation="Horizontal" Margin="0,2,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="12" Foreground="#FFE8E0" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="12" Foreground="#FFE8E0" Margin="6,0,0,0" />
      </StackPanel>
      <Grid Grid.Row="3" Margin="0,12,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="CountdownText" Text="距梁文谷" FontSize="12" Foreground="#FFF0EA" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#F3C4B4" Margin="8,0,0,0" Visibility="Collapsed" />
        </StackPanel>
        <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" Margin="8,0,0,0" VerticalAlignment="Center" />
      </Grid>
      <StackPanel Grid.Row="4" Orientation="Horizontal" Margin="0,10,0,0">
        <Rectangle x:Name="HalfRule" Width="26" Height="2" Fill="#FFFFFF" VerticalAlignment="Center" />
        <TextBlock x:Name="HalfFootText" Text="今日 峰 7h · 谷 17h" FontSize="11" Foreground="#FFFFFF" Margin="8,0,0,0" />
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

# ---------- D3 K 线：橙红标题 + 细体大钟 + 蜡烛区 + 底部倒计时 ----------
$script:LayoutCandle = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="12" Margin="12" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#131313" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#262626" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#E4552E" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="14,12,14,10">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
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
        <StackPanel Orientation="Horizontal">
          <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#E4552E" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="9" Height="9" Fill="#E4552E" Visibility="Collapsed" />
          <TextBlock x:Name="StatusIcon" Text="∿" FontSize="12" Foreground="#E4552E" Margin="0,0,5,0" />
          <TextBlock x:Name="StatusText" Text="梁文峰时段" FontSize="13" FontWeight="Bold" Foreground="#E4552E" />
        </StackPanel>
        <Border x:Name="RateBadge" Grid.Column="1" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="1.0×" FontSize="14" FontWeight="SemiBold" Foreground="#E4552E" />
        </Border>
      </Grid>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="33" FontWeight="Light" Foreground="#F5F5F5" Margin="0,2,0,0" />
      <StackPanel x:Name="DateBox" Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" Foreground="#8A8A8A" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="11" Foreground="#8A8A8A" Margin="6,0,0,0" />
      </StackPanel>
      <Border x:Name="CandleBox" Grid.Row="3" Height="70" Margin="0,6,0,0" Background="#00000000" />
      <Grid Grid.Row="4" Margin="0,8,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="CountdownText" Text="距梁文谷" FontSize="11" Foreground="#8A8A8A" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#5A5A5A" Margin="8,0,0,0" Visibility="Collapsed" />
        </StackPanel>
        <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="12" FontWeight="Bold" Foreground="#F5F5F5" Margin="8,0,0,0" VerticalAlignment="Center" />
      </Grid>
    </Grid>
    <Grid Visibility="Collapsed">
      <Canvas x:Name="TimelineCanvas" Height="8">
        <Rectangle x:Name="TimelineTrack" Height="6" Fill="#33FFFFFF" />
        <Rectangle x:Name="PeakSegment1" Height="6" Fill="#E4552E" />
        <Rectangle x:Name="PeakSegment2" Height="6" Fill="#E4552E" />
        <Rectangle x:Name="TimeMarker" Width="2" Height="8" Fill="#FFFFFF" />
      </Canvas>
    </Grid>
  </Grid>
</Border>
'@

# ---------- C6 色块：满版琥珀 + 方块标记 + 刻度尺 ----------
$script:LayoutSolid = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="12" Margin="12" BorderThickness="0">
  <Border.Background><SolidColorBrush Color="#E8A33D" /></Border.Background>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#111111" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="16,12,16,10">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
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
        <StackPanel Orientation="Horizontal">
          <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#111111" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="8" Height="8" Fill="#111111" VerticalAlignment="Center" />
          <TextBlock x:Name="StatusText" Text="高峰时段" FontSize="16" FontWeight="Bold" Foreground="#111111" Margin="7,0,0,0" />
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
          <Border x:Name="RateBadge" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0">
            <TextBlock x:Name="RateText" Text="1.0" FontSize="17" FontWeight="Bold" Foreground="#111111" />
          </Border>
          <TextBlock x:Name="RateTail" Text="×" FontSize="11" Foreground="#3A2A12" Margin="1,0,0,2" VerticalAlignment="Bottom" />
        </StackPanel>
      </Grid>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="36" FontWeight="Bold" Foreground="#111111" Margin="0,2,0,0" />
      <StackPanel x:Name="DateBox" Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="12" Foreground="#6B4413" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="12" Foreground="#6B4413" Margin="6,0,0,0" />
      </StackPanel>
      <Border x:Name="ScaleBox" Grid.Row="3" Height="22" Margin="0,8,0,0" Background="#00000000" />
      <Grid Grid.Row="4" Margin="0,6,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="11" Foreground="#6B4413" />
          <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#8A5E1E" Margin="8,0,0,0" Visibility="Collapsed" />
        </StackPanel>
        <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="12" FontWeight="Bold" Foreground="#111111" VerticalAlignment="Center" />
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

# ---------- E2 工业级 HUD：顶部琥珀条 + 描边框 + 分段进度 ----------
$script:LayoutHud = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="4" Margin="12" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#111318" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#242833" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="HudTopBar" Height="3" VerticalAlignment="Top" Fill="#FFB020" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#FFB020" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" Margin="14,13,14,12">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
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
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#FFB020" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="9" Height="9" Fill="#FFB020" Visibility="Collapsed" />
          <TextBlock x:Name="StatusIcon" Text="▲" FontSize="9" Foreground="#FFB020" Margin="0,1,6,0" />
          <TextBlock x:Name="StatusText" Text="PEAK ACTIVE" FontSize="12" FontWeight="Bold" Foreground="#FFB020" FontFamily="Consolas, Cascadia Mono" />
        </StackPanel>
        <Border x:Name="RateBadge" Grid.Column="1" Background="#00000000" BorderBrush="#FFB020" BorderThickness="1" CornerRadius="0" Padding="7,3" VerticalAlignment="Center">
          <TextBlock x:Name="RateText" Text="RATE 1.0X" FontSize="11" Foreground="#FFB020" FontFamily="Consolas, Cascadia Mono" />
        </Border>
      </Grid>
      <Canvas Grid.Row="1" Height="1" Margin="0,8,0,0" ClipToBounds="True">
        <Line X1="0" Y1="0" X2="900" Y2="0" Stroke="#3AFFB020" StrokeThickness="1" StrokeDashArray="1.5 3" />
      </Canvas>
      <Grid Grid.Row="2" Margin="0,8,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="ClockText" Text="10:30:24" FontSize="30" FontWeight="Bold" Foreground="#F1F5F9" FontFamily="Consolas, Cascadia Mono" VerticalAlignment="Center" />
        <StackPanel Grid.Column="1" VerticalAlignment="Center">
          <TextBlock x:Name="DateText" Text="OCT. 28 WED" FontSize="10" Foreground="#6B7C93" FontFamily="Consolas, Cascadia Mono" HorizontalAlignment="Right" />
          <TextBlock x:Name="WeekText" Text="" FontSize="10" Foreground="#6B7C93" Visibility="Collapsed" />
          <TextBlock x:Name="TzText" Text="UTC+8 BJT" FontSize="10" Foreground="#6B7C93" FontFamily="Consolas, Cascadia Mono" HorizontalAlignment="Right" Margin="0,4,0,0" />
        </StackPanel>
      </Grid>
      <Grid Grid.Row="3" Margin="0,10,0,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto" />
          <ColumnDefinition Width="*" />
          <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="WinLeft" Text="09:00" FontSize="9.5" Foreground="#6B7C93" FontFamily="Consolas, Cascadia Mono" />
        <TextBlock x:Name="WinMid" Grid.Column="1" Text="PEAK WINDOW 1/2" FontSize="9.5" Foreground="#6B7C93" FontFamily="Consolas, Cascadia Mono" HorizontalAlignment="Center" />
        <TextBlock x:Name="WinRight" Grid.Column="2" Text="12:00" FontSize="9.5" Foreground="#6B7C93" FontFamily="Consolas, Cascadia Mono" HorizontalAlignment="Right" />
      </Grid>
      <Canvas x:Name="HudProgress" Grid.Row="4" Height="8" Margin="0,5,0,0" ClipToBounds="True" />
      <Border x:Name="CdBox" Grid.Row="5" BorderBrush="#242833" BorderThickness="1" CornerRadius="3" Background="#0C0E12" Padding="9,6" Margin="0,9,0,0">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock x:Name="CountdownText" Text="NEXT IDLE IN:" FontSize="11" Foreground="#8A9BB4" FontFamily="Consolas, Cascadia Mono" />
            <TextBlock x:Name="HintText" Text="拖动 / 右键" FontSize="9" Foreground="#4B5563" Margin="8,0,0,0" Visibility="Collapsed" />
          </StackPanel>
          <TextBlock x:Name="CountdownValue" Grid.Column="1" Text="01:29:36" FontSize="12" FontWeight="Bold" Foreground="#FFB020" FontFamily="Consolas, Cascadia Mono" VerticalAlignment="Center" />
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
$script:LayoutGauge = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="Card" CornerRadius="150" Margin="10" BorderThickness="1">
  <Border.Background><SolidColorBrush Color="#12161D" /></Border.Background>
  <Border.BorderBrush><SolidColorBrush Color="#1E242E" /></Border.BorderBrush>
  <Grid x:Name="CardRoot">
    <Canvas x:Name="DecorHost" IsHitTestVisible="False" ClipToBounds="True" />
    <Rectangle x:Name="AccentBar" Width="3" HorizontalAlignment="Left" Visibility="Collapsed">
      <Rectangle.Fill><SolidColorBrush Color="#FFB020" /></Rectangle.Fill>
    </Rectangle>
    <Grid x:Name="Body" VerticalAlignment="Center" HorizontalAlignment="Center" Margin="0,-6,0,6">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
      </Grid.RowDefinitions>
      <Border x:Name="StatusPill" Grid.Row="0" Background="#FFB020" BorderThickness="0" CornerRadius="4" Padding="8,3" HorizontalAlignment="Center">
        <StackPanel Orientation="Horizontal">
          <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#1A1A1A" Visibility="Collapsed" />
          <Rectangle x:Name="StatusSquare" Width="9" Height="9" Fill="#1A1A1A" Visibility="Collapsed" />
          <TextBlock x:Name="StatusText" Text="• 高峰" FontSize="11" FontWeight="Bold" Foreground="#1A1A1A" />
        </StackPanel>
      </Border>
      <TextBlock x:Name="ClockText" Grid.Row="1" Text="10:30:24" FontSize="30" FontWeight="Bold" Foreground="#F1F5F9" FontFamily="Consolas, Cascadia Mono" HorizontalAlignment="Center" Margin="0,8,0,0" />
      <Border x:Name="RateBadge" Grid.Row="2" Background="#00000000" BorderThickness="0" CornerRadius="0" Padding="0" HorizontalAlignment="Center" Margin="0,2,0,0">
        <TextBlock x:Name="RateText" Text="1.0×" FontSize="15" FontWeight="Bold" Foreground="#FFB020" />
      </Border>
      <StackPanel x:Name="DateBox" Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,6,0,0">
        <TextBlock x:Name="DateText" Text="10月28日" FontSize="10" Foreground="#8A94A6" />
        <TextBlock x:Name="WeekText" Text="周三" FontSize="10" Foreground="#8A94A6" Margin="5,0,0,0" />
      </StackPanel>
      <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,2,0,0">
        <TextBlock x:Name="CountdownText" Text="距空闲" FontSize="9.5" Foreground="#6B7C93" />
        <TextBlock x:Name="CountdownValue" Text="01:29:36" FontSize="9.5" Foreground="#C9D2DF" Margin="6,0,0,0" />
        <TextBlock x:Name="HintText" Text="" FontSize="9" Foreground="#4B5563" Visibility="Collapsed" />
      </StackPanel>
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
# 网页稿的波形区是一个带描边的框，框里是「两个圆峰 + 中间谷」的曲线，
# 峰顶有菱形标记 + 引线 + PEAK 标签，当前时刻一条竖虚线。
function Add-DecorScope {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $box = Get-ElementBox -Element $script:ScopeBox -FallbackW ($W - 24) -FallbackH 58
    $bx = [double]$box[0]; $by = [double]$box[1]
    $bw = [double]$box[2]; $bh = [double]$box[3]
    if ($bw -lt 20) { return }

    $accent = [string]$Colors.Accent
    $padX = 10.0
    $innerW = $bw - $padX * 2
    $baseY = $by + $bh - 8.0
    $amp = $bh - 20.0
    if ($amp -lt 6) { $amp = 6 }

    # 横向虚线网格
    for ($i = 1; $i -le 2; $i++) {
        $gy = $by + $bh * ($i / 3.0)
        $grid = New-LineShape -X1 ($bx + 4) -Y1 $gy -X2 ($bx + $bw - 4) -Y2 $gy -Color '#18FFFFFF' -Thickness 1
        $grid.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection
        [void]$grid.StrokeDashArray.Add(3.0)
        [void]$grid.StrokeDashArray.Add(4.0)
        [void]$Layer.Children.Add($grid)
    }

    $peaks = Get-PeakShape -Status $Status

    # 曲线：两个高斯峰叠起来，峰位跟着真实窗口走，形状是圆的而不是方平台
    $steps = 120
    $figure = New-Object System.Windows.Media.PathFigure
    for ($i = 0; $i -le $steps; $i++) {
        $f = $i / [double]$steps
        $value = 0.0
        foreach ($peak in $peaks) {
            # sigma 给大一点，峰才圆；太小会变成尖刺（网页稿是两个宽圆峰）
            $sigma = [Math]::Max(0.062, $peak.Half / 1.05)
            $d = $f - $peak.Center
            $value += [Math]::Exp(-($d * $d) / (2.0 * $sigma * $sigma))
        }
        if ($value -gt 1.0) { $value = 1.0 }
        # 抬一点基线，曲线才不会在空闲段贴着框底走直线（网页稿是连绵起伏的）
        $value = 0.16 + 0.84 * $value
        $x = $bx + $padX + $f * $innerW
        $y = $baseY - $value * $amp
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
    $glow.Stroke = New-BrushSafe $accent 0.22
    $glow.StrokeThickness = 7
    $glow.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
    [void]$Layer.Children.Add($glow)

    $path = New-Object System.Windows.Shapes.Path
    $path.Data = $geometry
    $path.Stroke = New-BrushSafe $accent 0.95
    $path.StrokeThickness = 2
    $path.StrokeLineJoin = [System.Windows.Media.PenLineJoin]::Round
    [void]$Layer.Children.Add($path)

    # 当前时刻竖虚线
    $nowX = $bx + $padX + [double]$Status.DayFraction * $innerW
    $cursor = New-LineShape -X1 $nowX -Y1 ($by + 4) -X2 $nowX -Y2 ($by + $bh - 4) -Color '#40FFFFFF' -Thickness 1
    $cursor.StrokeDashArray = New-Object System.Windows.Media.DoubleCollection
    [void]$cursor.StrokeDashArray.Add(2.0)
    [void]$cursor.StrokeDashArray.Add(3.0)
    [void]$Layer.Children.Add($cursor)

    # 第一个峰顶：菱形标记 + 短引线 + PEAK 标签
    if ($peaks.Count -ge 1) {
        $peak = $peaks[0]
        $px = $bx + $padX + $peak.Center * $innerW
        $py = $baseY - $amp
        $diamond = New-Object System.Windows.Shapes.Polygon
        $pts = New-Object System.Windows.Media.PointCollection
        [void]$pts.Add((New-Object System.Windows.Point -ArgumentList $px, ($py - 5)))
        [void]$pts.Add((New-Object System.Windows.Point -ArgumentList ($px + 4), $py))
        [void]$pts.Add((New-Object System.Windows.Point -ArgumentList $px, ($py + 5)))
        [void]$pts.Add((New-Object System.Windows.Point -ArgumentList ($px - 4), $py))
        $diamond.Points = $pts
        $diamond.Fill = New-BrushSafe '#FFFFFF'
        [void]$Layer.Children.Add($diamond)

        $tagW = 56.0
        $tagH = 17.0
        $tagX = $px + 6
        if (($tagX + $tagW) -gt ($bx + $bw - 4)) { $tagX = $px - $tagW - 6 }
        $tagY = $py + 9
        if (($tagY + $tagH) -gt ($by + $bh - 3)) { $tagY = $py - $tagH - 9 }
        $tag = New-Object System.Windows.Controls.Border
        $tag.Width = $tagW
        $tag.Height = $tagH
        $tag.Background = New-BrushSafe '#E6101216'
        $tag.BorderBrush = New-BrushSafe $accent 0.8
        $tag.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 1
        $tag.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 2
        $tagText = New-Object System.Windows.Controls.TextBlock
        $tagText.Text = 'PEAK 1.0×'
        $tagText.FontSize = 8.0
        $tagText.Foreground = New-BrushSafe $accent
        $tagText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $tagText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $tag.Child = $tagText
        [System.Windows.Controls.Canvas]::SetLeft($tag, $tagX)
        [System.Windows.Controls.Canvas]::SetTop($tag, $tagY)
        [void]$Layer.Children.Add($tag)

        $leader = New-LineShape -X1 $px -Y1 ($py + 5) -X2 $px -Y2 $tagY -Color $accent -Thickness 1
        $leader.Opacity = 0.6
        [void]$Layer.Children.Add($leader)
    }
}

# ============================ D3 K 线 ============================
# 网页稿：24 根柱子，高峰是满高橙红粗柱，空闲是贴底的暗绿矮块，
# 当前那一根描白边并略高一点。
function Add-DecorKline {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $box = Get-ElementBox -Element $script:CandleBox -FallbackW ($W - 28) -FallbackH 56
    $bx = [double]$box[0]; $by = [double]$box[1]
    $bw = [double]$box[2]; $bh = [double]$box[3]
    if ($bw -lt 20) { return }

    $padX = 2.0
    $innerW = $bw - $padX * 2
    $baseY = $by + $bh - 2.0
    $slot = $innerW / 24.0
    $barW = [Math]::Max(4.0, $slot - 3.0)
    $peakColor = '#E4552E'
    $idleColor = '#2E6B5E'
    $currentHour = [int][Math]::Floor([double]$Status.DayFraction * 24.0)
    if ($currentHour -gt 23) { $currentHour = 23 }

    for ($h = 0; $h -lt 24; $h++) {
        $rate = Get-DayRate -Fraction (($h + 0.5) / 24.0) -Windows $Status.PeakWindows -Soft 0.0001
        $isPeak = ($rate -gt 0.5)
        $x = $bx + $padX + $h * $slot + ($slot - $barW) / 2.0
        if ($isPeak) {
            $barH = $bh - 6.0
            $color = $peakColor
        } else {
            $barH = 18.0
            $color = $idleColor
        }
        if ($h -eq $currentHour) { $barH = $barH + 3.0 }
        $bar = New-RectShape -X $x -Y ($baseY - $barH) -W $barW -H $barH -Color $color -Radius 0
        $bar.Opacity = 0.95
        [void]$Layer.Children.Add($bar)
        if ($h -eq $currentHour) {
            $bar.Stroke = New-BrushSafe '#FFFFFF'
            $bar.StrokeThickness = 1.5
        }
    }
}

# ============================ D6 半谷 ============================
# 网页稿：橙底 + 右侧青绿斜切块 + 细网格线；斜切角度固定，不跟峰时长走。
function Add-DecorHalfSplit {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $topX = $W * 0.62
    $bottomX = $W * 0.55
    $points = New-Object System.Windows.Media.PointCollection
    [void]$points.Add((New-Object System.Windows.Point -ArgumentList $topX, 0))
    [void]$points.Add((New-Object System.Windows.Point -ArgumentList $W, 0))
    [void]$points.Add((New-Object System.Windows.Point -ArgumentList $W, $H))
    [void]$points.Add((New-Object System.Windows.Point -ArgumentList $bottomX, $H))
    $polygon = New-Object System.Windows.Shapes.Polygon
    $polygon.Points = $points
    $polygon.Fill = New-BrushSafe '#2AB5A0'
    [void]$Layer.Children.Add($polygon)

    # 细网格：40px 一格，白色 7%
    $x = 0.0
    while ($x -lt $W) {
        $line = New-LineShape -X1 $x -Y1 0 -X2 $x -Y2 $H -Color '#12FFFFFF' -Thickness 1
        [void]$Layer.Children.Add($line)
        $x += 40
    }
    $y = 0.0
    while ($y -lt $H) {
        $line = New-LineShape -X1 0 -Y1 $y -X2 $W -Y2 $y -Color '#12FFFFFF' -Thickness 1
        [void]$Layer.Children.Add($line)
        $y += 40
    }
}

# ============================ C6 色块 ============================
# 网页稿：日期下面一条刻度尺（1 小时一格），高峰段压深色块，
# 当前时刻一个黑圆点 + 竖线指针。
function Add-DecorScaleBar {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $box = Get-ElementBox -Element $script:ScaleBox -FallbackW ($W - 32) -FallbackH 22
    $bx = [double]$box[0]; $by = [double]$box[1]
    $bw = [double]$box[2]; $bh = [double]$box[3]
    if ($bw -lt 20) { return }

    $padX = 0.0
    $innerW = $bw - $padX * 2
    $baseY = $by + $bh - 4.0
    $ink = '#C1111111'

    $rule = New-LineShape -X1 ($bx + $padX) -Y1 $baseY -X2 ($bx + $padX + $innerW) -Y2 $baseY -Color '#55111111' -Thickness 1
    [void]$Layer.Children.Add($rule)

    for ($h = 0; $h -le 24; $h++) {
        $tx = $bx + $padX + $h / 24.0 * $innerW
        $len = 4.0
        if (($h % 6) -eq 0) { $len = 7.0 }
        $tick = New-LineShape -X1 $tx -Y1 ($baseY - $len) -X2 $tx -Y2 $baseY -Color '#77111111' -Thickness 1
        [void]$Layer.Children.Add($tick)
    }

    foreach ($window in $Status.PeakWindows) {
        $sx = $bx + $padX + [double]$window.Start * $innerW
        $ex = $bx + $padX + [double]$window.End * $innerW
        $band = New-RectShape -X $sx -Y ($baseY - 13) -W ($ex - $sx) -H 11 -Color '#55111111'
        [void]$Layer.Children.Add($band)
    }

    $nowX = $bx + $padX + [double]$Status.DayFraction * $innerW
    $stem = New-LineShape -X1 $nowX -Y1 ($baseY - 17) -X2 $nowX -Y2 ($baseY + 1) -Color '#111111' -Thickness 2
    [void]$Layer.Children.Add($stem)
    $knob = New-Object System.Windows.Shapes.Ellipse
    $knob.Width = 7; $knob.Height = 7
    $knob.Fill = New-BrushSafe '#111111'
    [System.Windows.Controls.Canvas]::SetLeft($knob, ($nowX - 3.5))
    [System.Windows.Controls.Canvas]::SetTop($knob, ($baseY - 20.5))
    [void]$Layer.Children.Add($knob)
}

# ============================ C4 圆表 ============================
# 网页稿：最外圈是细刻度（每半小时一格），里面一圈粗环当轨道，
# 高峰窗口在轨道上画成琥珀弧，当前时刻一根白色斜指针。
function Add-DecorGauge {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $cx = $W / 2.0
    $cy = $H / 2.0
    $outer = [Math]::Min($W, $H) / 2.0 - 6.0
    $trackR = $outer * 0.645
    $trackW = [Math]::Max(12.0, $outer * 0.115)
    $accent = [string]$Colors.Accent

    # 外圈刻度：48 格，每 3 小时加长
    for ($i = 0; $i -lt 48; $i++) {
        $angle = $i / 48.0 * 360.0
        $rad = ($angle - 90.0) * [Math]::PI / 180.0
        $length = 6.0
        $opacity = '#4AFFFFFF'
        if (($i % 6) -eq 0) { $length = 11.0; $opacity = '#8AFFFFFF' }
        $r1 = $outer - $length
        $line = New-LineShape -X1 ($cx + $r1 * [Math]::Cos($rad)) -Y1 ($cy + $r1 * [Math]::Sin($rad)) `
            -X2 ($cx + $outer * [Math]::Cos($rad)) -Y2 ($cy + $outer * [Math]::Sin($rad)) -Color $opacity -Thickness 1
        [void]$Layer.Children.Add($line)
    }

    # 粗环轨道
    $track = New-Object System.Windows.Shapes.Ellipse
    $track.Width = $trackR * 2
    $track.Height = $trackR * 2
    $track.Stroke = New-BrushSafe '#3A3F47'
    $track.StrokeThickness = $trackW
    $track.Fill = New-BrushSafe '#00000000'
    [System.Windows.Controls.Canvas]::SetLeft($track, ($cx - $trackR))
    [System.Windows.Controls.Canvas]::SetTop($track, ($cy - $trackR))
    [void]$Layer.Children.Add($track)

    # 高峰弧
    foreach ($window in $Status.PeakWindows) {
        $startAngle = [double]$window.Start * 360.0
        $endAngle = [double]$window.End * 360.0
        $arc = New-Object System.Windows.Shapes.Path
        $arc.Data = New-ArcGeometry -Cx $cx -Cy $cy -Radius $trackR -StartAngle $startAngle -EndAngle $endAngle
        $arc.Stroke = New-BrushSafe $accent
        $arc.StrokeThickness = $trackW
        [void]$Layer.Children.Add($arc)
    }

    # 当前时刻：白色斜指针（从环外侧指向环内）
    $needle = New-LineShape -X1 $cx -Y1 ($cy - $trackR - 18) -X2 $cx -Y2 ($cy - $trackR - 2) -Color '#FFFFFF' -Thickness 2.5
    [void]$Layer.Children.Add($needle)

    $script:DecorRefs['GaugeNeedle'] = $needle
    $script:DecorRefs['GaugeCx'] = $cx
    $script:DecorRefs['GaugeCy'] = $cy
    $script:DecorRefs['GaugeR'] = $trackR
}

# ============================ E2 HUD 分段进度 ============================
# 网页稿是 8 段发光块。这里按「当前所处那一段的进度」点亮，
# 每秒重算，所以进度条是活的。
function Add-DecorHudProgress {
    param($Layer, [double]$W, [double]$H, $Colors, $Status)
    $canvas = $script:HudProgress
    if ($null -eq $canvas) { return }

    $width = [double]$canvas.ActualWidth
    if ($width -lt 20) { $width = $W - 28 }
    $count = 8
    $gap = 3.0
    $segW = ($width - $gap * ($count - 1)) / $count
    if ($segW -lt 3) { return }
    $lit = Get-HudSegmentCount -Status $Status
    $accent = [string]$Colors.Accent

    # 段数 / 段宽 / 颜色都没变就什么都不用做，避免每秒重建一批 Rectangle 造成闪
    $cacheKey = ('{0}|{1}|{2:0.0}|{3}' -f $lit, $count, $segW, $accent)
    if ([string]$script:HudCacheKey -eq $cacheKey) { return }

    $canvas.Children.Clear()
    for ($i = 0; $i -lt $count; $i++) {
        $seg = New-RectShape -X ($i * ($segW + $gap)) -Y 0 -W $segW -H 8 -Color '#1C2333' -Radius 1
        if ($i -lt $lit) {
            $seg.Fill = New-BrushSafe $accent
            try { $seg.Effect = New-CardShadow -Blur 6 -Depth 0 -Opacity 0.55 } catch { }
        }
        [void]$canvas.Children.Add($seg)
    }
    $script:HudCacheKey = $cacheKey
}

# 点亮几段：floor(进度 * 8) + 1，最少 1 段
function Get-HudSegmentCount {
    param($Status)
    $f = [double]$Status.DayFraction
    $progress = Get-PhaseProgress -Fraction $f -Status $Status
    $count = [int][Math]::Floor($progress * 8.0) + 1
    if ($count -lt 1) { $count = 1 }
    if ($count -gt 8) { $count = 8 }
    return $count
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
                $script:StatusText.Text = '梁文峰时段'
                if (-not $isPeak) { $script:StatusText.Text = '梁文谷时段' }
            }
            if ($null -ne $script:RateTail) {
                $script:RateTail.Text = '标准'
                if (-not $isPeak) { $script:RateTail.Text = '五折' }
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        'e5' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '[ IDLE MODE ]'
                if ($isPeak) { $script:StatusText.Text = '[ PEAK MODE ]' }
            }
            if ($null -ne $script:RateText) {
                $rate = '0.5X'
                if ($isPeak) { $rate = '1.0X' }
                $script:RateText.Text = 'RATE: ' + $rate
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = $dayText + '  ' + $weekEn }
            if ($null -ne $script:TzText) { $script:TzText.Text = 'BJT UTC+8' }
        }
        'e4' {
            if ($null -ne $script:PlateStatus) {
                $script:PlateStatus.Text = '空闲'
                if ($isPeak) { $script:PlateStatus.Text = '高峰' }
            }
            if ($null -ne $script:PlateStatusEn) {
                $script:PlateStatusEn.Text = 'IDLE'
                if ($isPeak) { $script:PlateStatusEn.Text = 'PEAK' }
            }
            if ($null -ne $script:PlateRate) {
                $script:PlateRate.Text = '0.5×'
                if ($isPeak) { $script:PlateRate.Text = '1.0×' }
            }
            if ($null -ne $script:PlateDay) {
                $script:PlateDay.Text = '工作日'
                if ($Status.IsWeekend) { $script:PlateDay.Text = '周末' }
                if ($Status.IsHoliday) { $script:PlateDay.Text = '节假日' }
            }
            if ($null -ne $script:DateText) {
                $script:DateText.Text = [string]$Status.DateText + ' ' + [string]$Status.WeekText + ' · 北京时间'
            }
        }
        'e3' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '空闲时段 IDLE'
                if ($isPeak) { $script:StatusText.Text = '高峰时段 PEAK' }
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
            if ($null -ne $script:TzText) { $script:TzText.Text = '北京时间' }
        }
        'd6' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '梁文谷时段'
                if ($isPeak) { $script:StatusText.Text = '梁文峰时段' }
            }
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
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        'c6' {
            if ($null -ne $script:RateText) { $script:RateText.Text = '0.5'; if ($isPeak) { $script:RateText.Text = '1.0' } }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        'e2' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = 'IDLE ACTIVE'
                if ($isPeak) { $script:StatusText.Text = 'PEAK ACTIVE' }
            }
            if ($null -ne $script:RateText) {
                $rate = '0.5X'
                if ($isPeak) { $rate = '1.0X' }
                $script:RateText.Text = 'RATE ' + $rate
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = $monthEn + '. ' + $now.Day + ' ' + $weekEn }
            if ($null -ne $script:TzText) { $script:TzText.Text = 'UTC+8 BJT' }
            Update-HudWindowLabels -Status $Status
        }
        'c4' {
            if ($null -ne $script:StatusText) {
                $script:StatusText.Text = '• 空闲'
                if ($isPeak) { $script:StatusText.Text = '• 高峰' }
            }
            if ($null -ne $script:RateText) {
                $script:RateText.Text = '0.5×'
                if ($isPeak) { $script:RateText.Text = '1.0×' }
            }
            if ($null -ne $script:DateText) { $script:DateText.Text = [string]$Status.DateText }
            if ($null -ne $script:WeekText) { $script:WeekText.Text = [string]$Status.WeekText }
        }
        default { }
    }
}

# HUD 的窗口标签：左边起点、中间第几个窗口、右边终点
function Update-HudWindowLabels {
    param($Status)
    $f = [double]$Status.DayFraction
    $windows = @($Status.PeakWindows)
    $left = '00:00'
    $right = '24:00'
    $mid = 'IDLE WINDOW'
    $index = 0

    if ($windows.Count -gt 0) {
        foreach ($window in $windows) {
            $a = [double]$window.Start
            $b = [double]$window.End
            if (($f -ge $a) -and ($f -le $b)) {
                $left = Format-HourLabel -Fraction $a
                $right = Format-HourLabel -Fraction $b
                $index = $windows.IndexOf($window) + 1
                $mid = ('PEAK WINDOW {0}/{1}' -f $index, $windows.Count)
                break
            }
        }
        if ($mid -eq 'IDLE WINDOW') {
            $prevEnd = 0.0
            $nextStart = 1.0
            foreach ($window in $windows) {
                $a = [double]$window.Start
                $b = [double]$window.End
                if ($b -lt $f) { $prevEnd = $b }
                if (($a -gt $f) -and ($a -lt $nextStart)) { $nextStart = $a }
            }
            $left = Format-HourLabel -Fraction $prevEnd
            $right = Format-HourLabel -Fraction $nextStart
        }
    }
    if ($null -ne $script:WinLeft) { $script:WinLeft.Text = $left }
    if ($null -ne $script:WinMid) { $script:WinMid.Text = $mid }
    if ($null -ne $script:WinRight) { $script:WinRight.Text = $right }
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
        $r = [double]$script:DecorRefs['GaugeR']
        $rad = ([double]$Status.DayFraction * 360.0 - 90.0) * [Math]::PI / 180.0
        $needle.X1 = $cx + ($r + 18) * [Math]::Cos($rad)
        $needle.Y1 = $cy + ($r + 18) * [Math]::Sin($rad)
        $needle.X2 = $cx + ($r + 2) * [Math]::Cos($rad)
        $needle.Y2 = $cy + ($r + 2) * [Math]::Sin($rad)
    }

    # E2 HUD 进度条：每秒重画一次，段数跟着时间涨
    if ([string]$Spec.Key -eq 'e2') {
        $canvas = $script:HudProgress
        if ($null -ne $canvas) {
            $colors = Get-SchemeColors -Spec $Spec -Status $Status
            Add-DecorHudProgress -Layer $script:DecorHost -W ([double]$script:Card.ActualWidth) -H ([double]$script:Card.ActualHeight) -Colors $colors -Status $Status
            Update-HudWindowLabels -Status $Status
        }
    }
}

