# DeepSeekBar — 菜单栏余额与用量小助手

macOS 菜单栏工具：一眼查看 DeepSeek API **余额**与**官方用量**（与平台网页版一致）。界面为 380pt 宽的轻量控制面板，支持深色 / 浅色模式。

## 功能

- **余额**：调用官方 `GET /user/balance` 接口，菜单栏直接显示余额数字（如 `¥110`），点开面板可看充值余额 / 赠送余额 / 账户状态，自动定时刷新 + 一键手动刷新。
- **充值（工具内页面）**：余额卡「+ 充值」不再弹独立窗口，而是切换到工具自己的充值页；页面内嵌 DeepSeek 官方充值页（`platform.deepseek.com/top_up`），复用网页登录态，支持在线充值 / 对公汇款与官方支付方式。支付过程中面板内实时刷新余额，返回后再次自动刷新。
- **API 管理（工具内页面）**：点击底部钥匙图标进入 API 管理页，可查看平台 API Keys、新建、重命名、删除；列表只显示脱敏 Key，新建后完整 Key 只显示一次，并支持一键复制或设为当前余额查询 Key。
- **官方用量（与网页版一致）**：DeepSeek 官方 API 不提供用量查询接口，但平台网页（platform.deepseek.com）有用量页。App 内置「网页授权」——弹出 WebView 扫码/验证码登录一次，自动捕获登录 token，随后调用网页同款内部接口展示：累计消费、近 30 天消费、日均消费、请求次数、Tokens、消费趋势、模型分布。**余额与用量共用同一刷新频率自动刷新**。Token 失效后重新授权即可。
- **安全**：API Key 与官方登录 Token 存本地凭证文件（`~/Library/Application Support/DeepSeekBar/credentials.json`，权限 600），不上传任何数据。

## 界面（v1.3.1 操作栏修复）

- **品牌渐变余额卡**：DeepSeek 蓝渐变 + 柔光装饰，余额数字使用等宽圆体，充值/赠送钱包以玻璃胶囊呈现。
- **充值页（页面内）**：余额卡右下角「+ 充值」，余额不足时在错误提示旁也会出现；点击后面板切换到充值页，顶部显示当前余额，中间直接内嵌官方充值页，底部持续同步余额。
- **API 管理页（页面内）**：底部钥匙图标进入；列表展示名称、脱敏 Key、创建/最近使用时间，当前 Key 带有「当前使用」标记；支持新建、重命名、删除与复制。
- **用量概览**：累计消费、日均、近 30 天、请求次数、Tokens 分组展示，信息密度适中。
- **可交互趋势图**：横向滚动查看完整 30 天，默认定位到最新；鼠标悬浮单日柱状图，右侧即时显示该日消费；底部保留可见滚动条，拖拽/触控板横滑均可。
- **模型分布**：只展示有实际消费的 Top 3 模型，显示占比、金额和进度条，原始 model id 自动映射成可读名称。
- **设置页**：按 API Key / 官方授权 / 自动刷新 / 关于重新分组，自定义分段选择器与状态胶囊，所有卡片支持浅色与深色模式。
- **操作栏**：刷新 / API 管理 / 设置 / 退出统一放在主面板底部；设置、API、充值页的返回与刷新也在底部。macOS `MenuBarExtra` 面板顶部存在系统拖拽/保留区，顶部按钮可能收不到鼠标点击，因此交互控件统一避开顶部。
- **细节**：充值页停留时每 8 秒静默刷新余额；API 页只展示脱敏 Key；面板切换页使用淡入淡出过渡。

## 构建与运行

```bash
# 直接编译运行（调试，会出现在 Dock）
swift run DeepSeekBar

# 打包成正式 .app（菜单栏应用，不占 Dock）
./scripts/make_app.sh
open dist/DeepSeekBar.app
```

## 使用

1. 点击菜单栏图标打开面板 → 右上角齿轮进入设置。
2. 填入 DeepSeek API Key（platform.deepseek.com → API Keys）→ 保存 → 测试连接，余额即显示。
3. 用量统计：设置里点「网页登录授权」→ 弹出窗口扫码/验证码登录一次 → 自动同步官方用量（累计消费、请求次数、Tokens、近 30 天图表、模型分布），之后定时自动刷新。
4. 充值：点余额卡右下角「+ 充值」→ 面板切换到充值页 → 在官方页面完成支付 → 支付过程中顶部余额自动更新，返回后再次刷新。
5. API 管理：点右上角钥匙图标 → 查看/新建/重命名/删除 API Keys；新建后完整 Key 只显示一次，可复制或一键设为当前余额查询 Key。

## 数据位置

| 数据 | 位置 |
|---|---|
| API Key / 官方 Token | `~/Library/Application Support/DeepSeekBar/credentials.json`（600 权限） |
| 设置 | UserDefaults（刷新频率） |

## 开发备注

- 调试参数（`swift run DeepSeekBar` 或 `.build/debug/DeepSeekBar`）：
  - `--window`：弹出 380pt 无边框预览窗口（便于截图/验证 UI；预览窗口用 NSWindow + NSHostingController 实现）
  - `--settings` / `--recharge` / `--api`：配合 `--window` 直接打开对应页面
  - `--dark` / `--light`：强制深色 / 浅色外观，便于双模式截图
  - `--snapshot <png>`：ImageRenderer 快速截图（适合主面板/设置页）
  - `--snapshot-view <png>`：NSHostingView 整页截图（可渲染 ScrollView，如 API 管理页）
  - `--snapshot-topup <png>`：单独渲染官方充值页 380×600 截图（锁屏也可用）
  - `--webauth`：启动即弹官方授权窗口（配合 `[WebAuth]` 日志监控抓 token 过程）
  - 环境变量 `DSBAR_UPSTREAM`：覆盖上游 API 地址（本地 mock 测试 / 自托管网关）
- 技术栈：SwiftUI `MenuBarExtra`（macOS 14+）+ Swift Charts + WKWebView（授权抓 token / 页面内嵌充值 / API 管理）。
- 目录：`Sources/DeepSeekBar/`（AppState 状态、OfficialAPI 官方接口/API Key 管理、WebAuthController 授权、RechargePage/RechargeWebView 充值页、APIKeysPage 管理页、MainPage/SettingsPage 界面、DesignSystem 设计令牌）。
- 官方接口真实结构与逆向细节见 skill `macos-swiftui-app-dev`。
- v1.3.1 · 2026-10
