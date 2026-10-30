# DeepSeek 时段挂件 · DSH 插件方案调研

- 调研日期：2026-10-30
- 调研对象：DeepSeek Harness（DSH）插件机制、UI 插槽、打包与发布
- 结论：**可以做，而且适合做成一个很小的常驻状态芯片**；Windows 桌面挂件不需要改，两个形态独立运行、共用同一套时段规则和节假日数据

---

## 一、先确认 DSH 是什么

DSH 是 **DeepSeek Harness** 的缩写，DeepSeek 官方开源的 agent harness，目前处于 public preview。官方定位不是“另一个聊天客户端”，而是“可替换、可组合的 agent 运行框架”：

- 基于 Cordis 的「一切皆插件」架构：模型、工具、技能、会话、沙箱、存储、agent loop、甚至 UI 本身都是插件
- 可以 Desktop 应用运行，也可以用 `npx @deepseek-ai/dsh web` 启动 Web UI
- 插件分为**宿主侧（Node/Cordis）**和**浏览器侧（Web UI/React）**两半，二者通过同一个包分发
- 插件安装进 profile（例如 `web`），不是装进 DSH 本体

这意味着两件事：

1. 我们的“时段判断”可以做成 DSH 原生能力，而不是再做一个外挂窗口；
2. 小 UI 可以直接挂进 DSH 现有界面，不需要重画一套完整桌面挂件。

> 重要澄清：DSH **不自带插件市场索引**。官方的“发现”页是一个实验性入口，用户需要自己添加 JSON 索引源。dsh.so、dshplugins.co、dshplugin.store 等是社区市场/索引，不是 DSH 内置商店。

> 证据说明：插件模型、打包要求、市场索引格式来自官方文档；客户端 slot 名称、ModuleLoader 包装和 React 用法目前主要来自社区插件源码与实测。DSH 仍在 public preview，最终落地前必须先在目标版本做一次 M0 插槽验证。

---

## 二、最终建议（先给结论）

### 2.1 推荐形态

**主入口：会话标题栏右侧的小芯片（`conversation.session.header.utilities`）**

```
● 1.0×  01:29
```

- 高峰：琥珀色圆点
- 空闲：青绿色圆点
- 周末/节假日：青绿色圆点 + 一个很小的「周末」或「节」字标
- 悬停：`高峰时段 · 距空闲 01:29:36 · 价格 1.0×`
- 点击：展开一个 240–280px 的小浮层，显示阶段进度条、起止时间、今日高峰窗口、节日名

这是最适合“瞥一眼”的位置：它和 DSH 自己的 Session log、余额、成本等芯片在同一行，不占输入框，不挡聊天内容，也不需要用户切页面。

**可选形态：右下角浮动小胶囊（`shell.overlay`）**

- 默认关闭，在插件设置里打开
- 尺寸约 150×34，固定在 DSH 窗口右下角
- 用来模拟现在 Windows 挂件的“常驻桌面”感觉
- 必须确认该层是 click-through，只有胶囊本身接收鼠标事件，不能挡住 DSH 的按钮

**不建议把主 UI 放在：**

- 设置页：用户不会为了看时间专门打开设置
- 插件市场页：那是安装入口，不是状态展示
- 大尺寸卡片：DSH 里已经有系统时钟，再放一个大时钟是浪费空间

### 2.2 一句话产品定位

> 不是“把 Windows 挂件塞进 DSH”，而是“在 DSH 里加一个 24px 高的 DeepSeek 计费状态芯片，顺手让 Agent 也知道现在贵不贵”。

---

## 三、具体怎么做

### 3.1 一个 DSH 插件包由两半组成

```text
dsh-plugin-deepseek-clock/
├─ package.json          # 声明 dsh.bundle + dsh.client
├─ cordis.patch.yml      # 把宿主插件插入 profile
├─ lib/
│  ├─ index.js           # 宿主侧：Cordis 插件（Node）
│  └─ client.js          # 浏览器侧：Web UI 插槽（React）
└─ src/                  # 源码，构建后产出 lib/
```

宿主侧负责：

- 注册一个给 Agent 用的工具，例如 `deepseek_pricing_status`
- 可选：注册一个只读 HTTP 路由，向前端提供状态或节假日数据
- 可选：注册设置项

浏览器侧负责：

- 把 React 组件注册到 DSH 的某个 slot
- 每秒更新一次状态
- 跟随 DSH 的浅色/深色主题

### 3.2 package.json 关键字段

下面是根据现有社区插件整理出的最小可用形态，具体版本号要按你安装的 DSH 版本调整：

```json
{
  "name": "dsh-deepseek-clock",
  "version": "0.1.0",
  "type": "module",
  "main": "lib/index.js",
  "exports": {
    ".": { "default": "./lib/index.js" },
    "./client": { "default": "./lib/client.js" },
    "./package.json": "./package.json"
  },
  "files": [
    "lib/index.js",
    "lib/client.js",
    "cordis.patch.yml",
    "README.md",
    "LICENSE"
  ],
  "keywords": ["dsh-plugin", "deepseek-harness", "deepseek", "clock"],
  "dsh": {
    "bundle": {
      "patch": "./cordis.patch.yml"
    },
    "client": {
      "platform": "web",
      "inject": [
        "@deepseek-ai/dsh-client-ui-layout",
        "@deepseek-ai/dsh-client-ui-conversation",
        "@deepseek-ai/dsh-client-ui-renderer",
        "@deepseek-ai/dsh-client-locale"
      ]
    }
  },
  "engines": {
    "node": "^22.19.0 || >=24.0.0",
    "dsh": "^0.2.1-rc.2"
  },
  "peerDependencies": {
    "@deepseek-ai/cordis": "^4.0.1"
  }
}
```

要点：

- **`./client` 必须存在**：浏览器半边靠这个导出被加载；缺了它，插件可能安装成功但 UI 永远不出现
- **`cordis.patch.yml` 必须进 `files`**：这是最常见的“装了但没生效”原因
- `dsh.client.platform` 固定为 `web`；DSH Desktop 内嵌的是同一套 Web UI，所以客户端插件理论上是复用的，但要在桌面版实测
- `dsh.client.inject` 只列真正用到的客户端包；header utilities 属于 `ui-conversation`，shell overlay 属于 `ui-layout`
- `engines.dsh` 要写你验证过的版本范围，不要写 `*`

### 3.3 cordis.patch.yml

发布包里的 patch 用**包名**引用，不用相对路径：

```yaml
- insert:
    - id: deepseek-clock
      name: dsh-deepseek-clock
```

本地开发时可以用绝对路径的临时 overlay：

```yaml
- insert:
    - id: deepseek-clock-dev
      name: '/absolute/path/to/dsh-plugin/src/index.ts'
```

然后：

```bash
pnpm dsh web --patch ./dsh-plugin/cordis.yml
```

### 3.4 宿主侧最小插件

官方文档给的最小形态就是导出一个 `apply(ctx)`：

```ts
import type { Context } from '@deepseek-ai/cordis'
import { defineTool } from '@deepseek-ai/dsh-tools'
import { getDeepSeekTimeStatus } from './core/time.js'

export const name = 'deepseek-clock'
export const inject = ['tools']

export function apply(ctx: Context) {
  ctx.tools.register(defineTool({
    name: 'deepseek_pricing_status',
    description: 'Return DeepSeek API peak/off-peak status, rate multiplier, and next transition in Asia/Shanghai.',
    parameters: {},
    output: {
      schema: { type: 'object' },
      render: (_args, value) => [{ type: 'text', text: JSON.stringify(value) }],
    },
    async execute() {
      return getDeepSeekTimeStatus(new Date())
    },
  }))
}
```

工具的价值：

- 用户可以直接问 Agent「现在 DeepSeek 贵不贵」「帮我把批量任务排到空闲时段」
- Agent 可以在计划任务里引用 `nextOffPeak`，而不是靠模型猜
- 这是 Windows 挂件没有的能力，也是 DSH 插件的差异化

`inject = ['tools']` 表示等 `ctx.tools` 服务就绪后再执行 `apply`。如果还要注册设置或 HTTP 路由，再按官方文档注入对应服务。

### 3.5 浏览器侧：注册插槽

客户端插件的核心只有两步：`inject` 插槽、`register` 组件。

```tsx
import type { Context } from '@deepseek-ai/cordis'
import { ClockBadge } from './ClockBadge'

export const name = 'deepseek-clock-client'
export const inject = ['slots']

export function apply(ctx: Context) {
  ctx.slots.inject('conversation.session.header.utilities', () =>
    ctx.slots.register(
      {
        name: 'conversation.session.header.utilities',
        id: 'deepseek-clock',
        order: -1,
      },
      ClockBadge,
    ),
  )
}
```

如果要做可选浮动胶囊，再加一个：

```tsx
ctx.slots.inject('shell.overlay', () =>
  ctx.slots.register(
    { name: 'shell.overlay', id: 'deepseek-clock-overlay' },
    FloatingClock,
  ),
)
```

`ctx.slots.inject` 只在目标插槽存在时才执行回调；目标 slot 不存在时插件自动降级，不会把 DSH 弄坏。这是官方和社区插件都在用的 fail-closed 方式。

### 3.6 浏览器包格式

当前 DSH 的客户端半边不是普通网页，而是由宿主的 ModuleLoader 加载。社区插件的通行格式是：

```js
window.__ModuleLoader__.load({
  id: 'dsh-deepseek-clock',   // 必须和 npm 包名完全一致
  factory: (require) => {
    const module = { exports: {} }
    const exports = module.exports
    // ...打包后的 React 组件和注册代码...
    return module.exports
  },
})
```

`id` 必须等于 package name，否则运行时会拒绝加载。React、Cordis、DSH 的 client-ui 包保持为平台外部依赖，不要重复打包进 bundle。

### 3.7 构建

推荐：

- 宿主侧：TypeScript → ESM，输出 `lib/index.js`
- 客户端侧：React/TSX → CJS，外面套 ModuleLoader 包装，输出 `lib/client.js`
- 构建器：`tsdown`、esbuild 或 Vite library mode 均可；社区里 `tsdown` 比较常见
- 样式：CSS/CSS Modules，构建时内联或生成单独 CSS；优先使用 DSH 主题变量

示意脚本：

```json
{
  "scripts": {
    "build": "tsdown -c tsdown.config.ts",
    "typecheck": "tsc --noEmit",
    "test": "node --test test/*.test.ts",
    "check": "pnpm run typecheck && pnpm run test && pnpm run build"
  }
}
```

### 3.8 本地安装与验证

DSH 的 Creator mode 可以先生成一个插件骨架，适合 M0 快速验证插槽；但进入 M1 后，建议按本文的 package/manifest/构建方式重新整理，不要直接拿生成物当发布包。

```bash
# 启动 DSH Web UI
npx @deepseek-ai/dsh web

# 安装本地包（DSH 会把参数转给 profile 里的 pnpm）
dsh plugin --profile web add file:./dsh-plugin

# 查看插件是否真的进入配置树
dsh --profile web --dump-config

# 卸载
dsh plugin --profile web remove dsh-deepseek-clock
```

验证顺序：

1. `--dump-config` 里能看到 `deepseek-clock` 这一行
2. 启动后终端没有 client bundle / ModuleLoader 报错
3. 打开一个已有会话，标题栏出现芯片
4. 切换浅色/深色主题，颜色和对比度正常
5. 停用/卸载插件，DSH 原生 UI 完全恢复

### 3.9 发布到市场

DSH 官方“发现”页不内置索引源，所以发布路径是：

1. 发布到 npm（推荐：预构建产物，用户安装时不需要执行构建脚本，也不需要开 `allowBuilds`）
2. `package.json` 加 `dsh-plugin`、`deepseek-harness` 关键词
3. GitHub 仓库加 `dsh-plugin` topic
4. 填好 description、license、repository、homepage
5. 提交到社区索引（dsh.so、dshplugins.co、dshplugin.store 等），或自己用官方索引格式托管一个 `index.json`
6. 索引里的 `engines.dsh` 要和包里的 `engines.dsh` 一致

官方索引最小结构：

```json
{
  "format": 1,
  "title": { "en": "DeepSeek Clock", "zh": "DeepSeek 时段" },
  "plugins": [
    {
      "name": "dsh-deepseek-clock",
      "title": "DeepSeek Clock",
      "description": "DeepSeek API peak/off-peak status and countdown in the DSH header.",
      "author": "ChenChen913",
      "homepage": "https://github.com/ChenChen913/deepseek-time-widget",
      "repository": { "url": "https://github.com/ChenChen913/deepseek-time-widget" },
      "versions": [
        {
          "version": "0.1.0",
          "publishTimestamp": 1790000000,
          "source": { "type": "npm" },
          "engines": { "dsh": "^0.2.1-rc.2" }
        }
      ]
    }
  ]
}
```

dsh.so 这类市场会做 GitHub API 校验、安全扫描和沙盒安装实测，比自己托管索引更容易获得信任；但发布前仍要自己跑一遍真实 DSH 安装验证。

---

## 四、UI 放在哪里：逐个插槽对比

| 插槽 | 位置 | 适合放什么 | 优点 | 缺点 |
| --- | --- | --- | --- | --- |
| `conversation.session.header.utilities` | 会话标题右侧，和 Session log 同一行 | 24px 高的小芯片、状态点、倒计时 | 最容易被瞥见；不占输入区；已有成本/余额插件验证过 | 只在会话打开时出现；标题栏窄屏会拥挤 |
| `conversation.composer.dock` | 输入卡片底部的一行 | `● 高峰 1.0× · 距空闲 01:29:36` | 输入时一直可见；宽度宽松 | 和其他 composer 状态行抢位置 |
| `conversation.input.dock` | 输入卡片上方的一条 | 状态条 + 8 段进度 | 信息量可以稍大 | 会抬高输入区，聊天内容变少 |
| `shell.overlay` | 整个 DSH 框架的浮层，固定右下 | 150×34 浮动胶囊 | 跨会话常驻；最接近 Windows 挂件 | 会挡内容；需要正确处理 click-through；和桌面挂件重复 |
| `sidebar.footer.action` | 左栏底部、设置按钮旁 | 一个状态点 | 极省空间 | 不够显眼；折叠栏时只剩一个点 |
| `settings.plugins.tab` | 设置 → 插件 → 新标签页 | 配置、说明、数据更新 | 适合放复杂选项 | 不适合日常查看 |
| `settings.plugin.item` | 设置 → 插件 → 可配置卡片 | 显示模式、是否显示秒、叠加层开关 | 原生设置形态 | 需要处理 settings 命名空间白名单 |

### 最终组合建议

- **默认：header utilities 芯片**（主入口）
- **可选：shell.overlay 浮动胶囊**（默认关闭，设置里打开）
- **配置：settings.plugin.item**（只放 3–5 个选项）
- **不做的：** 大卡片、独立全屏面板、需要 hover 才出现的关键信息

---

## 五、小 UI 具体怎么设计

### 5.1 信息优先级

DSH 里已经有系统时钟，所以不要再显示大时钟。只保留四个层级：

1. **状态色点**：高峰琥珀 / 空闲青绿 / 数据缺失灰
2. **价格倍数**：`1.0×` / `0.5×`
3. **距下次切换**：`01:29`（小于 1 小时显示 mm:ss；跨天显示 `2天14:00`）
4. **状态文字**：`高峰` / `空闲` / `周末` / `节假日`

日期、节日名、今日两个高峰窗口、阶段起止时间放在点击后的浮层里，不放进 24px 芯片。

### 5.2 芯片规格

```text
高度        22–24px
宽度        88–110px（紧凑）；窄屏可缩成 24×24 圆点
圆角        999px
字号        11–12px，等宽数字
内边距      8px 左右
背景        宿主主题的次级表面色，或 8%–12% 状态色
边框        1px，状态色 20%–30% 透明度
```

显示内容：

```text
● 1.0×  01:29
```

窄屏或用户选择“极简”时：

```text
● 1.0×
```

再窄：

```text
●
```

### 5.3 点击浮层（E2B 风格的小型版）

浮层宽度 240–280px，内容是 E2B 的缩小版：

```text
┌──────────────────────────────┐
│ ● 高峰时段            1.0×   │
│                              │
│ 距空闲还有        01:29:36   │
│                              │
│ ███████████████░░░░░░        │
│ 开始 14:00      结束 18:00   │
│                              │
│ 今日高峰 09:00–12:00         │
│          14:00–18:00         │
└──────────────────────────────┘
```

空闲/周末时把中间换成：

```text
│ 距周一高峰      2天14:00:00  │
│ ███████████████████████████  │
│ 开始 周五18:00   结束 周一09:00 │
```

这就是把 Windows 端 E2B 的“整段相位、跨周末连续”语义，原样缩进 DSH 里。

### 5.4 状态与文案

| 状态 | 圆点 | 倍数 | 芯片文字 | 浮层标题 |
| --- | --- | --- | --- | --- |
| 高峰 | 琥珀 `#F59E0B` | `1.0×` | `高峰 01:29` | `高峰时段` |
| 工作日空闲 | 青绿 `#10B981` | `0.5×` | `空闲 14:00` | `空闲时段` |
| 周末 | 青绿 | `0.5×` | `周末 1天22:30` | `周末 · 全天空闲` |
| 法定节假日 | 青绿 | `0.5×` | `节 6天23:00` | `国庆节 · 全天空闲` |
| 数据缺失 | 灰 | `—` | `数据待更新` | `节假日数据缺失` |

### 5.5 主题与可访问性

- 优先使用 DSH 的主题变量（背景、文字、边框、圆角、字体）；没有对应变量时再回退到项目色板
- 深色和浅色主题都要实测，不能只在深色底上好看
- 不能只靠颜色区分高峰/空闲：必须有 `1.0×` / `0.5×` 文字
- 芯片加 `aria-label`，例如“DeepSeek 高峰时段，价格 1.0 倍，距空闲 1 小时 29 分”
- 浮层支持 `Esc` 关闭、`Enter`/`Space` 打开
- 状态切换动画控制在 150ms 内，并尊重 `prefers-reduced-motion`

### 5.6 浮动胶囊（可选）

```text
● 高峰  1.0×   01:29
```

- 约 150×34，固定右下角，距边 16px
- 默认半透明，鼠标移入变实
- 和 Windows 挂件同时开启时，建议只保留一个；设置里给用户选择
- 不要做拖动，除非确认 `shell.overlay` 的 pointer-event 行为和拖拽不会和 DSH 自身交互冲突

---

## 六、技术栈建议

| 层 | 选择 | 原因 |
| --- | --- | --- |
| 运行时 | Node.js `^22.19.0` 或 `>=24` | 当前 DSH 社区插件和官方 CLI 的要求 |
| 语言 | TypeScript | Cordis 插件、slot 类型、工具 DSL 都是 TS |
| 宿主框架 | `@deepseek-ai/cordis` | 官方插件模型：`apply(ctx)` + `inject` |
| 客户端 UI | React 18 | DSH 客户端 UI 包和社区插件都以 React 组件注册插槽 |
| 样式 | CSS / CSS Modules + DSH 主题变量 | 跟随 DSH 浅色/深色主题；不引入 Tailwind 这类会污染宿主的方案 |
| 构建 | `tsdown` 或 esbuild + 自定义 ModuleLoader 包装 | 宿主 ESM + 客户端 CJS 两种产物 |
| 包管理 | pnpm（DSH 内部也是 pnpm profile） | `dsh plugin add` 最终转发给 pnpm |
| 设置 | `@deepseek-ai/schemastery` | 官方配置 schema，和 DSH 设置页一致 |
| 测试 | `node:test` + Playwright | 纯函数单测 + 真实 DSH 启动验证 |
| 数据 | JSON + 纯 TS 核心 | 与 Windows 端共享规则和节假日数据 |

不需要：

- 不需要后端服务、数据库、API key
- 不需要 Electron/Tauri
- 不需要复制 Windows 的 WPF 代码
- 不需要调用 DeepSeek 官方接口（这是本地时间计算器）

---

## 七、和 Windows 版怎么共存

### 7.1 原则

**两个形态独立运行，不互相依赖。**

- Windows 挂件继续用 PowerShell + WPF，现有 23 套界面、托盘、开机自启全部不动
- DSH 插件用 TypeScript + React，单独一个包
- 二者共享同一套规则、同一个 `holidays.json`、同一组边界测试用例
- 不做“Windows 挂件给 DSH 插件传数据”的 IPC；两边都本地计算，简单可靠

### 7.2 共用核心

把现有的 `lib/DeepSeekTime.ps1` 逻辑移植成 TS：

```ts
export interface DeepSeekStatus {
  isPeak: boolean
  isPeakDay: boolean
  isWeekend: boolean
  isHoliday: boolean
  holidayName: string
  rate: 1.0 | 0.5
  statusText: string
  nextChange: Date
  nextChangeIsPeak: boolean
  phaseStart: Date | null
  phaseEnd: Date | null
  phaseProgress: number
}
```

必须保持这些语义一致：

- 高峰：周一至周五 09:00–12:00、14:00–18:00（北京时间，法定节假日除外）
- 空闲：其余所有时间，包括周末和法定节假日全天
- 跨周末相位：周五 18:00 → 周一 09:00 是一整段空闲
- 跨天倒计时显示 `N天 HH:MM:SS`
- 调休上班日仍按官网字面规则处理（周末算空闲）

### 7.3 防止两边算得不一样

建立一组共享测试夹具，例如：

```json
[
  { "time": "2026-10-28T10:30:00+08:00", "isPeak": true, "next": "2026-10-28T12:00:00+08:00" },
  { "time": "2026-10-30T19:00:00+08:00", "isPeak": false, "next": "2026-11-02T09:00:00+08:00" },
  { "time": "2026-10-31T10:30:00+08:00", "isPeak": false, "next": "2026-11-02T09:00:00+08:00" },
  { "time": "2026-11-02T08:30:00+08:00", "isPeak": false, "next": "2026-11-02T09:00:00+08:00" },
  { "time": "2026-10-01T10:00:00+08:00", "isPeak": false, "next": "2026-10-07T09:00:00+08:00" }
]
```

PowerShell 测试和 TS 测试都读这份夹具。以后改规则，只改一处，两边测试同时报警。

### 7.4 数据流

```text
holidays.json（仓库根，唯一数据源）
        │
        ├─ Windows: Load-HolidayData
        └─ DSH 插件: 构建时复制到 dsh-plugin/src/data/holidays.json

时间规则
        │
        ├─ DeepSeekTime.ps1（Windows）
        └─ core/time.ts（DSH）
```

V1 不在 DSH 插件里做联网更新，避免权限和网络问题；节假日数据随插件版本更新。后续如果要更新，可以加一个宿主 HTTP 路由或设置页按钮，但保持和 Windows 端相同的合并逻辑。

---

## 八、建议的仓库结构

```text
deepseek-time-widget-main/
├─ DeepSeekClock.ps1              # Windows 主程序，不动
├─ lib/                           # Windows 引擎，不动
├─ holidays.json                  # 唯一数据源
├─ research/
│  └─ dsh-plugin.md               # 本文
└─ dsh-plugin/
   ├─ package.json
   ├─ cordis.patch.yml
   ├─ tsconfig.json
   ├─ tsdown.config.ts
   ├─ src/
   │  ├─ index.ts                 # 宿主侧：工具 / 路由 / 设置
   │  ├─ core/
   │  │  ├─ time.ts               # 峰谷、相位、倒计时
   │  │  └─ format.ts             # 中文/英文文案
   │  ├─ data/
   │  │  └─ holidays.json         # 从根目录同步
   │  └─ client/
   │     ├─ index.tsx             # slots 注册
   │     ├─ ClockBadge.tsx        # 会话标题栏芯片
   │     ├─ ClockPopover.tsx      # 点击浮层
   │     └─ FloatingClock.tsx     # 可选 shell.overlay 胶囊
   ├─ test/
   │  ├─ time.test.ts
   │  └─ fixtures.json            # 与 PowerShell 共用
   └─ README.md                   # 插件安装/配置/截图
```

这样不会把现有 Windows 项目变成 monorepo，也不会影响 GitHub Releases 里的 Windows 包。

---

## 九、分阶段落地建议

### M0：验证插槽（先不写业务）

- 用本地 `cordis.patch.yml` + 一个最小 client bundle，插入一个 `conversation.session.header.utilities` 的 `Hello` 芯片
- 确认 DSH Web 和 DSH Desktop 都能显示
- 确认浅色/深色主题、窄屏、无会话时的行为
- 确认卸载后 DSH 完全恢复

这一步只验证 DSH 版本、slot 名称和客户端打包格式，不写时间逻辑。

### M1：最小可用插件

- 共享 TS 核心 + 节假日 JSON
- header utilities 芯片：状态点 + `1.0×` + 倒计时
- 点击浮层：阶段进度、起止时间、周末/节假日文案
- 单元测试跑通 5 个边界时刻
- 本地 `dsh plugin add file:` 安装验证

### M2：DSH 原生能力

- 宿主工具 `deepseek_pricing_status`，让 Agent 能查询
- 设置卡片：显示模式（芯片/胶囊）、是否显示秒、是否显示周末标签
- 可选 `shell.overlay` 浮动胶囊
- 真实 DSH 重启、升级、卸载测试

### M3：发布

- 先用 `npm view dsh-deepseek-clock` 确认包名可用（或改用带 scope 的包名）
- npm 预构建发布，不带 install/postinstall 脚本
- GitHub topic + keywords
- 提交 dsh.so / dshplugins.co / dshplugin.store
- 自己托管索引（可选）
- README 放真实 DSH 截图，不放网页设计稿

---

## 十、风险与坑

1. **DSH 还在 public preview**：slot 名称、客户端包名、ModuleLoader 格式都可能变。必须锁定验证过的 DSH 版本，并在 CI 里跑真实启动，而不是只跑单元测试。
2. **client bundle 的 `id` 必须等于包名**：不一致会静默不显示；`./client` export 缺失也会静默不显示。
3. **`cordis.patch.yml` 忘记进 `files`**：安装成功但宿主插件没插入，`--dump-config` 是最快的排查手段。
4. **settings 命名空间白名单**：DSH Web 只暴露白名单里的设置命名空间；不在名单里时，设置卡片会显示“未暴露”，需要在文档里给出 `cordis.patch.yml` 的配置方法。
5. **shell.overlay 是 click-through 层**：entry 必须显式接收 pointer events，否则胶囊看得见点不着；也不能挡住 DSH 自己的按钮。
6. **插件权限很大**：宿主插件运行在 DSH 进程里，能访问文件、命令、凭据。我们的插件应坚持“只读、无网络、无 API key”，并在 README 里写清楚。
7. **市场不等于安全**：DSH 只校验索引格式，不验证插件内容；dsh.so 会做扫描和沙盒安装，但发布时仍要避免安装期执行代码。
8. **和已有插件撞车**：`@goodandready/dsh-cost-meter` 已经在 header utilities 做了“成本 + 峰谷倒计时”芯片；`@freespace8/dsh-deepseek-balance` 做了余额芯片。我们的差异化应该是：
   - 四态（高峰/空闲/周末/节假日）
   - 跨周末整段相位和 E2B 风格进度
   - 中英双语
   - 与 Windows 挂件同源、可对照
   - 给 Agent 的时段工具
9. **不要把 Windows 端规则复制两份**：共享 fixtures，任何一边改规则都要两边测试通过。
10. **窄屏/侧栏折叠**：header utilities 在窄窗口会拥挤；芯片要能在 24px 圆点和完整文本之间自适应，不能把 Session log 挤掉。

---

## 十一、需要你拍板的三件事

1. **主入口选哪个？**
   - 推荐：`conversation.session.header.utilities` 芯片
   - 备选：`conversation.composer.dock` 输入框底部状态行
2. **要不要默认开启右下角浮动胶囊？**
   - 推荐：默认关闭，设置里可选；避免和 Windows 挂件重复
3. **V1 要不要带 Agent 工具？**
   - 推荐：带。`deepseek_pricing_status` 是 DSH 插件相对 Windows 挂件的核心增量

另外两个可选项：

- 是否发布到 npm 公共市场（需要先确认包名可用）
- 是否自己托管插件市场索引，还是只提交到 dsh.so / dshplugins.co

---

## 十二、参考资料

- [DeepSeek Harness 官方介绍](https://www.deepseek.com/en/harness/)
- [DeepSeek Harness 官方文档：第一个插件](https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/)
- [DeepSeek Harness 官方文档：插件市场](https://deepseek-harness.github.io/deepseek-harness/guide/plugin-market)
- [DeepSeek Harness GitHub](https://github.com/deepseek-ai/deepseek-harness)
- [create-dsh-plugin UI Surfaces（slot 清单）](https://raw.githubusercontent.com/zaeyee/create-dsh-plugin/HEAD/docs/ui-surfaces.md)
- [DSH Plugins Guide（安装、层、发布）](https://dshplugins.co/en/dsh-plugins-guide/)
- [Universal Palette 的客户端插件架构（slot / ModuleLoader / 打包）](https://raw.githubusercontent.com/yunmin311/dsh-universal-palette/HEAD/docs/ARCHITECTURE.md)
- [dsh-pomodoro package.json（client manifest 实例）](https://raw.githubusercontent.com/causebefore/dsh-pomodoro/HEAD/package.json)
- [dsh-cost-meter（header utilities 成本芯片先例）](https://www.npmjs.com/package/@goodandready/dsh-cost-meter)
- [dsh-deepseek-balance（header utilities + host route 先例）](https://www.npmjs.com/package/@freespace8/dsh-deepseek-balance)
- [dsh.so 社区插件市场](https://www.dsh.so/zh/)
- [dsh-market（DSH 内可视化市场）](https://www.dshplugin.store/plugin/dsh-market/dsh-market)
