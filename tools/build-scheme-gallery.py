# -*- coding: utf-8 -*-
"""
生成 design/all-schemes.html —— 把 design 目录下 7 份设计稿里的全部 UI 方案
统一编号、集中到一个网页里逐项审阅。

做法：把 7 份原稿以 base64 内联进页面，运行时用 iframe(srcdoc) 原样渲染，
再用 postMessage 让 iframe 滚到指定方案，保证视觉 100% 不失真且单文件可离线打开。
"""
import base64
import json
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')
BASE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "design")
OUT = os.path.join(BASE, "all-schemes.html")

DOC_FILES = {
    "live": "live-v1-states.html",
    "code01": "code01.html",
    "v2": "design-options-v2.html",
    "v3": "design-options-v3.html",
    "v4": "design-options-v4.html",
    "code02": "code02.html",
    "code03": "code03.html",
    "do": "design-options.html",
}

# ---------------------------------------------------------------- 方案清单
# num 直接显示成「组内编号」（L1 / A3 / B5 …），和口头说的「A 类 3 号」一一对应。
ITEMS = []


def add(num, name, en, desc, tags, diff, doc, target, **kw):
    ITEMS.append({
        "num": num, "name": name, "en": en, "desc": desc, "tags": tags,
        "diff": diff, "doc": doc, "target": target,
        "alt": kw.get("alt"), "lv": kw.get("lv", ""),
        "why": kw.get("why", ""), "risk": kw.get("risk", ""),
    })


# ============ L · 默认界面基准（live-v1-states.html）============
LIVE = [
    ("高峰时段", "Peak",
     "琥珀配色，状态点带光晕，时间轴用两段琥珀标出今天的高峰窗口。",
     ["默认界面", "316×180"],
     "现在这台机器上跑的就是它。IsPeak=true 时 Apply-Theme 把状态点、状态字、价格徽章、倒计时整组换成 #F59E0B。", ""),
    ("空闲时段", "Idle",
     "青绿配色。工作日里非高峰的时间段，时间轴上的琥珀段仍然保留。",
     ["默认界面", "316×180"],
     "IsPeak=false 时换 #34D399。此时 IsPeakDay 还是 true，所以高峰段照样画在轴上，只是白线不在窗口里。", ""),
    ("周末", "Weekend",
     "和空闲态同色，只有日期行多「· 周末」，时间轴换成青绿底、琥珀段消失。",
     ["默认界面", "同色不同字"],
     "周六周日直接判 IsPeakDay=false，主色仍然是空闲色——这就是「看起来只有两种 UI」的根因。",
     "周末与空闲肉眼几乎分不出，只能看日期行那两个字"),
    ("法定节假日", "Holiday",
     "和周末像素级相同，仅日期行换成节日名（如「· 国庆节」）。",
     ["默认界面", "同色不同字"],
     "holidays.json 里 yyyy-MM-dd 日期命中即 IsHoliday=true，同样落到空闲配色。",
     "同上；而且不处理调休上班日"),
]
for i, (n, e, d, t, w, r) in enumerate(LIVE):
    add("L%d" % (i + 1), n, e, d, t, "已实现", "live", {"sel": ".item", "idx": i},
        lv="已实现", why=w, risk=r)

# ============ A · 初版液态玻璃（留下 1 / 3 / 5 / 6）============
add("A1", "极简折射流光", "Minimal Sheen",
    "克制、高通透，最接近 Windows 11 原生亚克力质感。",
    ["液态玻璃", "常规型 316×180"], "低（推荐落地）", "do", {"id": "opt-01"},
    alt={"doc": "code01", "file": "code01.html", "target": {"sel": ".scheme-section", "idx": 0}},
    lv="中", why="布局和线上几乎一样，主要成本全在真实背景模糊上。",
    risk="WPF 没有 backdrop-filter，玻璃要靠 DWM 未公开 API + 圆角裁剪")
add("A3", "灵动极简胶囊", "Dynamic Capsule",
    "超扁平横向胶囊，贴合任务栏上方，极致省空间。",
    ["胶囊型 500×120", "省空间"], "极低", "do", {"id": "opt-03"},
    lv="中偏高", why="胶囊 480×110 要改窗口尺寸；左侧状态光球要常驻呼吸动画。",
    risk="动画和每秒刷新会互相打断，必须拆成两层")
add("A5", "霜白明澈玻璃", "Frosted Light",
    "浅色壁纸首选，如 iPhone 控制中心般清澈明朗。",
    ["浅色玻璃", "常规型 316×180"], "低", "do", {"id": "opt-05"},
    lv="中", why="浅色主题要重调整套文字色、阴影与对比度；玻璃部分同 A1。",
    risk="浅色下倒计时和日期很容易糊")
add("A6", "24h 环形轨道玻璃", "Orbit Glass",
    "打破常规方框，圆形拟态表盘，外圈刻画 24 小时时刻。",
    ["圆形表盘", "打破方框"], "中", "do", {"id": "opt-06"},
    lv="高", why="圆形 24h 轨道 + 当前时刻定位，窗口要变成方形 Ø300。",
    risk="WPF 没有 ConicGradient，环形渐变只能用弧段拼")

# ============ B · v2 玻璃材质深化（留下 1 / 3 / 4 / 5）============
add("B1", "深空琥珀", "Void Amber",
    "深色厚玻璃打底，状态光晕从右上角渗出——不看字也能判断现在贵不贵。",
    ["深色玻璃", "常规型 316×180"], "中", "v2", {"id": "p01"},
    lv="中", why="径向光晕 WPF 原生支持（RadialGradientBrush），布局可复用。",
    risk="要做出「厚玻璃」感仍然依赖真实模糊")
add("B3", "流光胶囊", "Flow Capsule",
    "左侧一颗会呼吸的状态光球，右侧信息横排——最像「桌面小宠物」的一版。",
    ["胶囊型 500×120", "深色玻璃"], "中", "v2", {"id": "p03"},
    lv="中", why="胶囊 + 光球脉冲，和 A3 是同一类改动。",
    risk="同 A3：动画与刷新要分层")
add("B4", "石英表盘", "Quartz Dial",
    "24 小时压成一圈，两个高峰窗口就是环上的两段琥珀弧——时间轴变成表盘刻度。",
    ["圆形表盘 Ø300", "深色玻璃"], "高", "v2", {"id": "p04"},
    lv="高", why="24h 表盘 + 两段高峰弧 + 当前时刻指针。",
    risk="无圆锥渐变；指针每秒跳一格会显得卡")
add("B5", "熔岩边缘", "Ember Edge",
    "去掉流光和颗粒，只留左边缘一根 3px 状态光柱——最安静、也最省电的一版。",
    ["深色玻璃", "最省电"], "低", "v2", {"id": "p05"},
    lv="低", why="只在卡片左侧加一根 3px 状态光柱，布局完全不动。",
    risk="基本没有")

# ============ C · v3 仪器方向（留下 1 / 2 / 3 / 4 / 6）============
add("C1", "仪表盘", "Panel",
    "一块深色仪器面板：chip 报状态、等宽数字报时间、底部刻度尺报全天分布。",
    ["实色 · 无模糊", "316×180"], "低", "v3", {"id": "p01"},
    lv="低", why="实色面板，底部刻度尺可以直接复用现有时间轴。",
    risk="")
add("C2", "报表", "Ledger",
    "米白纸感 + 报表排版，左侧 4px 竖色条是唯一的状态信号。",
    ["纸感浅色", "衬线数字"], "低", "v3", {"id": "p02"},
    lv="低", why="米白纸感 + 衬线数字 + 左侧竖色条，纯样式改动。",
    risk="浅色下要重校一遍文字对比度")
add("C3", "刻度带", "Tape",
    "一条 460px 横向窄条，底部整条刻度尺贯穿——像贴纸一样贴在任务栏上沿。",
    ["横向窄条 520×120", "实色"], "中", "v3", {"id": "p03"},
    lv="中", why="460×112 横条，刻度尺贯穿整条。",
    risk="改窗口尺寸后右下角锚点要重算")
add("C4", "圆表", "Gauge",
    "真仪表盘：外圈 24 小时刻度，两个高峰扇区填色，一根游标指当前时刻。",
    ["圆表 Ø300", "深色金属"], "高", "v3", {"id": "p04"},
    lv="高", why="外圈 24h 刻度 + 两个高峰扇区 + 游标。",
    risk="扇区只能用 ArcSegment 拼，没有圆锥渐变")
add("C6", "色块", "Block",
    "最激进的一版：整块底色就是状态本身，高峰满版琥珀、空闲满版青绿。",
    ["满版实色 280×182", "零装饰"], "低", "v3", {"id": "p06"},
    lv="极低", why="整块底色就是状态，删掉时间轴和徽章就行。",
    risk="周末/节假日会和空闲完全一样，必须额外加区分")

# ============ D · v4 波峰波谷（留下 1 / 3 / 6）============
add("D1", "示波器", "Scope",
    "一整天的计费画成一条连续波形：两个平台是峰，中间凹陷是午间谷。",
    ["深色 320×176", "连续波形"], "中", "v4", {"id": "p01"},
    lv="中", why="波形可以按 PeakWindows 采样成 Path 曲线。",
    risk="没有历史数据，只能画「理论上的这一天」")
add("D3", "K 线", "Candle",
    "24 根蜡烛，柱子越高越贵；高峰红烛、空闲绿烛——股民不用解释就懂。",
    ["深色 316×230", "蜡烛图"], "低", "v4", {"id": "p03"},
    lv="中", why="24 根柱子按高峰/空闲着色，复用同一天的数据。",
    risk="没有 OHLC，柱高只能当装饰，别让人误读成真实行情")
add("D6", "半谷", "Split",
    "整块斜切成两半：红的是峰、绿的是谷，面积比就是今天的时长比。",
    ["双色斜切 300×206", "海报感"], "低", "v4", {"id": "p06"},
    lv="低", why="双色斜切用 Polygon 或 SkewTransform 就能做。",
    risk="面积比要跟着今天的高峰/空闲时长算")

# ============ E · 全新风格（留下 2 / 3 / 4 / 5）============
add("E2", "工业级仪表 HUD", "Cyber Gauge HUD",
    "顶部琥珀条 + 描边框 + 8 段发光进度，按当前窗口实时推进，极客控制台气质。",
    ["290×198 DIP", "8 段进度"], "低", "code02", {"sel": ".proposal-section", "idx": 1},
    lv="低", why="8 段进度就是 8 个 Rectangle，按当前窗口进度点亮，每秒重算。",
    risk="")
add("E3", "新野兽派高对比卡片", "Neo-Brutalist Pop",
    "纯平粗黑描边 + 纯色高对比，杜绝一切渐变模糊，年轻化辨识度极强。",
    ["290×226 DIP", "零渐变"], "超低", "code02", {"sel": ".proposal-section", "idx": 2},
    lv="极低", why="白底 + 2px 黑边 + 零模糊硬投影，纯属性改动。",
    risk="")
add("E4", "双色瑞士分屏切块", "Swiss Dual-Pane",
    "左侧实色状态铭牌 + 右侧黑曜石大字，建筑学般的模块化秩序感。",
    ["330×172 DIP", "双区块拼接"], "低", "code02", {"sel": ".proposal-section", "idx": 3},
    lv="低", why="左右两栏，左栏是实色状态铭牌。",
    risk="窗口窄的时候两栏会挤")
add("E5", "点阵液晶电子时钟", "Matrix LCD",
    "复古荧光屏底色 + 超大 LCD 数字，0 高光反射，长期盯屏最护眼。",
    ["310×178 DIP", "内凹屏槽"], "中低", "code02", {"sel": ".proposal-section", "idx": 4},
    lv="中", why="点阵数字可以用等宽字体近似，或用 5×7 点阵手绘。",
    risk="依赖系统字体，没装就会退化成普通等宽")

# ============ F · 梗图向（只留 1）============
add("F1", "峰谷示波器", "Oscilloscope Wave Monitor",
    "琥珀描边波形框：两个圆峰对应两段高峰，峰顶菱形标记 + PEAK 标签，当前时刻一条竖虚线。",
    ["300×220 DIP", "波形框 + 峰标"], "", "code03", {"sel": ".scheme-block", "idx": 0},
    lv="中", why="两个高斯峰按 PeakWindows 叠出来，外加「梁文峰 / 梁文谷」文案。",
    risk="现在只有「高峰/空闲」两套文案，梗文案要新增字段")

assert len(ITEMS) == 25, len(ITEMS)

# 21 个方案已经全部实现进挂件本体（lib/Schemes.ps1），
# 所以「落地难度」这一列统一改成「已实现」，原始难度保留在 why 里。
for _it in ITEMS:
    _it["diff"] = "已实现"
    _it["lv"] = "已实现"


GROUPS = [
    {"key": "L", "title": "默认界面 · 四种状态基准", "file": "live-v1-states.html", "color": "#94A3B8",
     "note": "基准：这台机器上现在跑的就是它（右键菜单里的「默认界面」）。四种状态摆在一起，方便和后面所有方案对比",
     "nums": ["L1", "L2", "L3", "L4"]},
    {"key": "A", "title": "初版 · 液态玻璃", "file": "design-options.html", "color": "#FFB443",
     "note": "原本 6 个方向，留 A1 / A3 / A5 / A6；A1 还能切到展开版看 token 表与 WPF 落地说明",
     "nums": ["A1", "A3", "A5", "A6"]},
    {"key": "B", "title": "v2 · 玻璃材质深化", "file": "design-options-v2.html", "color": "#7DD3FC",
     "note": "留 B1 / B3 / B4 / B5（B2 霜白棱镜、B6 极简薄片已删）",
     "nums": ["B1", "B3", "B4", "B5"]},
    {"key": "C", "title": "v3 · 仪器方向", "file": "design-options-v3.html", "color": "#A78BFA",
     "note": "留 C1 / C2 / C3 / C4 / C6（C5 终端已删）",
     "nums": ["C1", "C2", "C3", "C4", "C6"]},
    {"key": "D", "title": "v4 · 波峰波谷", "file": "design-options-v4.html", "color": "#5EEAD4",
     "note": "留 D1 / D3 / D6（D2 地形、D4 环波、D5 双峰已删）",
     "nums": ["D1", "D3", "D6"]},
    {"key": "E", "title": "全新风格与组件架构", "file": "code02.html", "color": "#FB7185",
     "note": "留 E2 / E3 / E4 / E5（E1 Win11 实色、E6 软拟态已删）",
     "nums": ["E2", "E3", "E4", "E5"]},
    {"key": "F", "title": "梗图向 · 梁文峰 / 梁文谷", "file": "code03.html", "color": "#A3E635",
     "note": "只留 F1（F2–F5 已删）",
     "nums": ["F1"]},
]

# ---------------------------------------------------------------- 底层逻辑映射
MECH = [
    {"k": "01", "t": "时间显示", "st": "全部方案够用", "cls": "ok",
     "d": "Get-DeepSeekTimeStatus 每秒对齐刷新一次，一次返回：HH:mm:ss、日期、周几、状态文案、价格倍数、倒计时文案、当天进度（0–1）、两个高峰窗口（0–1）。",
     "i": "任何「时间 + 状态 + 倒计时 + 一天分布」的组合都能直接接，核心逻辑一行都不用改。",
     "c": "没有历史与累计值（比如「今天已过高峰 2 小时」）。要做得自己累加，重启会清零。"},
    {"k": "02", "t": "高峰 ↔ 空闲切换", "st": "硬切，没有过渡", "cls": "warn",
     "d": "每秒重算一次，只有状态 key 变化时才调 Apply-Theme 整组换色。整个项目 0 个 Storyboard，颜色是瞬间跳变的。",
     "i": "凡是要「渐变 / 呼吸 / 脉冲 / 进度环」的方案（A3、B3、B4、D1、F1…）都得新写动画，而且必须和每秒刷新解耦，否则动画会被 1 秒一次的重绘打断。",
     "c": "切换点固定在 09:00 / 12:00 / 14:00 / 18:00，Find-NextTransition 已能算出下一跳的精确时刻，做倒计时弧可以直接用，不用另写时间逻辑。"},
    {"k": "03", "t": "周末 / 节假日换算", "st": "逻辑完备，视觉没区分", "cls": "warn",
     "d": "周末＝周六周日一律空闲；节假日＝holidays.json 的日期表命中即全天空闲；两者都会让 IsPeakDay=false。",
     "i": "所有方案都能正确显示。但任何用颜色/形状编码状态的方案（C6 色块、D6 半谷、L3/L4），周末和节假日会长得一模一样，必须额外加区分。",
     "c": "调休上班日按官网字面规则仍算空闲；数据只覆盖 2025–2026，跨年要联网更新。"},
    {"k": "04", "t": "特效", "st": "装饰层已落地", "cls": "ok",
     "d": "卡片里多了一层 DecorHost（Canvas），方案按需往里挂装饰：扫光、角落光晕、24h 表盘弧段、波形、K 线、灯带、刻度尺、斜切、铭牌、LCD 屏槽、扫描线、呼吸光球。静态的整层重建，每秒动的（表盘游标、波形亮点）单独走 Update-SchemeDecorTick。",
     "i": "全部用 WPF 原生图元（Rectangle / Path / Ellipse / LinearGradientBrush / RadialGradientBrush / ArcSegment）画，没有第三方依赖，也不吃 GPU 合成层。",
     "c": "唯一没做的是真·背景模糊：网页里的 backdrop-filter 在 WPF 无对应物，要走 DWM 未公开 API（SetWindowCompositionAttribute）才做得出，属于另一件事。"},
    {"k": "05", "t": "窗口尺寸与位置", "st": "按方案自适应", "cls": "ok",
     "d": "每个方案自己声明 Width / Height（0 = 高度自适应）。切方案时 Apply-SchemeWindowSize 重设窗口尺寸，并以右边缘为锚点重算 Left，所以换宽窄不会跳位。位置仍然写进 settings.json。",
     "i": "卡片 280–330、胶囊 500 / 520×120、圆表 Ø300 三种尺寸并存，切换时不闪、不跳、不重启。",
     "c": "无。注意屏幕边缘的 Clamp 是在启动时算的，切到更宽的方案后如果超出屏幕，下一次拖动会自动夹回来。"},
]

APPENDIX = []

# ---------------------------------------------------------------- 读取原稿
docs = {}
for key, fn in DOC_FILES.items():
    raw = open(os.path.join(BASE, fn), "rb").read()
    docs[key] = base64.b64encode(raw).decode("ascii")
    print("  %-8s %-28s %7d B -> %8d B b64" % (key, fn, len(raw), len(docs[key])))

boot = {"items": ITEMS, "groups": GROUPS, "appendix": APPENDIX, "docs": docs, "mech": MECH}
boot_json = json.dumps(boot, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")

TPL = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>DeepSeek 时段挂件 · 25 个 UI 方案终选审查台</title>
<style>
:root{
  --bg:#070A10; --panel:rgba(17,23,34,.86);
  --line:rgba(255,255,255,.07); --line2:rgba(255,255,255,.13);
  --text:#E9EFF8; --dim:#8C99AD; --dim2:#5B6678;
  --amber:#FFB443; --teal:#5EEAD4;
}
*{box-sizing:border-box}
[hidden]{display:none!important}
html,body{height:100%;margin:0}
body{
  background:
    radial-gradient(900px 620px at 84% -10%, rgba(255,180,67,.10), transparent 62%),
    radial-gradient(820px 640px at 2% 110%, rgba(94,234,212,.09), transparent 64%),
    var(--bg);
  color:var(--text);
  font:14px/1.62 system-ui,-apple-system,"Segoe UI","Microsoft YaHei",sans-serif;
  -webkit-font-smoothing:antialiased;
  overflow:hidden;
}
.mono{font-family:ui-monospace,"Cascadia Code",Consolas,monospace;font-variant-numeric:tabular-nums}

/* ---------- 布局 ---------- */
.app{display:grid;grid-template-columns:276px minmax(0,1fr);height:100%}

/* ---------- 侧栏 ---------- */
.side{display:flex;flex-direction:column;min-height:0;border-right:1px solid var(--line);
  background:linear-gradient(180deg,rgba(14,19,29,.94),rgba(7,10,16,.96))}
.side-hd{padding:18px 18px 10px}
.brand{font-size:15px;font-weight:700;letter-spacing:.2px;display:flex;align-items:center;gap:8px}
.brand i{width:8px;height:8px;border-radius:50%;background:var(--amber);box-shadow:0 0 12px var(--amber);font-style:normal}
.brand-sub{color:var(--dim);font-size:11.5px;margin-top:5px;line-height:1.5}
.side-nav{flex:1;overflow-y:auto;overflow-x:hidden;padding:2px 10px 16px;scrollbar-width:thin}
.side-nav::-webkit-scrollbar{width:8px}
.side-nav::-webkit-scrollbar-thumb{background:rgba(255,255,255,.10);border-radius:8px}
.grp{margin-top:13px}
.grp-h{display:flex;align-items:center;gap:7px;padding:5px 8px 6px}
.grp-h .k{font:700 10px/1 ui-monospace,Consolas,monospace;color:#0A0D14;background:var(--g);
  padding:3px 5px;border-radius:4px;letter-spacing:.5px}
.grp-h b{font-size:11.5px;font-weight:600;color:#C8D2E0;letter-spacing:.2px}
.it{display:flex;align-items:center;gap:9px;padding:6px 9px;border-radius:8px;cursor:pointer;
  color:#AEBBCC;border:1px solid transparent;transition:background .12s,color .12s}
.it:hover{background:rgba(255,255,255,.055);color:#fff}
.it.on{background:linear-gradient(90deg,rgba(255,180,67,.17),rgba(255,180,67,.03));
  border-color:rgba(255,180,67,.30);color:#fff}
.it .n{font:600 10px/1 ui-monospace,Consolas,monospace;color:var(--dim2);min-width:27px;
  text-align:center;padding:4px 0;border-radius:5px;background:rgba(255,255,255,.055);flex:none;letter-spacing:.3px}
.it.on .n{color:#0A0D14;background:var(--amber)}
.it.seen .n{color:var(--teal)}
.it.on.seen .n{color:#0A0D14}
.it .t{flex:1;min-width:0;font-size:12.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.it .d{width:5px;height:5px;border-radius:50%;background:transparent;flex:none}
.it.seen .d{background:var(--teal);box-shadow:0 0 7px rgba(94,234,212,.85)}
.it .s{font-size:10px;color:var(--amber);flex:none}
.side-ft{padding:11px 16px 14px;border-top:1px solid var(--line);font-size:11.5px;color:var(--dim)}
.bar{height:3px;border-radius:3px;background:rgba(255,255,255,.09);margin-top:7px;overflow:hidden}
.bar i{display:block;height:100%;width:0;background:linear-gradient(90deg,var(--teal),var(--amber));transition:width .3s}

/* ---------- 主区 ---------- */
.main{display:grid;grid-template-rows:auto minmax(0,1fr);min-height:0}
.top{display:flex;align-items:center;gap:14px;padding:11px 20px;border-bottom:1px solid var(--line);
  background:rgba(9,13,20,.72);backdrop-filter:blur(14px)}
.seg{display:flex;gap:2px;padding:2px;border-radius:9px;background:rgba(255,255,255,.05);border:1px solid var(--line)}
.seg button{all:unset;padding:5px 13px;border-radius:7px;font-size:12.5px;color:var(--dim);cursor:pointer}
.seg button.on{background:rgba(255,255,255,.11);color:#fff;box-shadow:0 1px 4px rgba(0,0,0,.4)}
.seg button:hover{color:#fff}
.crumb{flex:1;min-width:0;font-size:12.5px;color:var(--dim);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.crumb b{color:var(--text);font-weight:600}
.crumb .g{display:inline-block;padding:1px 6px;border-radius:4px;font-size:10.5px;
  background:rgba(255,255,255,.07);color:#C8D2E0;margin-right:6px}
.hint{font-size:11.5px;color:var(--dim2)}
.hint kbd{font:11px ui-monospace,Consolas,monospace;padding:1px 5px;border-radius:4px;
  background:rgba(255,255,255,.07);border:1px solid var(--line2);color:#B9C4D4}

.stage{display:grid;min-height:0}
.stage>*{grid-area:1/1;min-height:0}

/* ---------- 总览 ---------- */
.ov{overflow-y:auto;padding:0 22px 70px;scrollbar-width:thin}
.ov::-webkit-scrollbar{width:10px}
.ov::-webkit-scrollbar-thumb{background:rgba(255,255,255,.10);border-radius:10px}
.hero{padding:30px 4px 22px}
.hero h1{margin:0;font-size:25px;letter-spacing:-.3px;font-weight:700}
.hero h1 em{font-style:normal;color:var(--amber)}
.hero p{margin:9px 0 0;color:var(--dim);font-size:13px;max-width:760px}
.stats{display:flex;gap:26px;margin-top:18px;flex-wrap:wrap}
.stat b{display:block;font:700 22px/1.1 ui-monospace,Consolas,monospace;color:#fff}
.stat span{font-size:11.5px;color:var(--dim2)}
.legend{display:flex;gap:16px;margin-top:16px;font-size:11.5px;color:var(--dim);flex-wrap:wrap}
.legend i{display:inline-block;width:6px;height:6px;border-radius:50%;margin-right:5px;vertical-align:1px}
.filters{display:flex;gap:8px;margin:18px 0 4px;flex-wrap:wrap}
.chip{all:unset;cursor:pointer;font-size:12px;padding:5px 12px;border-radius:20px;
  border:1px solid var(--line2);color:var(--dim);background:rgba(255,255,255,.03)}
.chip:hover{color:#fff;border-color:rgba(255,255,255,.28)}
.chip.on{background:rgba(255,180,67,.15);border-color:rgba(255,180,67,.42);color:#FFD79A}

.gsec{margin-top:26px}
.gsec-h{display:flex;align-items:center;gap:10px;margin-bottom:11px;flex-wrap:wrap}
.gsec-h .k{font:700 10.5px/1 ui-monospace,Consolas,monospace;color:#0A0D14;background:var(--g);
  padding:4px 6px;border-radius:4px}
.gsec-h b{font-size:14.5px;font-weight:600}
.gsec-h a{font-size:11.5px;color:var(--dim2);text-decoration:none;border-bottom:1px dashed rgba(255,255,255,.18);padding-bottom:1px}
.gsec-h a:hover{color:var(--amber);border-color:var(--amber)}
.gsec-h .note{flex:1 1 100%;font-size:11.5px;color:var(--dim2);margin-top:-4px}

.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(272px,1fr));gap:12px}
.card{position:relative;display:flex;gap:13px;padding:14px 14px 13px;border-radius:13px;cursor:pointer;
  background:linear-gradient(158deg,rgba(255,255,255,.058),rgba(255,255,255,.016));
  border:1px solid var(--line);transition:transform .16s,border-color .16s,box-shadow .16s}
.card:hover{transform:translateY(-2px);border-color:rgba(255,180,67,.34);
  box-shadow:0 16px 34px -20px rgba(0,0,0,.95),0 0 0 1px rgba(255,180,67,.08) inset}
.card .cn{font:700 13px/1 ui-monospace,Consolas,monospace;color:var(--g);flex:none;
  width:34px;height:34px;border-radius:9px;display:grid;place-items:center;letter-spacing:.3px;
  background:color-mix(in srgb,var(--g) 12%,transparent);border:1px solid color-mix(in srgb,var(--g) 26%,transparent)}
.card.seen .cn{box-shadow:0 0 0 2px rgba(94,234,212,.28)}
.card .cb{flex:1;min-width:0;display:flex;flex-direction:column}
.card .cnm{font-size:13.5px;font-weight:600;line-height:1.35}
.card .cnm span{display:block;font-size:10.5px;color:var(--dim2);font-weight:400;letter-spacing:.2px}
.card .cd{font-size:11.5px;color:var(--dim);line-height:1.55;margin-top:6px;
  display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.card .ct{display:flex;gap:5px;flex-wrap:wrap;margin-top:auto;padding-top:9px}
.card .ct span{font-size:10px;padding:1px 6px;border-radius:4px;color:#9FAABC;
  background:rgba(255,255,255,.055);border:1px solid var(--line)}
.card .star{position:absolute;top:9px;right:9px;width:22px;height:22px;border-radius:6px;
  display:grid;place-items:center;font-size:13px;color:rgba(255,255,255,.16);cursor:pointer}
.card .star:hover{background:rgba(255,255,255,.08);color:rgba(255,180,67,.7)}
.card .star.on{color:var(--amber)}

/* ---------- 落地等级徽章 ---------- */
.lv{font-size:10px;padding:1px 6px;border-radius:4px;border:1px solid transparent;white-space:nowrap;line-height:1.6}
.lv-0{color:#5EEAD4;background:rgba(94,234,212,.12);border-color:rgba(94,234,212,.28)}
.lv-1{color:#86EFAC;background:rgba(134,239,172,.12);border-color:rgba(134,239,172,.28)}
.lv-2{color:#FCD34D;background:rgba(252,211,77,.12);border-color:rgba(252,211,77,.28)}
.lv-3{color:#FCA5A5;background:rgba(252,165,165,.12);border-color:rgba(252,165,165,.28)}

/* ---------- 逻辑映射 ---------- */
.map{overflow-y:auto;padding:0 22px 70px;scrollbar-width:thin}
.map::-webkit-scrollbar{width:10px}
.map::-webkit-scrollbar-thumb{background:rgba(255,255,255,.10);border-radius:10px}
.map-hero{padding:30px 4px 4px}
.map-hero h1{margin:0;font-size:24px;letter-spacing:-.3px;font-weight:700}
.map-hero h1 em{font-style:normal;color:var(--amber)}
.map-hero p{margin:9px 0 0;color:var(--dim);font-size:13px;max-width:880px}
.map-hero p b{color:#CBD5E1;font-weight:600}
.mechs{display:grid;grid-template-columns:repeat(auto-fill,minmax(368px,1fr));gap:12px;margin-top:22px}
.mech{background:linear-gradient(158deg,rgba(255,255,255,.055),rgba(255,255,255,.015));
  border:1px solid var(--line);border-radius:14px;padding:15px 16px 14px}
.mech-h{display:flex;align-items:center;gap:9px;margin-bottom:9px}
.mech-h .k{font:700 10px/1 ui-monospace,Consolas,monospace;color:#0A0D14;background:var(--mc);
  padding:4px 6px;border-radius:4px}
.mech-h b{font-size:13.5px;font-weight:600}
.mech-h .st{margin-left:auto;font-size:10.5px;padding:2px 8px;border-radius:20px;white-space:nowrap;
  color:var(--mc);background:color-mix(in srgb,var(--mc) 13%,transparent);
  border:1px solid color-mix(in srgb,var(--mc) 32%,transparent)}
.mech dl{margin:0;font-size:12px;line-height:1.64}
.mech dt{font-size:10px;color:var(--dim2);letter-spacing:.7px;margin-top:9px}
.mech dt:first-child{margin-top:0}
.mech dd{margin:2px 0 0;color:#B4C0D0}
.mech dd b{color:#fff;font-weight:600}

.tbl{margin-top:26px;border:1px solid var(--line);border-radius:12px;overflow:hidden}
.tbl table{width:100%;border-collapse:collapse;font-size:12.5px}
.tbl th{text-align:left;font-weight:600;font-size:10.5px;color:var(--dim2);letter-spacing:.7px;
  padding:10px 12px;background:rgba(255,255,255,.04);border-bottom:1px solid var(--line)}
.tbl td{padding:9px 12px;border-bottom:1px solid rgba(255,255,255,.045);vertical-align:top;color:#C2CCDA}
.tbl tr:last-child td{border-bottom:0}
.tbl tbody tr:hover td{background:rgba(255,255,255,.025)}
.tbl .id{font:600 11px/1 ui-monospace,Consolas,monospace;color:var(--dim);white-space:nowrap}
.tbl .nm{font-weight:600;color:#fff;white-space:nowrap}
.tbl .rs{color:var(--dim);font-size:11.5px}
.map-foot{margin-top:20px;font-size:11.5px;color:var(--dim2);line-height:1.8}

/* ---------- 逐项 ---------- */
.dt{display:grid;grid-template-rows:auto minmax(0,1fr);min-height:0}
.dt-hd{display:grid;grid-template-columns:auto minmax(0,1fr) auto;gap:16px;align-items:start;
  padding:14px 20px 13px;border-bottom:1px solid var(--line);
  background:linear-gradient(180deg,rgba(255,255,255,.038),rgba(255,255,255,.008))}
.dt-num{font:700 30px/1 ui-monospace,Consolas,monospace;color:var(--amber);letter-spacing:-1.5px;padding-top:3px}
.dt-nm{font-size:16px;font-weight:600;line-height:1.3}
.dt-nm span{font-size:11.5px;color:var(--dim2);font-weight:400;margin-left:8px}
.dt-ds{font-size:12.5px;color:var(--dim);margin-top:4px;max-width:820px}
.dt-tg{display:flex;gap:5px;flex-wrap:wrap;margin-top:7px}
.dt-tg span{font-size:10.5px;padding:1.5px 7px;border-radius:5px;color:#A8B4C6;
  background:rgba(255,255,255,.055);border:1px solid var(--line)}
.dt-tg span.df{color:#FFD79A;border-color:rgba(255,180,67,.3);background:rgba(255,180,67,.09)}
.dt-lv{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-top:8px;font-size:11.5px;color:var(--dim)}
.dt-src{display:flex;gap:6px;align-items:center;margin-top:9px;flex-wrap:wrap}.dt-src .lb{font-size:10.5px;color:var(--dim2);letter-spacing:.6px}
.dt-src .sbtn{all:unset;cursor:pointer;font-size:11px;padding:3px 9px;border-radius:6px;
  border:1px solid var(--line);color:var(--dim);background:rgba(255,255,255,.03)}
.dt-src .sbtn:hover{color:#fff;border-color:rgba(255,255,255,.26)}
.dt-src .sbtn.on{color:#0A0D14;background:var(--amber);border-color:transparent;font-weight:600}
.dt-ac{display:flex;gap:6px;align-items:center;flex-wrap:wrap;justify-content:flex-end}
.btn{all:unset;cursor:pointer;font-size:12px;padding:5px 11px;border-radius:7px;
  border:1px solid var(--line2);color:#C2CCDA;background:rgba(255,255,255,.045);white-space:nowrap}
.btn:hover{color:#fff;border-color:rgba(255,255,255,.3);background:rgba(255,255,255,.09)}
.btn.pri{color:#0A0D14;background:var(--amber);border-color:transparent;font-weight:600}
.btn.pri:hover{background:#FFC768;color:#0A0D14}
.btn.on{color:#0A0D14;background:var(--teal);border-color:transparent;font-weight:600}
.btn.star{color:var(--dim)}
.btn.star.on{color:#0A0D14;background:var(--amber);border-color:transparent;font-weight:600}
.btn[disabled]{opacity:.32;pointer-events:none}
.dt-bd{min-height:0;background:#0A0D14;position:relative}
#frame{width:100%;height:100%;border:0;display:block;background:#0A0D14}
.loading{position:absolute;inset:0;display:grid;place-items:center;color:var(--dim2);font-size:12.5px;pointer-events:none}
noscript{display:block;padding:40px;color:#fff}
@media (max-width:900px){
  .app{grid-template-columns:1fr}
  .side{display:none}
  .dt-hd{grid-template-columns:1fr}
  .dt-ac{justify-content:flex-start}
}
</style>
</head>
<body>
<div class="app">
  <aside class="side">
    <div class="side-hd">
      <div class="brand"><i></i>方案审查台</div>
      <div class="brand-sub">DeepSeek 时段挂件 · 7 份设计稿统一编号</div>
    </div>
    <div class="side-nav" id="nav"></div>
    <div class="side-ft">
      <div>已看 <b id="pgNum" class="mono">0</b> / 25　候选 <b id="stNum" class="mono">0</b></div>
      <div class="bar"><i id="pgBar"></i></div>
    </div>
  </aside>

  <main class="main">
    <div class="top">
      <div class="seg">
        <button id="tabOv" class="on">总览</button>
        <button id="tabMap">逻辑映射</button>
        <button id="tabDt">逐项</button>
      </div>
      <div class="crumb" id="crumb">25 个方案 · 7 个方向 · 已按你的取舍筛过</div>
      <div class="hint"><kbd>←</kbd> <kbd>→</kbd> 切换　<kbd>Esc</kbd> 返回总览</div>
    </div>
    <div class="stage">
      <section class="ov" id="ov"></section>
      <section class="map" id="map" hidden></section>
      <section class="dt" id="dt" hidden>
        <div class="dt-hd" id="dtHd"></div>
        <div class="dt-bd">
          <iframe id="frame" title="方案原稿预览"></iframe>
          <div class="loading" id="loading">正在载入原稿…</div>
        </div>
      </section>
    </div>
  </main>
</div>
<noscript>此页面需要启用 JavaScript 才能逐项加载原稿。</noscript>

<script id="boot" type="application/json">__BOOT__</script>
<script>
(function(){
  "use strict";
  var B = JSON.parse(document.getElementById("boot").textContent);
  var ITEMS = B.items, GROUPS = B.groups, APPX = B.appendix, DOCS = B.docs, MECH = B.mech;
  var BY = {};
  ITEMS.forEach(function(it, i){ it.i = i; BY[it.num] = it; });

  var LS_SEEN = "ds_schemes_seen_v1", LS_STAR = "ds_schemes_star_v1";
  function load(k){ try{ return JSON.parse(localStorage.getItem(k) || "{}") || {}; }catch(e){ return {}; } }
  function save(k, v){ try{ localStorage.setItem(k, JSON.stringify(v)); }catch(e){} }
  var seen = load(LS_SEEN), star = load(LS_STAR);

  var state = { cur: -1, var: 0, filter: "all" };
  var frame = document.getElementById("frame");
  var curDoc = null;

  function esc(s){ return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;"); }
  function seenCount(){ return Object.keys(seen).length; }
  function starCount(){ return Object.keys(star).length; }

  /* ---------- 侧栏 ---------- */
  function renderNav(){
    var h = "";
    GROUPS.forEach(function(g){
      h += '<div class="grp" style="--g:' + g.color + '">';
      h += '<div class="grp-h"><span class="k">' + g.key + '</span><b>' + esc(g.title) + '</b></div>';
      g.nums.forEach(function(num){
        var it = BY[num];
        h += '<div class="it' + (state.cur === it.i ? " on" : "") + (seen[num] ? " seen" : "") +
             '" data-i="' + it.i + '"><span class="n">' + num + '</span><span class="t">' +
             esc(it.name) + '</span>' + (star[num] ? '<span class="s">★</span>' : "") +
             '<span class="d"></span></div>';
      });
      h += '</div>';
    });
    if (APPX.length){
      h += '<div class="grp" style="--g:#64748B"><div class="grp-h"><span class="k">附</span><b>附录</b></div>';
      APPX.forEach(function(a, k){
        h += '<div class="it" data-x="' + k + '"><span class="n">·</span><span class="t">' +
             esc(a.title) + '</span><span class="d"></span></div>';
      });
      h += '</div>';
    }
    document.getElementById("nav").innerHTML = h;
    var act = document.querySelector(".it.on");
    if (act && act.scrollIntoView) act.scrollIntoView({ block: "nearest" });
    var p = seenCount();
    document.getElementById("pgNum").textContent = p;
    document.getElementById("stNum").textContent = starCount();
    document.getElementById("pgBar").style.width = (p / ITEMS.length * 100) + "%";
  }

  /* ---------- 总览 ---------- */
  function renderOv(){
    var ovEl = document.getElementById("ov");
    var keep = ovEl.scrollTop;
    var h = '<div class="hero">';
    h += '<h1>DeepSeek 时段挂件 · <em>25 个 UI 方案</em>终选审查</h1>';
    h += '<p>已经按你的取舍筛过一轮：<b>7 个方向只留下 21 个方案</b>，再加上「默认界面」的 4 个状态做基准，'
       + '合计 <b class="mono">25</b> 个。编号沿用各组原来的序号（A1 / B3 / C6 …），删掉的编号直接空着，方便对回原稿。'
       + '点卡片进入逐项查看，右侧渲染的是原稿本身，<b>←/→</b> 连续翻阅。</p>';
    h += '<div class="stats">'
       + '<div class="stat"><b>7</b><span>个方向</span></div>'
       + '<div class="stat"><b>25</b><span>个方案</span></div>'
       + '<div class="stat"><b>21</b><span>个待选</span></div>'
       + '<div class="stat"><b id="hSeen">0</b><span>已看过</span></div>'
       + '</div>';
    h += '<div class="legend">'
       + '<span><i style="background:#5EEAD4;box-shadow:0 0 7px rgba(94,234,212,.8)"></i>已看过</span>'
       + '<span><i style="background:#FFB443"></i>已标为候选</span>'
       + '<span style="color:#5B6678">L 组是现在机器上正在跑的版本；A1 详情页可切「展开版」看 token 表与 WPF 落地说明。落地难度见「逻辑映射」页签。</span>'
       + '</div>';
    h += '<div class="filters">'
       + '<button class="chip on" data-f="all">全部 25</button>'
       + '<button class="chip" data-f="unseen">未看</button>'
       + '<button class="chip" data-f="star">★ 候选</button>'
       + '</div></div>';

    GROUPS.forEach(function(g){
      h += '<div class="gsec" style="--g:' + g.color + '">';
      h += '<div class="gsec-h"><span class="k">' + g.key + '</span><b>' + esc(g.title) + '</b>'
         + '<a href="' + esc(g.file) + '" target="_blank" rel="noopener">' + esc(g.file) + ' ↗</a>'
         + '<span class="note">' + esc(g.note) + '</span></div>';
      h += '<div class="grid">';
      g.nums.forEach(function(num){
        var it = BY[num];
        if (!match(it)) return;
        h += cardHtml(it, g.color);
      });
      h += '</div></div>';
    });

    if (state.filter === "all" && APPX.length){
      h += '<div class="gsec" style="--g:#64748B"><div class="gsec-h"><span class="k">附</span><b>附录</b>'
         + '<span class="note">不计入编号</span></div><div class="grid">';
      APPX.forEach(function(a, k){
        h += '<div class="card" data-x="' + k + '" style="--g:#64748B">'
           + '<div class="cn mono">附</div><div class="cb">'
           + '<div class="cnm">' + esc(a.title) + '<span>' + esc(a.file) + '</span></div>'
           + '<div class="cd">' + esc(a.desc) + '</div>'
           + '<div class="ct"><span>原稿</span><span>点击查看</span></div>'
           + '</div></div>';
      });
      h += '</div></div>';
    }

    ovEl.innerHTML = h;
    ovEl.scrollTop = keep;
    document.getElementById("hSeen").textContent = seenCount();
  }

  function match(it){
    if (state.filter === "unseen") return !seen[it.num];
    if (state.filter === "star") return !!star[it.num];
    return true;
  }

  function lvCls(lv){
    if (!lv) return "lv-2";
    if (lv.indexOf("已实现") === 0) return "lv-0";
    if (lv.indexOf("极低") === 0 || lv.indexOf("低") === 0) return "lv-1";
    if (lv.indexOf("高") === 0) return "lv-3";
    return "lv-2";
  }
  function lvBadge(lv){ return '<span class="lv ' + lvCls(lv) + '">落地 ' + esc(lv) + '</span>'; }

  function cardHtml(it, color){
    return '<div class="card' + (seen[it.num] ? " seen" : "") + '" data-i="' + it.i + '" style="--g:' + color + '">'
      + '<div class="cn mono">' + it.num + '</div>'
      + '<div class="cb">'
      + '<div class="cnm">' + esc(it.name) + '<span>' + esc(it.en) + '</span></div>'
      + '<div class="cd">' + esc(it.desc) + '</div>'
      + '<div class="ct">' + it.tags.map(function(t){ return "<span>" + esc(t) + "</span>"; }).join("")
      + (it.alt ? '<span>初版 + 展开版</span>' : "")
      + (it.lv ? lvBadge(it.lv) : "") + '</div>'
      + '</div>'
      + '<div class="star' + (star[it.num] ? " on" : "") + '" data-star="' + it.i + '" title="标为候选">★</div>'
      + '</div>';
  }

  /* ---------- 逻辑映射 ---------- */
  function renderMap(){
    var h = '<div class="map-hero"><h1>底层逻辑 → <em>25 个方案的映射</em></h1>'
      + '<p>先把现在这版挂件的底层机制拆开看清楚：<b>哪些能力现成、哪些要补、补起来什么代价</b>。'
      + '每条都按「现在怎么做的 / 对方案意味着什么 / 要付什么代价」三段写，最后是 25 个方案的落地总表。</p></div>';

    h += '<div class="mechs">';
    MECH.forEach(function(m){
      var c = m.cls === "ok" ? "#5EEAD4" : (m.cls === "bad" ? "#F87171" : "#FCD34D");
      h += '<div class="mech" style="--mc:' + c + '">'
        + '<div class="mech-h"><span class="k">' + m.k + '</span><b>' + esc(m.t) + '</b>'
        + '<span class="st">' + esc(m.st) + '</span></div>'
        + '<dl><dt>现在怎么做的</dt><dd>' + esc(m.d) + '</dd>'
        + '<dt>对方案意味着什么</dt><dd>' + esc(m.i) + '</dd>'
        + '<dt>要付的代价</dt><dd>' + esc(m.c) + '</dd></dl>'
        + '</div>';
    });
    h += '</div>';

    h += '<div class="tbl"><table><thead><tr>'
      + '<th style="width:58px">编号</th><th style="width:186px">方案</th>'
      + '<th style="width:86px">落地</th><th>主要成本 / 风险</th></tr></thead><tbody>';
    ITEMS.forEach(function(it){
      h += '<tr><td class="id">' + it.num + '</td>'
        + '<td class="nm">' + esc(it.name) + '</td>'
        + '<td>' + lvBadge(it.lv) + '</td>'
        + '<td class="rs">' + esc(it.why || '')
        + (it.risk ? '<br><span style="color:#8C99AD">⚠ ' + esc(it.risk) + '</span>' : '')
        + '</td></tr>';
    });
    h += '</tbody></table></div>';

    h += '<p class="map-foot">判定口径：<b>已实现</b>＝已经写进 lib/Schemes.ps1，右键菜单可直接切；'
      + '<b>中</b>＝要动布局或动画，2–3 天；<b>高</b>＝要碰圆形几何 / 圆锥渐变或改窗口尺寸，得单独排期。</p>';

    document.getElementById("map").innerHTML = h;
  }

  /* ---------- 逐项 ---------- */
  function groupOf(it){
    for (var i = 0; i < GROUPS.length; i++){
      if (GROUPS[i].nums.indexOf(it.num) >= 0) return GROUPS[i];
    }
    return GROUPS[0];
  }

  function renderDetail(){
    var it = ITEMS[state.cur], g = groupOf(it);
    var h = '<div class="dt-num mono">' + it.num + '</div>';
    h += '<div><div class="dt-nm">' + esc(it.name) + '<span>' + esc(it.en) + '</span></div>'
       + '<div class="dt-ds">' + esc(it.desc) + '</div><div class="dt-tg">'
       + '<span>' + esc(g.key) + ' · ' + esc(g.title) + '</span>'
       + it.tags.map(function(t){ return '<span>' + esc(t) + '</span>'; }).join("")
       + (it.diff ? '<span class="df">WPF 还原 ' + esc(it.diff) + '</span>' : "")
       + '</div>';
    if (it.lv){
      h += '<div class="dt-lv">' + lvBadge(it.lv)
         + (it.why ? '<span>' + esc(it.why) + '</span>' : '') + '</div>';
    }
    if (it.alt){
      h += '<div class="dt-src"><span class="lb">查看</span>'
         + '<button class="sbtn' + (state.var ? "" : " on") + '" data-v="0">初版 · ' + esc(g.file) + '</button>'
         + '<button class="sbtn' + (state.var ? " on" : "") + '" data-v="1">展开版 · ' + esc(it.alt.file) + '</button>'
         + '</div>';
    }
    h += '</div>';
    h += '<div class="dt-ac">'
       + '<button class="btn star' + (star[it.num] ? " on" : "") + '" data-act="star">' + (star[it.num] ? "★ 已候选" : "☆ 标候选") + '</button>'
       + '<button class="btn' + (seen[it.num] ? " on" : "") + '" data-act="seen">' + (seen[it.num] ? "已看" : "标已看") + '</button>'
       + '<button class="btn" data-act="open">打开原文件 ↗</button>'
       + '<button class="btn" data-act="prev"' + (state.cur <= 0 ? " disabled" : "") + '>‹ 上一个</button>'
       + '<button class="btn pri" data-act="next"' + (state.cur >= ITEMS.length - 1 ? " disabled" : "") + '>下一个 ›</button>'
       + '</div>';
    document.getElementById("dtHd").innerHTML = h;

    var pct = Math.round((state.cur + 1) / ITEMS.length * 100);
    document.getElementById("crumb").innerHTML =
      '<span class="g" style="background:' + g.color + '22;color:' + g.color + '">' + g.key + ' · ' + esc(g.title) + '</span>'
      + '第 <b class="mono">' + (state.cur + 1) + '</b> / ' + ITEMS.length + ' 个　·　已看 <b>' + seenCount() + '</b>';
  }

  function decode(b64){
    var bin = atob(b64), n = bin.length, u8 = new Uint8Array(n);
    for (var i = 0; i < n; i++) u8[i] = bin.charCodeAt(i);
    return new TextDecoder("utf-8").decode(u8);
  }

  var HELPER = '<script>window.addEventListener("message",function(e){var d=e.data;if(!d||d.__wb!==1)return;'
    + 'function find(t){if(!t)return null;if(t.id){var x=document.getElementById(t.id);if(x)return x;}'
    + 'if(t.sel){var l=document.querySelectorAll(t.sel);if(l.length>(t.idx||0))return l[t.idx||0];}return null;}'
    + 'function jump(t){var el=find(t);if(!el)return false;var y=el.getBoundingClientRect().top+window.pageYOffset-8;'
    + 'var h=document.documentElement,p=h.style.scrollBehavior;h.style.scrollBehavior="auto";'
    + 'window.scrollTo(0,Math.max(0,y));'
    + 'if(p){h.style.scrollBehavior=p;}else{h.style.removeProperty("scroll-behavior");}return true;}'
    + 'var n=0;(function tick(){if(jump(d)||++n>60)return;setTimeout(tick,100);})();});<\/script>';

  function inject(html){
    if (/<\/body>/i.test(html)) return html.replace(/<\/body>/i, HELPER + "</body>");
    return html + HELPER;
  }

  function refOf(it){
    if (state.var && it.alt) return { doc: it.alt.doc, file: it.alt.file, target: it.alt.target };
    return { doc: it.doc, file: groupOf(it).file, target: it.target };
  }

  function loadDoc(ref, cb){
    if (curDoc === ref.doc){ cb(); return; }
    curDoc = ref.doc;
    document.getElementById("loading").hidden = false;
    frame.onload = function(){ frame.onload = null; cb(); };
    frame.srcdoc = inject(decode(DOCS[ref.doc]));
  }

  function jump(target){
    if (!target || !Object.keys(target).length) return;
    var msg = { __wb: 1 };
    for (var k in target) msg[k] = target[k];
    try { frame.contentWindow.postMessage(msg, "*"); } catch(e){}
  }

  function openItem(i, v){
    var it = ITEMS[i];
    state.cur = i;
    state.var = v ? 1 : 0;
    seen[it.num] = 1; save(LS_SEEN, seen);
    showView("dt");
    renderNav(); renderDetail();
    var ref = refOf(it);
    loadDoc(ref, function(){
      document.getElementById("loading").hidden = true;
      setTimeout(function(){ jump(ref.target); }, 60);
    });
  }

  function showView(v){
    document.getElementById("ov").hidden = v !== "ov";
    document.getElementById("map").hidden = v !== "map";
    document.getElementById("dt").hidden = v !== "dt";
    document.getElementById("tabOv").className = v === "ov" ? "on" : "";
    document.getElementById("tabMap").className = v === "map" ? "on" : "";
    document.getElementById("tabDt").className = v === "dt" ? "on" : "";
    if (v === "ov"){
      renderOv();
      document.getElementById("crumb").innerHTML = "25 个方案 · 7 个方向 · 已按你的取舍筛过";
      renderNav();
    } else if (v === "map"){
      renderMap();
      document.getElementById("crumb").innerHTML = "底层逻辑 → 方案映射：5 条机制 + 25 个方案落地表";
    }
  }

  /* ---------- 事件 ---------- */
  document.getElementById("nav").addEventListener("click", function(e){
    var it = e.target.closest(".it");
    if (!it) return;
    if (it.dataset.i != null) openItem(+it.dataset.i);
  });

  document.getElementById("ov").addEventListener("click", function(e){
    var s = e.target.closest("[data-star]");
    if (s){
      e.stopPropagation();
      var it = ITEMS[+s.dataset.star];
      if (star[it.num]) delete star[it.num]; else star[it.num] = 1;
      save(LS_STAR, star);
      s.classList.toggle("on", !!star[it.num]);
      renderNav();
      return;
    }
    var c = e.target.closest(".card");
    if (!c) return;
    if (c.dataset.i != null) openItem(+c.dataset.i);
  });

  document.getElementById("ov").addEventListener("click", function(e){
    var ch = e.target.closest(".chip");
    if (!ch) return;
    state.filter = ch.dataset.f;
    renderOv();
  });

  document.getElementById("dtHd").addEventListener("click", function(e){
    var sb = e.target.closest(".sbtn");
    if (sb){ openItem(state.cur, sb.dataset.v === "1" ? 1 : 0); return; }
    var b = e.target.closest("[data-act]");
    if (!b) return;
    var act = b.dataset.act;
    var it = ITEMS[state.cur];
    if (act === "star"){
      if (star[it.num]) delete star[it.num]; else star[it.num] = 1;
      save(LS_STAR, star); renderNav(); renderDetail();
    } else if (act === "seen"){
      if (seen[it.num]) delete seen[it.num]; else seen[it.num] = 1;
      save(LS_SEEN, seen); renderNav(); renderDetail();
    } else if (act === "open"){
      var ref = refOf(it);
      window.open(ref.file + (ref.target && ref.target.id ? "#" + ref.target.id : ""), "_blank");
    } else if (act === "prev"){
      if (state.cur > 0) openItem(state.cur - 1);
    } else if (act === "next"){
      if (state.cur < ITEMS.length - 1) openItem(state.cur + 1);
    }
  });

  document.getElementById("tabOv").addEventListener("click", function(){ showView("ov"); });
  document.getElementById("tabMap").addEventListener("click", function(){ showView("map"); });
  document.getElementById("tabDt").addEventListener("click", function(){
    if (state.cur >= 0) openItem(state.cur); else if (ITEMS.length) openItem(0);
  });

  document.addEventListener("keydown", function(e){
    if (e.target && /^(INPUT|TEXTAREA)$/.test(e.target.tagName)) return;
    if (e.key === "ArrowRight"){
      e.preventDefault();
      if (state.cur < 0) openItem(0);
      else if (state.cur < ITEMS.length - 1) openItem(state.cur + 1);
    }
    else if (e.key === "ArrowLeft"){
      e.preventDefault();
      if (state.cur > 0) openItem(state.cur - 1);
    }
    else if (e.key === "Escape"){ showView("ov"); }
    else if (e.key === "s" || e.key === "S"){
      if (state.cur >= 0){
        var it = ITEMS[state.cur];
        if (star[it.num]) delete star[it.num]; else star[it.num] = 1;
        save(LS_STAR, star); renderNav(); renderDetail();
      }
    }
  });

  /* ---------- 启动 ---------- */
  window.__DS = { items: ITEMS, groups: GROUPS, state: state, seen: seen, star: star };
  renderNav();
  renderOv();
  if (location.hash === "#dt" && ITEMS.length) openItem(0);
})();
</script>
</body>
</html>
"""

html = TPL.replace("__BOOT__", boot_json)
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(html)

print("\n写出 %s" % OUT)
print("大小 %.1f KB" % (os.path.getsize(OUT) / 1024.0))
