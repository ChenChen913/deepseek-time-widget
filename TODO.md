# DeepSeek 时段挂件 · 后续任务与实施方案

最后更新：2026-11-02

当前最新 Release：`v1.2.0`，包含 EXE 安装版和便携版。项目已具备 C# 启动器、中文安装向导、安装模式标记、安装包冒烟测试和 Release 自动构建。剩余任务按优先级排列，完成一项就在对应标题下打勾，并补充验证记录。

## 当前基线

- [x] 23 套界面方案，核心测试 85 项、方案校验 872 项、渲染冒烟 93 项。
- [x] EXE 启动器，安装版和便携版不再依赖 VBS。
- [x] Inno Setup 中文安装向导，当前用户安装，不需要管理员权限。
- [x] 安装、CLI、启动器、自启、卸载冒烟测试，本机和 GitHub Actions 均通过。
- [x] Release 工作流，推送 `v*` 标签时自动构建、测试、上传资产。
- [ ] 安装包和启动器代码签名。
- [ ] 节假日在线更新回退源。
- [ ] 2027 年节假日数据。
- [ ] 便携包自动冒烟和升级回归。

## 优先级说明

- P0：影响发布可信度或核心功能，应优先处理。
- P1：发布前应完成，或在下个版本补齐。
- P2：后续增强，不阻塞当前版本。

## P0-1 代码签名与 SmartScreen

状态：待证书。当前 `v1.2.0` 已人工核对并设为正式版，但安装包和启动器未签名。

影响：

- 用户下载 EXE 时可能看到“未知发布者”或 SmartScreen 警告。
- 部分企业策略可能直接阻止未签名程序运行。

证书方案：

| 方案 | 适合场景 | 说明 |
| --- | --- | --- |
| SignPath Foundation | 开源项目免费签名 | 需要申请并通过开源项目审核，CI 集成成熟 |
| Certum 开源代码签名 | 低成本开源签名 | 需要身份验证，适合个人开源项目 |
| Azure Trusted Signing | 已有 Azure 账号 | 按月付费，CI 集成方便 |
| OV 证书 | 常规商业发行 | 需要下载量积累 SmartScreen 信誉 |
| EV 证书 | 希望尽快建立信任 | 成本较高，SmartScreen 信誉更直接 |

推荐顺序：先申请 SignPath Foundation 或 Certum 开源签名；如果项目需要更快建立信任，再考虑 EV。

操作步骤：

1. 选择证书提供方，完成身份验证，拿到 PFX 或云端签名凭据。
2. 如果使用 PFX，在仓库 Secrets 中配置：
   - `WINDOWS_CERTIFICATE_BASE64`：PFX 文件的 Base64 字符串。
   - `WINDOWS_CERTIFICATE_PASSWORD`：PFX 密码。
3. 确认 [.github/workflows/release.yml](.github/workflows/release.yml) 的证书准备步骤能解码 PFX，构建脚本会调用 `signtool` 给启动器和安装包签名。
4. 本地验证签名命令：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-release.ps1 -Version 1.2.1 -PfxPath .\cert.pfx -PfxPassword <密码>
signtool verify /pa /v .\dist\DeepSeekClock-Setup-v1.2.1.exe
signtool verify /pa /v .\dist\app\DeepSeekClock.exe
```

5. 发 `v1.2.1` 标签，让 Release 工作流自动签名并发布稳定版。
6. 在干净的 Windows 10 / 11 标准用户环境下载安装包，检查数字签名、SmartScreen 和 Defender 扫描结果。
7. 更新 Release 说明，去掉“未签名”提示，保留 SHA256 校验值。

验收标准：

- 安装包和启动器的 `Get-AuthenticodeSignature` 状态为 `Valid`。
- 签名带 RFC3161 时间戳，证书链可信。
- 下载后 SmartScreen 不再显示“未知发布者”。
- Defender 扫描无威胁；如遇误报，向微软提交误报样本。

注意：

- 没有受信任证书时，无法彻底消除 SmartScreen 提示。
- 如果以后需要商业发行，Inno Setup 6.7.4 免费版标注为非商业用途，需要购买许可或改用 NSIS、WiX。

## P0-2 节假日在线更新增加回退源

状态：待开发。2026-11-02 实测 timor.tech 返回 Cloudflare 验证页，用户环境可能更新失败。

当前实现：

- [DeepSeekClock.ps1](DeepSeekClock.ps1) 的 `Update-HolidaysOnline` 只请求 `https://timor.tech/api/holiday/year/{year}`。
- 请求失败或无数据时，只返回错误，没有备用源。

方案：

1. 把节假日解析逻辑抽成纯函数，放到 `lib\HolidaySources.ps1`，便于单元测试。
2. 更新流程按年份执行：
   - 先请求 timor.tech。
   - 失败、Cloudflare 拦截、返回空数据时，回退到 `https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{year}.json`。
   - 解析 `days` 中 `isOffDay=true` 的日期和 `name`，生成放假日和节日名。
3. 合并时继续保留 `holidays.json` 的其它字段，例如 `makeupWorkdays`、`sources`、`notes`。
4. 更新结果里的 `source` 写明实际使用的数据源，例如“timor.tech 或 holiday-cn 回退”。
5. 失败提示要说明两个源都失败，不能只显示一个 URL。
6. 增加离线测试：
   - 用 timor 样例 JSON 测试解析。
   - 用 holiday-cn 样例 JSON 测试解析。
   - 测试空数据、Cloudflare HTML、非法日期、重复日期。
7. 手动更新测试：右键“联网更新节假日数据”，确认写入 `%APPDATA%\DeepSeekClock\holidays.json`，并保留 `.bak`。

验收标准：

- timor.tech 不可用时，回退源能补全当年数据。
- 2027 数据未发布时，回退源返回空，界面仍显示“数据待更新”，不崩溃。
- 更新后旧年份和 `makeupWorkdays` 等字段不丢失。

## P1-1 2027 年节假日数据

状态：等待国务院办公厅通知。2026-11-02 核查 holiday-cn 的 2027 数据仍为空。

操作步骤：

1. 官方通知发布后，从国务院办公厅原文、timor.tech、NateScarlet/holiday-cn 三方核对放假日、节日名和调休上班日。
2. 更新 `holidays.json`：
   - `coverageYears` 增加 2027。
   - `holidays` 增加 2027 放假日数组。
   - `holidayNames` 增加对应节日名。
   - `makeupWorkdays` 增加 2027 调休上班日。
   - `sources` 和 `notes` 记录官方文号、核对日期和来源。
3. 更新测试：
   - `Test-Core.ps1` 的覆盖年份断言增加 2027。
   - 增加 2027 春节、国庆边界用例。
   - 校验全年普通工作日和节假日分类。
4. 更新 README 的“2027 年安排尚未发布”说明。
5. 跑全量测试：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\Test-Core.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\Test-Schemes.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\Test-Render.ps1
```

6. 按发布流程发新版本，优先在代码签名完成后发布。

验收标准：

- 2027 年元旦、春节、清明、劳动、端午、中秋、国庆的放假日和调休日与官方通知一致。
- `-PrintStatus -PreviewTime` 对 2027 边界日期输出正确。
- 数据缺失提示只在 2028 等未覆盖年份出现。

## P1-2 便携包自动冒烟

状态：安装包已有自动冒烟，便携包目前只做人工核对。

方案：

1. 新增 `test\Test-Portable.ps1`：
   - 找到 `dist\DeepSeekClock-Portable-v*.zip`。
   - 解压到临时目录。
   - 检查 `DeepSeekClock.exe`、`DeepSeekClock.ps1`、`lib`、`holidays.json` 存在。
   - 检查不包含 `启动挂件.vbs` 和 `install.marker`。
   - 运行便携版 `-PrintStatus`，校验 `StatusText`。
   - 可选启动 `DeepSeekClock.exe`，检查 PowerShell 进程后结束。
   - 结束时删除临时目录。
2. 在 Release 工作流的安装包冒烟测试之后增加便携包冒烟步骤。
3. 在 README 文件结构和测试命令中补充该脚本。

验收标准：

- 便携包在 CI 中可解压、可运行、无 VBS、无安装标记。
- 安装包和便携包都通过冒烟后才能上传 Release。

## P1-3 升级与卸载交互回归

状态：当前自动测试覆盖全新安装和静默卸载，未覆盖覆盖升级和非静默卸载提示。

测试步骤：

1. 安装旧版 `v1.2.0` 到临时目录。
2. 启动一次挂件，写入窗口位置、界面方案和节假日数据文件。
3. 安装新版 `v1.2.1` 到同一目录，确认：
   - 安装器识别旧版并覆盖程序文件。
   - `%APPDATA%\DeepSeekClock` 设置和位置保留。
   - 桌面和开始菜单快捷方式仍指向新 EXE。
   - 自启项路径更新。
4. 运行新版，确认界面方案和位置恢复。
5. 运行非静默卸载，确认：
   - 默认保留设置。
   - 勾选“同时删除设置”后，`%APPDATA%\DeepSeekClock` 被删除。
   - 程序目录、快捷方式、开始菜单组、自启项、卸载入口全部清理。
6. 重复启动挂件，确认单实例和唤起前台正常。

验收标准：

- 覆盖升级不丢设置、不产生重复快捷方式。
- 卸载无残留；设置删除行为符合勾选。
- 安装器检测运行中的挂件并提示退出。

## P1-4 兼容性回归

状态：当前主要在 Windows 11、125% DPI 环境验证。

需要覆盖：

- Windows 10 22H2 和 Windows 11 最新版。
- 标准用户，无管理员权限。
- 100%、125%、150%、200% 缩放。
- 多显示器、混合 DPI、主屏切换、显示器拔插。
- 睡眠唤醒、跨午夜、跨周末、跨法定节假日。
- 系统时区不是 UTC+8 的情况。
- VBScript 被禁用、PowerShell 执行策略受限的情况。
- 23 套界面逐一切换，确认无裁切、闪烁、错位。
- 2027 数据未覆盖时的“数据待更新”提示。

建议：

- 至少准备一台 Windows 10 和一台 Windows 11 的干净虚拟机。
- 每项记录系统版本、DPI、安装方式、结果和截图。
- 发现布局问题时，用 `-PreviewTime` 和 `-CapturePath` 固定时刻复现。

## P2-1 winget 分发

状态：等待签名稳定版。

步骤：

1. 发布签名后的稳定安装包，例如 `v1.2.1`。
2. Fork `microsoft/winget-pkgs`。
3. 按 `manifests/c/ChenChen913/DeepSeekClock/<version>` 创建清单，填写安装包 URL、SHA256、版本、发布者、安装类型。
4. 本地用 `winget validate` 校验，提交 PR。
5. 合并后验证 `winget install ChenChen913.DeepSeekClock`。

验收标准：

- winget 清单校验通过。
- 用户可通过 winget 安装和升级。
- 安装包 SHA256 与 Release 资产一致。

## P2-2 长期方案：C# 原生单 EXE

状态：可选，仅在 PowerShell 相关误报持续存在时考虑。

背景：

- 当前启动器仍然是 PowerShell 宿主，部分杀软可能对“隐藏 PowerShell 进程”敏感。
- 完全消除这类误报需要去掉脚本引擎。

方案：

1. 把 `lib\DeepSeekTime.ps1` 的时段逻辑迁移到 C#，保留现有测试用例。
2. 把 23 套方案配方、XAML 和装饰器迁移到 C# WPF。
3. 把托盘、右键菜单、自启、快捷方式、设置迁移到 C#。
4. 输出单个原生 EXE，使用 Authenticode 签名。
5. 保留当前 PowerShell 版本作为过渡版本，直到 C# 版本通过完整回归。

验收标准：

- 单个 EXE 无 PowerShell、无 VBS。
- 测试覆盖核心逻辑、方案渲染、安装卸载。
- SmartScreen 和 Defender 表现优于当前版本。

## 发布操作清单

每个版本按以下顺序执行：

1. 更新版本号，运行全部测试。
2. 确认签名证书 Secrets 已配置，或明确本次发布为未签名预发布。
3. 提交代码并打标签：

```powershell
git tag -a v1.2.1 -m "v1.2.1"
git push origin refs/tags/v1.2.1
```

4. 等待 Release 工作流完成，检查：
   - 安装包冒烟测试通过。
   - 便携包冒烟测试通过。
   - 安装包和启动器签名状态。
   - 三个资产和校验值齐全。
5. 下载发布资产，核对 SHA256，运行一次安装和卸载。
6. 更新 README、TODO 和 Release 说明。

注意：

- 未签名版本默认会被工作流标记为预发布。GitHub 的 `/releases/latest` 指针在把预发布改为正式版后可能不会立即更新；必要时删除该 Release 后用同一标签重新创建并上传资产，或先配置证书再发稳定版。
- `v1.2.0` 已经人工核对并设为正式版，当前 Latest 指向它。

## 完成定义

以下条件全部满足后，可以认为项目的发布链路基本收敛：

- [ ] 安装包和启动器签名，SmartScreen 无未知发布者提示。
- [ ] timor.tech 不可用时，节假日更新有可用回退源。
- [ ] 2027 数据发布后及时更新并通过回归。
- [ ] 便携包、安装包、升级、卸载、兼容性全部有自动或人工验收记录。
- [ ] Release 资产、SHA256、Latest 指针和 README 保持一致。
